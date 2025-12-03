# frozen_string_literal: true

module MarcoButterflyNet
  # Controller for the error tracking dashboard.
  # Provides index (list of errors) and show (error details) actions.
  class DashboardController < ApplicationController
    PER_PAGE = 25

    def index
      @page = (params[:page] || 1).to_i
      @page = 1 if @page < 1

      @error_logs = ErrorLog.recent
                            .includes(:occurrences)
                            .offset((@page - 1) * PER_PAGE)
                            .limit(PER_PAGE)

      @total_count = ErrorLog.count
      @total_pages = (@total_count / PER_PAGE.to_f).ceil
      @total_pages = 1 if @total_pages < 1
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
  end
end
