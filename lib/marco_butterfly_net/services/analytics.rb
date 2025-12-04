# frozen_string_literal: true

require "set"

module MarcoButterflyNet
  module Services
    # Service for calculating analytics and metrics for the error tracking dashboard
    class Analytics
      # Returns the count of errors with status 'open'
      # @return [Integer]
      def total_open_errors
        ErrorLog.with_status("open").count
      end

      # Returns the count of unique users affected by errors today
      # @return [Integer]
      def total_affected_users_today
        today_start = Time.current.beginning_of_day

        # Count distinct users by collecting unique user_id or user_email
        # A user is identified by either user_id or user_email, whichever is present
        occurrences = ErrorOccurrence
          .where("created_at >= ?", today_start)
          .select(:user_id, :user_email)

        unique_users = Set.new
        occurrences.each do |occ|
          # Use user_id as primary identifier, fall back to user_email
          identifier = occ.user_id.presence || occ.user_email
          unique_users.add(identifier) if identifier.present?
        end

        unique_users.size
      end

      # Returns the average time from error creation to resolution in hours
      # Only considers errors that have been resolved
      # @return [Float] average hours, or 0 if no resolved errors
      def mean_time_to_resolution
        resolved_errors = ErrorLog
          .where(status: "resolved")
          .where.not(resolved_at: nil)

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
        breakdown = ErrorLog.group(:status).count

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
        ErrorLog
          .joins(:occurrences)
          .select("marco_butterfly_net_error_logs.*, COUNT(marco_butterfly_net_error_occurrences.id) as occurrence_count")
          .group("marco_butterfly_net_error_logs.id")
          .order("occurrence_count DESC")
          .limit(limit)
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

      # Returns daily affected user counts for the past N days
      # @param days [Integer] number of days to look back (default: 30)
      # @return [Array<Hash>] array of { date: "2023-12-01", count: 5 }
      def affected_users_over_time(days: 30)
        start_date = (Date.current - days.days).beginning_of_day

        # Count distinct users per day
        results = {}
        (0...days).each do |i|
          date = Date.current - i.days
          date_str = date.to_s

          # Get all occurrences for this date
          occurrences = ErrorOccurrence
            .where("DATE(created_at) = ?", date)
            .select(:user_id, :user_email)

          # Count unique users using user_id or user_email as identifier
          unique_users = Set.new
          occurrences.each do |occ|
            identifier = occ.user_id.presence || occ.user_email
            unique_users.add(identifier) if identifier.present?
          end

          results[date_str] = unique_users.size
        end

        results.sort.map { |date, count| { date: date, count: count } }
      end

      # Returns daily error occurrence counts for the past N days
      # @param days [Integer] number of days to look back (default: 30)
      # @return [Array<Hash>] array of { date: "2023-12-01", count: 15 }
      def error_occurrences_over_time(days: 30)
        start_date = (Date.current - days.days).beginning_of_day

        occurrences_by_date = ErrorOccurrence
          .where("created_at >= ?", start_date)
          .group("DATE(created_at)")
          .count

        # Normalize date keys to strings for consistent lookup
        normalized_occurrences = {}
        occurrences_by_date.each do |date, count|
          date_str = date.is_a?(String) ? date : date.to_s
          normalized_occurrences[date_str] = count
        end

        # Fill in missing dates with zero counts
        results = {}
        (0...days).each do |i|
          date = (Date.current - i.days).to_s
          results[date] = normalized_occurrences[date] || 0
        end

        results.sort.map { |date, count| { date: date, count: count } }
      end

      # Returns daily new error discovery counts for the past N days
      # @param days [Integer] number of days to look back (default: 30)
      # @return [Array<Hash>] array of { date: "2023-12-01", count: 3 }
      def new_errors_over_time(days: 30)
        start_date = (Date.current - days.days).beginning_of_day

        errors_by_date = ErrorLog
          .where("created_at >= ?", start_date)
          .group("DATE(created_at)")
          .count

        # Normalize date keys to strings for consistent lookup
        normalized_errors = {}
        errors_by_date.each do |date, count|
          date_str = date.is_a?(String) ? date : date.to_s
          normalized_errors[date_str] = count
        end

        # Fill in missing dates with zero counts
        results = {}
        (0...days).each do |i|
          date = (Date.current - i.days).to_s
          results[date] = normalized_errors[date] || 0
        end

        results.sort.map { |date, count| { date: date, count: count } }
      end

      # Returns total occurrences today
      # @return [Integer]
      def total_occurrences_today
        today_start = Time.current.beginning_of_day
        ErrorOccurrence.where("created_at >= ?", today_start).count
      end
    end
  end
end
