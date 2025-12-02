# frozen_string_literal: true

module MarcoButterflyNet
  # Model for storing captured exception data from the error tracking middleware.
  # Each record represents a single exception that was caught during a request.
  class ErrorLog < ApplicationRecord
    validates :exception_class, presence: true

    # Returns backtrace as array (handles text storage)
    def backtrace_lines
      return [] if backtrace.blank?

      backtrace.split("\n")
    end

    # Returns request_params as hash (with safety for nil values)
    def params_hash
      request_params || {}
    end

    # Scope for recent errors
    scope :recent, -> { order(created_at: :desc) }

    # Scope for filtering by exception class
    scope :by_exception_class, ->(klass) { where(exception_class: klass) }

    # Scope for errors with GitHub issues
    scope :with_github_issue, -> { where.not(github_issue_number: nil) }

    # Scope for errors without GitHub issues
    scope :without_github_issue, -> { where(github_issue_number: nil) }

    # Scope for filtering by user_id
    scope :for_user, ->(user_id) { where(user_id: user_id) }

    # Scope for filtering by user_email
    scope :for_user_email, ->(email) { where(user_email: email) }

    # Scope for filtering by status
    scope :with_status, ->(status) { where(status: status) }

    # Scope for open errors
    scope :open, -> { where(status: "open") }

    # Scope for resolved errors
    scope :resolved, -> { where(status: "resolved") }

    # Scope for repeated errors (occurrence_count > 1)
    scope :repeated, -> { where("occurrence_count > 1") }

    # Status constants
    STATUSES = %w[open in_progress resolved dismissed].freeze

    validates :status, inclusion: { in: STATUSES }

    # Checks if this error has an associated GitHub issue
    def has_github_issue?
      github_issue_number.present?
    end

    # Checks if this error has blame information
    def has_blame_info?
      blame_file.present? && blame_commit_sha.present?
    end

    # Checks if this is a repeated error
    def repeated?
      occurrence_count > 1
    end

    # Increments the occurrence count for this error
    def increment_occurrence!
      increment!(:occurrence_count)
    end

    # Finds or creates an error log for the same error and user
    # @param exception_class [String] the exception class name
    # @param message [String] the error message
    # @param user_id [String] optional user id
    # @param user_email [String] optional user email
    # @return [MarcoButterflyNet::ErrorLog] the found or created error log
    def self.find_or_create_for_user(exception_class:, message:, user_id: nil, user_email: nil, **attributes)
      # When no user identifiers provided, always create a new error
      # to avoid incorrectly grouping errors from different users
      if user_id.nil? && user_email.nil?
        return create!(
          exception_class: exception_class,
          message: message,
          **attributes
        )
      end

      existing = where(exception_class: exception_class, message: message)
      existing = existing.where(user_id: user_id) if user_id
      existing = existing.where(user_email: user_email) if user_email
      existing = existing.first

      if existing
        existing.increment_occurrence!
        existing
      else
        create!(
          exception_class: exception_class,
          message: message,
          user_id: user_id,
          user_email: user_email,
          **attributes
        )
      end
    end

    # Retrieves git blame information for this error
    # @param force [Boolean] whether to retrieve even if blame info exists
    # @return [MarcoButterflyNet::Services::GitBlame::BlameResult, nil]
    def fetch_blame_info(force: false)
      return existing_blame_result if has_blame_info? && !force

      service = MarcoButterflyNet::Services::GitBlame.new
      result = service.blame_from_backtrace(backtrace_lines)

      if result
        update(
          blame_file: result.file,
          blame_line_number: result.line_number,
          blame_commit_sha: result.commit_sha,
          blame_author_name: result.author_name,
          blame_author_email: result.author_email,
          blame_commit_date: result.commit_date
        )
      end

      result
    end

    # Creates a GitHub issue for this error
    # @param additional_labels [Array<String>] extra labels to add
    # @return [MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult]
    def create_github_issue(additional_labels: [])
      return existing_issue_result if has_github_issue?

      # Ensure blame info is fetched
      blame_result = fetch_blame_info

      service = MarcoButterflyNet::Services::GitHubIssueCreator.new
      result = service.create_issue_for_error(self, blame_result: blame_result, additional_labels: additional_labels)

      if result.success
        update(
          github_issue_number: result.issue_number,
          github_issue_url: result.issue_url
        )
      end

      result
    end

    private

    # Returns a BlameResult from stored data
    def existing_blame_result
      return nil unless has_blame_info?

      MarcoButterflyNet::Services::GitBlame::BlameResult.new(
        file: blame_file,
        line_number: blame_line_number,
        commit_sha: blame_commit_sha,
        author_name: blame_author_name,
        author_email: blame_author_email,
        commit_date: blame_commit_date,
        line_content: nil
      )
    end

    # Returns an IssueResult from stored data
    def existing_issue_result
      MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
        success: true,
        issue_number: github_issue_number,
        issue_url: github_issue_url,
        error_message: "Issue already exists"
      )
    end
  end
end
