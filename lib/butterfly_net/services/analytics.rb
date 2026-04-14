# frozen_string_literal: true

require "set"

module ButterflyNet
  module Services
    # Service for calculating analytics and metrics for the error tracking dashboard
    class Analytics
      def initialize(start_time: nil, end_time: nil)
        @start_time = start_time
        @end_time = end_time
      end

      # Returns the count of errors with status 'open'
      # @return [Integer]
      def total_open_errors
        scope = ErrorLog.with_status("open")

        if time_range?
          scope = scope.joins(:occurrences).merge(occurrences_in_range_scope).distinct
        end

        scope.count
      end

      # Returns the count of unique users affected by errors in the configured range
      # @return [Integer]
      def total_affected_users
        count_unique_users(occurrences_in_range_scope)
      end

      # Returns the average time from error creation to resolution in hours
      # Only considers errors that have been resolved
      # @return [Float] average hours, or 0 if no resolved errors
      def mean_time_to_resolution
        resolved_errors = ErrorLog
          .where(status: "resolved")
          .where.not(resolved_at: nil)

        if time_range?
          resolved_errors = resolved_errors.where(resolved_at: @start_time..@end_time)
        end

        return 0.0 if resolved_errors.count.zero?

        total_seconds = resolved_errors.sum do |error|
          (error.resolved_at - error.created_at).to_f
        end

        total_hours = total_seconds / 3600.0
        (total_hours / resolved_errors.count).round(2)
      end

      # Returns a hash with counts for each error status
      # @return [Hash] { "open" => 5, "in_progress" => 3, "resolved" => 10, "dismissed" => 2 }
      def error_status_breakdown
        breakdown_scope = ErrorLog.all

        if time_range?
          breakdown_scope = breakdown_scope.joins(:occurrences).merge(occurrences_in_range_scope).distinct
        end

        breakdown = breakdown_scope.group(:status).count

        # Ensure all statuses are present in the result
        ErrorLog::STATUSES.each do |status|
          breakdown[status] ||= 0
        end

        breakdown
      end

      # Returns the top N most frequent errors sorted by occurrence count
      # @param limit [Integer] number of errors to return (default: 10)
      # @return [Array<Hash>] array of hashes with error info and occurrence count
      def top_frequent_errors(limit: 10)
        scope = ErrorLog
          .joins(:occurrences)
          .select("butterfly_net_error_logs.*, COUNT(butterfly_net_error_occurrences.id) as occurrence_count")
          .group("butterfly_net_error_logs.id")
          .order("occurrence_count DESC")
          .limit(limit)

        scope = scope.merge(occurrences_in_range_scope) if time_range?

        scope
          .map do |error|
            {
              id: error.id,
              exception_class: error.exception_class,
              message: error.message,
              status: error.status,
              occurrence_count: error.occurrence_count
            }
          end
      end

      # Returns daily affected user counts for the given date range
      # @return [Array<Hash>] array of { date: "2023-12-01", count: 5 }
      def affected_users_over_time(start_date:, end_date:)

        users_by_date = Hash.new { |hash, key| hash[key] = Set.new }

        ErrorOccurrence
          .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
          .select(:created_at, :user_id, :user_email)
          .each do |occurrence|
            identifier = occurrence.user_id.presence || occurrence.user_email
            next if identifier.blank?

            users_by_date[occurrence.created_at.to_date.to_s].add(identifier)
          end

        build_date_series(start_date, end_date) do |date|
          users_by_date[date.to_s].size
        end
      end

      # Returns daily error occurrence counts for the given date range
      # @return [Array<Hash>] array of { date: "2023-12-01", count: 15 }
      def error_occurrences_over_time(start_date:, end_date:)

        occurrences_by_date = ErrorOccurrence
          .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
          .group("DATE(created_at)")
          .count

        # Normalize date keys to strings for consistent lookup
        normalized_occurrences = {}
        occurrences_by_date.each do |date, count|
          date_str = date.is_a?(String) ? date : date.to_s
          normalized_occurrences[date_str] = count
        end

        # Fill in missing dates with zero counts
        build_date_series(start_date, end_date) do |date|
          normalized_occurrences[date.to_s] || 0
        end
      end

      # Returns daily new error discovery counts for the given date range
      # @return [Array<Hash>] array of { date: "2023-12-01", count: 3 }
      def new_errors_over_time(start_date:, end_date:)

        errors_by_date = ErrorLog
          .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
          .group("DATE(created_at)")
          .count

        # Normalize date keys to strings for consistent lookup
        normalized_errors = {}
        errors_by_date.each do |date, count|
          date_str = date.is_a?(String) ? date : date.to_s
          normalized_errors[date_str] = count
        end

        # Fill in missing dates with zero counts
        build_date_series(start_date, end_date) do |date|
          normalized_errors[date.to_s] || 0
        end
      end

      # Returns top N most affected users by occurrence count in the configured range
      # @param limit [Integer] number of users to return (default: 10)
      # @return [Array<Hash>] array of { email: "user@example.com", count: 5 }
      def top_affected_users(limit: 10)
        scope = occurrences_in_range_scope.where.not(user_email: [nil, ""])

        scope
          .group(:user_email)
          .order("count_all DESC")
          .limit(limit)
          .count
          .map { |email, count| { email: email, count: count } }
      end

      # Returns total occurrences in the configured range
      # @return [Integer]
      def total_occurrences
        occurrences_in_range_scope.count
      end

      private

      def time_range?
        @start_time.present? && @end_time.present?
      end

      def occurrences_in_range_scope
        scope = ErrorOccurrence.all
        return scope unless time_range?

        scope.where(created_at: @start_time..@end_time)
      end

      def count_unique_users(scope)
        unique_users = Set.new

        scope.select(:user_id, :user_email).each do |occurrence|
          identifier = occurrence.user_id.presence || occurrence.user_email
          unique_users.add(identifier) if identifier.present?
        end

        unique_users.size
      end

      def build_date_series(start_date, end_date)
        return [] if end_date < start_date

        (start_date..end_date).map do |date|
          {
            date: date.to_s,
            count: yield(date)
          }
        end
      end
    end
  end
end
