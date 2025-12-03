# frozen_string_literal: true

module MarcoButterflyNet
  # Controller for the error tracking dashboard.
  # Provides index (list of errors) and show (error details) actions.
  class DashboardController < ApplicationController
    def index
      @pagy, @error_logs = pagy(ErrorLog.recent.includes(:occurrences), limit: 25)

      respond_to do |format|
        format.html
        format.json do
          render json: {
            error_logs: @error_logs.map { |log| error_log_json(log) },
            pagy: pagy_metadata(@pagy)
          }
        end
      end
    end

    def show
      @error_log = ErrorLog.find(params[:id])
      @github_configured = MarcoButterflyNet.configuration.github_configured?
    end

    # Fetches git blame information for the error
    def fetch_blame
      @error_log = ErrorLog.find(params[:id])
      @blame_result = @error_log.fetch_blame_info(force: params[:force] == "true")

      if @blame_result
        flash[:notice] = "Git blame information retrieved successfully."
      else
        flash[:alert] = "Could not retrieve git blame information. The file may not be in the repository."
      end

      redirect_to dashboard_path(@error_log)
    end

    # Creates a GitHub issue for the error
    def create_issue
      @error_log = ErrorLog.find(params[:id])

      unless MarcoButterflyNet.configuration.github_configured?
        flash[:alert] = "GitHub integration is not configured. Please set github_access_token, github_repo_owner, and github_repo_name."
        redirect_to dashboard_path(@error_log)
        return
      end

      result = @error_log.create_github_issue

      if result.success
        flash[:notice] = "GitHub issue ##{result.issue_number} created successfully."
      else
        flash[:alert] = "Failed to create GitHub issue: #{result.error_message}"
      end

      redirect_to dashboard_path(@error_log)
    end

    private

    def error_log_json(error_log)
      last_occurrence = error_log.occurrences.order(created_at: :desc).first
      unique_users = error_log.occurrences.where.not(user_id: nil).distinct.count(:user_id)
      unique_emails = error_log.occurrences.where.not(user_email: nil).distinct.count(:user_email)
      affected_count = [ unique_users, unique_emails ].max

      {
        id: error_log.id,
        status: error_log.status,
        exception_class: error_log.exception_class,
        message: error_log.message,
        occurrence_count: error_log.occurrence_count,
        affected_count: affected_count,
        last_seen: last_occurrence ? last_occurrence.created_at : error_log.created_at,
        github_issue_number: error_log.github_issue_number,
        github_issue_url: error_log.github_issue_url,
        has_github_issue: error_log.has_github_issue?
      }
    end

    def pagy_metadata(pagy)
      {
        page: pagy.page,
        limit: pagy.limit,
        count: pagy.count,
        pages: pagy.pages,
        next: pagy.next,
        prev: pagy.prev
      }
    end
  end
end
