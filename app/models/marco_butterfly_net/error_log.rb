# frozen_string_literal: true

module MarcoButterflyNet
  # Model for storing captured exception data from the error tracking middleware.
  # Each record represents a unique exception type that was caught during requests.
  # Individual occurrences are tracked in ErrorOccurrence.
  class ErrorLog < ApplicationRecord
    has_many :occurrences, class_name: "MarcoButterflyNet::ErrorOccurrence", dependent: :destroy

    validates :exception_class, presence: true

    # Callback to set resolved_at timestamp when status changes to resolved
    before_update :set_resolved_at

    # Automatically fetch blame information in background when error log is created
    after_create_commit :enqueue_blame_fetch, if: :should_auto_fetch_blame?

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

    # Scope for filtering by status
    scope :with_status, ->(status) { where(status: status) }

    # Scope for open errors
    scope :open, -> { where(status: "open") }

    # Scope for resolved errors
    scope :resolved, -> { where(status: "resolved") }

    # Scope for repeated errors (more than one occurrence)
    scope :repeated, -> {
      subquery = MarcoButterflyNet::ErrorOccurrence
        .select(:error_log_id)
        .group(:error_log_id)
        .having("COUNT(*) > 1")
      where(id: subquery)
    }

    # Scope for errors affecting a specific user
    scope :affecting_user, ->(user_id) {
      where(
        id: ErrorOccurrence.select(:error_log_id).where(user_id: user_id)
      )
    }

    # Scope for errors affecting a specific user email
    scope :affecting_user_email, ->(email) {
      where(
        id: ErrorOccurrence.select(:error_log_id).where(user_email: email)
      )
    }

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

    # Returns the total occurrence count
    def occurrence_count
      occurrences.count
    end

    # Checks if this is a repeated error (more than one occurrence)
    def repeated?
      occurrence_count > 1
    end

    # Records an occurrence of this error for a user
    # @param user_id [String] optional user id
    # @param user_email [String] optional user email
    # @param request_params [Hash] optional request parameters
    # @param user_agent [String] optional user agent
    # @return [MarcoButterflyNet::ErrorOccurrence] the created occurrence
    def record_occurrence(user_id: nil, user_email: nil, request_params: nil, user_agent: nil)
      occurrences.create!(
        user_id: user_id,
        user_email: user_email,
        request_params: request_params,
        user_agent: user_agent
      )
    end

    # Finds or creates an error log for the same error type, and records an occurrence
    # @param exception_class [String] the exception class name
    # @param message [String] the error message
    # @param user_id [String] optional user id
    # @param user_email [String] optional user email
    # @param request_params [Hash] optional request parameters
    # @param user_agent [String] optional user agent
    # @param backtrace [String] optional backtrace
    # @return [MarcoButterflyNet::ErrorLog] the found or created error log
    def self.find_or_create_with_occurrence(exception_class:, message:, user_id: nil, user_email: nil, request_params: nil, user_agent: nil, backtrace: nil)
      error_log = find_or_create_by!(exception_class: exception_class, message: message) do |log|
        log.backtrace = backtrace
        log.request_params = request_params
        log.user_agent = user_agent
      end

      # Update request_params and user_agent on existing records if they're missing
      if error_log.request_params.nil? && request_params.present?
        error_log.update(request_params: request_params)
      end
      if error_log.user_agent.nil? && user_agent.present?
        error_log.update(user_agent: user_agent)
      end

      error_log.record_occurrence(
        user_id: user_id,
        user_email: user_email,
        request_params: request_params,
        user_agent: user_agent
      )

      error_log
    end

    # Returns occurrences for a specific user
    def occurrences_for_user(user_id)
      occurrences.for_user(user_id)
    end

    # Returns occurrences for a specific user email
    def occurrences_for_user_email(email)
      occurrences.for_user_email(email)
    end

    # Returns the count of affected users (unique user_ids)
    def affected_users_count
      occurrences.where.not(user_id: nil).distinct.count(:user_id)
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

    # Sets resolved_at timestamp when status changes to 'resolved'
    def set_resolved_at
      if status_changed? && status == "resolved"
        self.resolved_at = Time.current
      elsif status_changed? && status_was == "resolved"
        # Clear resolved_at if status changes away from resolved
        self.resolved_at = nil
      end
    end

    # Checks if blame info should be automatically fetched
    def should_auto_fetch_blame?
      backtrace.present? && !has_blame_info?
    end

    # Enqueues background job to fetch blame information
    def enqueue_blame_fetch
      FetchBlameJob.perform_later(id)
    end
  end
end
