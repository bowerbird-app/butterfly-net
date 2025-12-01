# frozen_string_literal: true

require "octokit"

module MarcoButterflyNet
  module Services
    # Service to create GitHub issues for errors using the Octokit gem.
    # Formats error information and creates issues in the configured repository.
    class GitHubIssueCreator
      IssueResult = Struct.new(:success, :issue_number, :issue_url, :error_message, keyword_init: true)

      attr_reader :client, :repo

      def initialize(access_token: nil, repo: nil)
        @access_token = access_token || MarcoButterflyNet.configuration.github_access_token
        @repo = repo || MarcoButterflyNet.configuration.full_repo_name

        @client = create_client if @access_token
      end

      # Creates a GitHub issue for an error log entry
      # @param error_log [MarcoButterflyNet::ErrorLog] the error log record
      # @param blame_result [GitBlame::BlameResult, nil] optional blame information
      # @param additional_labels [Array<String>] additional labels to apply
      # @return [IssueResult] result of the issue creation
      def create_issue_for_error(error_log, blame_result: nil, additional_labels: [])
        return IssueResult.new(success: false, error_message: "GitHub client not configured") unless client
        return IssueResult.new(success: false, error_message: "Repository not configured") unless repo

        title = build_issue_title(error_log)
        body = build_issue_body(error_log, blame_result)
        labels = build_labels(error_log, additional_labels)

        response = client.create_issue(repo, title, body, labels: labels)

        IssueResult.new(
          success: true,
          issue_number: response.number,
          issue_url: response.html_url
        )
      rescue Octokit::Error => e
        IssueResult.new(success: false, error_message: "GitHub API error: #{e.message}")
      rescue StandardError => e
        IssueResult.new(success: false, error_message: "Unexpected error: #{e.message}")
      end

      # Checks if the service is properly configured
      # @return [Boolean] true if configured correctly
      def configured?
        @access_token.present? && @repo.present?
      end

      private

      def create_client
        Octokit::Client.new(access_token: @access_token)
      end

      def build_issue_title(error_log)
        message_preview = error_log.message.to_s.truncate(80)
        "[Error] #{error_log.exception_class}: #{message_preview}"
      end

      def build_issue_body(error_log, blame_result)
        body = []

        body << "## Error Details\n"
        body << "| Field | Value |"
        body << "|-------|-------|"
        body << "| **Exception Class** | `#{error_log.exception_class}` |"
        body << "| **Occurred At** | #{error_log.created_at&.strftime('%Y-%m-%d %H:%M:%S %Z')} |"
        body << "| **Error Log ID** | #{error_log.id} |"
        body << ""
        body << "### Message\n"
        body << "```"
        body << error_log.message
        body << "```"
        body << ""

        if blame_result
          body << "## Git Blame Information\n"
          body << "| Field | Value |"
          body << "|-------|-------|"
          body << "| **File** | `#{blame_result.file}` |"
          body << "| **Line Number** | #{blame_result.line_number} |"
          body << "| **Commit** | `#{blame_result.commit_sha&.first(8)}` |"
          body << "| **Author** | #{blame_result.author_name} (#{blame_result.author_email}) |"
          body << "| **Commit Date** | #{blame_result.commit_date&.strftime('%Y-%m-%d %H:%M:%S %Z')} |"
          body << ""
          if blame_result.line_content.present?
            body << "### Problematic Line\n"
            body << "```"
            body << blame_result.line_content
            body << "```"
            body << ""
          end
        end

        params_hash = error_log.params_hash
        if params_hash.present?
          body << "## Request Details\n"
          body << "| Field | Value |"
          body << "|-------|-------|"
          body << "| **Path** | `#{params_hash['path'] || params_hash[:path] || 'N/A'}` |"
          body << "| **Method** | `#{params_hash['method'] || params_hash[:method] || 'N/A'}` |"
          body << "| **User Agent** | #{error_log.user_agent || 'N/A'} |"
          body << ""
        end

        if error_log.backtrace_lines.any?
          body << "## Stack Trace\n"
          body << "<details>"
          body << "<summary>Click to expand</summary>\n"
          body << "```"
          error_log.backtrace_lines.first(30).each_with_index do |line, idx|
            body << "#{idx + 1}. #{line}"
          end
          if error_log.backtrace_lines.count > 30
            body << "... (#{error_log.backtrace_lines.count - 30} more lines)"
          end
          body << "```"
          body << "</details>"
        end

        body << ""
        body << "---"
        body << "_This issue was automatically created by [MarcoButterflyNet](https://github.com/bowerbird-app/marco-butterfly-net)_"

        body.join("\n")
      end

      def build_labels(error_log, additional_labels)
        labels = [ "bug", "error-tracking" ]
        labels += additional_labels
        labels.uniq
      end
    end
  end
end
