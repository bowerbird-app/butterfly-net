# frozen_string_literal: true

require "butterfly_net/analytics_date_range"
module ButterflyNet
  # Controller for the error tracking dashboard.
  # Provides index (list of errors) and show (error details) actions.
  class DashboardController < ApplicationController
    GROUP_BY_MESSAGE = "message"
    GROUP_BY_IP = "ip"
    GROUP_BY_OPTIONS = [ GROUP_BY_MESSAGE, GROUP_BY_IP ].freeze

    def index
      @pagy, @error_rows = grouped_error_rows

      respond_to do |format|
        format.html
        format.json do
          render json: {
            error_logs: @error_rows,
            pagy: pagy_metadata(@pagy)
          }
        end
      end
    end

    def grouped
      @exception_class = params[:exception_class].to_s
      @group_by = normalized_group_by
      @pagy, @error_logs = grouped_error_logs

      respond_to do |format|
        format.html
        format.json do
          render json: {
            error_logs: grouped_error_logs_json,
            pagy: pagy_metadata(@pagy)
          }
        end
      end
    end

    def show
      @error_log = ErrorLog.find(params[:id])
      @github_configured = ButterflyNet.configuration.github_configured?
      @bowerbird_target_repos = @error_log.bowerbird_repos_from_backtrace
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

      unless ButterflyNet.configuration.github_configured?
        flash[:alert] = "GitHub integration is not configured. Please set github_access_token, github_repo_owner, and github_repo_name."
        redirect_to dashboard_path(@error_log)
        return
      end

      target_repo = resolve_target_repo
      unless target_repo
        flash[:alert] = "Invalid target repository."
        redirect_to dashboard_path(@error_log)
        return
      end

      result = @error_log.create_github_issue(target_repo: target_repo)

      if result.success
        flash[:notice] = "GitHub issue ##{result.issue_number} created successfully in #{target_repo}."
      else
        flash[:alert] = "Failed to create GitHub issue: #{result.error_message}"
      end

      redirect_to dashboard_path(@error_log)
    end

    # Renders the analytics dashboard view
    def analytics
      @date_range = AnalyticsDateRange.from_params(
        start_date: params[:start_date],
        end_date: params[:end_date]
      )
    end

    private

    # Resolves the target repo for issue creation.
    # Accepts params[:target_repo] only if it is the configured app repo
    # or one of the bowerbird repos detected in the error's backtrace.
    def resolve_target_repo
      requested = params[:target_repo].presence
      default_repo = ButterflyNet.configuration.full_repo_name

      return default_repo unless requested

      allowed = [ default_repo ] + @error_log.bowerbird_repos_from_backtrace
      allowed.include?(requested) ? requested : nil
    end

    def error_log_json(error_log, affected_count = nil)
      last_occurrence = error_log.occurrences.order(created_at: :desc).first

      # Calculate affected count if not provided
      if affected_count.nil?
        unique_users = error_log.occurrences.where.not(user_id: nil).distinct.count(:user_id)
        unique_emails = error_log.occurrences.where.not(user_email: nil).distinct.count(:user_email)
        affected_count = [ unique_users, unique_emails ].max
      end

      {
        id: error_log.id,
        dashboard_path: ButterflyNet::Engine.routes.url_helpers.dashboard_path(error_log),
        grouped: false,
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

    def grouped_error_rows
      total_count = ErrorLog.distinct.count(:exception_class)
      pagy = Pagy.new(count: total_count, page: params[:page], limit: 25)

      exception_classes = grouped_exception_class_scope
        .offset(pagy.offset)
        .limit(pagy.limit)
        .pluck("#{error_logs_table}.exception_class")

      [ pagy, build_grouped_error_rows(exception_classes) ]
    end

    def grouped_exception_class_scope
      ErrorLog
        .left_outer_joins(:occurrences)
        .group("#{error_logs_table}.exception_class")
        .order(Arel.sql("MAX(COALESCE(#{error_occurrences_table}.created_at, #{error_logs_table}.created_at)) DESC"))
    end

    def build_grouped_error_rows(exception_classes)
      return [] if exception_classes.empty?

      aggregate_rows = ErrorLog
        .left_outer_joins(:occurrences)
        .where(exception_class: exception_classes)
        .group("#{error_logs_table}.exception_class")
        .pluck(
          "#{error_logs_table}.exception_class",
          Arel.sql("COUNT(DISTINCT #{error_logs_table}.id)"),
          Arel.sql("MIN(#{error_logs_table}.id)"),
          Arel.sql("COUNT(#{error_occurrences_table}.id)"),
          Arel.sql("COUNT(DISTINCT #{error_occurrences_table}.user_id)"),
          Arel.sql("COUNT(DISTINCT #{error_occurrences_table}.user_email)"),
          Arel.sql("MAX(COALESCE(#{error_occurrences_table}.created_at, #{error_logs_table}.created_at))")
        )

      aggregates_by_class = aggregate_rows.each_with_object({}) do |(exception_class, error_log_count, error_log_id, occurrence_count, user_count, email_count, last_seen), grouped_rows|
        grouped_rows[exception_class] = {
          error_log_count: error_log_count.to_i,
          error_log_id: error_log_id,
          occurrence_count: occurrence_count.to_i,
          affected_count: [ user_count.to_i, email_count.to_i ].max,
          last_seen: last_seen
        }
      end

      unique_log_ids = aggregates_by_class.values
        .select { |row| row[:error_log_count] == 1 }
        .map { |row| row[:error_log_id] }

      unique_logs = ErrorLog.where(id: unique_log_ids).index_by(&:id)

      exception_classes.map do |exception_class|
        aggregate = aggregates_by_class.fetch(exception_class)
        unique = aggregate[:error_log_count] == 1
        error_log = unique_logs[aggregate[:error_log_id]]

        {
          id: unique ? error_log.id : nil,
          dashboard_path: unique ? dashboard_path(error_log) : grouped_dashboard_index_path(exception_class: exception_class),
          grouped: !unique,
          status: unique ? error_log.status : nil,
          exception_class: exception_class,
          message: unique ? error_log.message : nil,
          occurrence_count: aggregate[:occurrence_count],
          affected_count: aggregate[:affected_count],
          last_seen: aggregate[:last_seen] || error_log&.created_at,
          github_issue_number: unique ? error_log.github_issue_number : nil,
          github_issue_url: unique ? error_log.github_issue_url : nil,
          has_github_issue: unique && error_log.has_github_issue?
        }
      end
    end

    def calculate_affected_counts(error_log_ids)
      return {} if error_log_ids.empty?

      # Calculate affected user counts in a single query to avoid N+1
      user_counts = ErrorOccurrence
        .where(error_log_id: error_log_ids)
        .where.not(user_id: nil)
        .group(:error_log_id)
        .distinct
        .count(:user_id)

      email_counts = ErrorOccurrence
        .where(error_log_id: error_log_ids)
        .where.not(user_email: nil)
        .group(:error_log_id)
        .distinct
        .count(:user_email)

      # Merge and take the max count for each error log
      error_log_ids.index_with do |id|
        [ user_counts[id] || 0, email_counts[id] || 0 ].max
      end
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

    def error_logs_table
      ErrorLog.table_name
    end

    def error_occurrences_table
      ErrorOccurrence.table_name
    end

    def normalized_group_by
      GROUP_BY_OPTIONS.include?(params[:group_by]) ? params[:group_by] : GROUP_BY_MESSAGE
    end

    def grouped_error_logs
      return grouped_error_logs_by_ip if @group_by == GROUP_BY_IP

      pagy(ErrorLog.by_exception_class(@exception_class).recent.includes(:occurrences), limit: 25)
    end

    def grouped_error_logs_json
      return @error_logs.map { |group| grouped_ip_group_json(group) } if @group_by == GROUP_BY_IP

      error_log_ids = @error_logs.pluck(:id)
      affected_counts = calculate_affected_counts(error_log_ids)

      @error_logs.map { |log| error_log_json(log, affected_counts[log.id] || 0) }
    end

    def grouped_error_logs_by_ip
      groups = build_grouped_ip_groups
      pagy = Pagy.new(count: groups.length, page: params[:page], limit: 25)

      [ pagy, groups.slice(pagy.offset, pagy.limit) || [] ]
    end

    def build_grouped_ip_groups
      grouped_rows = ErrorOccurrence
        .joins(:error_log)
        .where(error_logs_table => { exception_class: @exception_class })
        .includes(:error_log)
        .each_with_object({}) do |occurrence, rows|
          ip_address = occurrence_ip_address(occurrence)
          rows[ip_address] ||= {
            ip_address: ip_address,
            last_seen: nil,
            error_logs: {}
          }

          row = rows[ip_address]

          row[:error_logs][occurrence.error_log_id] ||= {
            error_log: occurrence.error_log,
            occurrence_count: 0,
            unique_user_ids: Set.new,
            unique_user_emails: Set.new,
            last_seen: nil
          }

          error_row = row[:error_logs][occurrence.error_log_id]
          error_row[:occurrence_count] += 1
          error_row[:unique_user_ids] << occurrence.user_id if occurrence.user_id.present?
          error_row[:unique_user_emails] << occurrence.user_email if occurrence.user_email.present?

          occurred_at = occurrence.created_at || occurrence.error_log.created_at
          row[:last_seen] = occurred_at if row[:last_seen].nil? || occurred_at > row[:last_seen]
          error_row[:last_seen] = occurred_at if error_row[:last_seen].nil? || occurred_at > error_row[:last_seen]
        end

      grouped_rows.values.map do |row|
        row[:error_logs] = row[:error_logs].values.map do |error_row|
          build_grouped_ip_error_log(error_row)
        end.sort_by { |error_log| [ -(error_log[:last_seen]&.to_i || 0), error_log[:message].to_s ] }
        row
      end.sort_by { |row| [ -(row[:last_seen]&.to_i || 0), row[:ip_address] ] }
    end

    def build_grouped_ip_error_log(error_row)
      error_log = error_row[:error_log]

      {
        id: error_log.id,
        dashboard_path: dashboard_path(error_log),
        grouped: false,
        status: error_log.status,
        exception_class: error_log.exception_class,
        message: error_log.message,
        occurrence_count: error_row[:occurrence_count],
        affected_count: [ error_row[:unique_user_ids].length, error_row[:unique_user_emails].length ].max,
        last_seen: error_row[:last_seen] || error_log.created_at,
        github_issue_number: error_log.github_issue_number,
        github_issue_url: error_log.github_issue_url,
        has_github_issue: error_log.has_github_issue?
      }
    end

    def grouped_ip_group_json(group)
      {
        ip_address: group[:ip_address],
        last_seen: group[:last_seen],
        error_logs: group[:error_logs]
      }
    end

    def occurrence_ip_address(occurrence)
      params = occurrence.params_hash
      params["ip_address"].presence || params[:ip_address].presence || "Unknown"
    end
  end
end
