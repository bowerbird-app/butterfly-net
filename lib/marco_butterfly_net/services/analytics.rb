# frozen_string_literal: true

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
        
        user_ids = ErrorOccurrence
          .where("created_at >= ?", today_start)
          .where.not(user_id: nil)
          .distinct
          .count(:user_id)
        
        user_emails = ErrorOccurrence
          .where("created_at >= ?", today_start)
          .where.not(user_email: nil)
          .distinct
          .count(:user_email)
        
        # Return the max to avoid double-counting users who have both ID and email
        [ user_ids, user_emails ].max
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
        
        # Get occurrences grouped by date with distinct user counts
        daily_data = ErrorOccurrence
          .where("created_at >= ?", start_date)
          .group("DATE(created_at)")
          .select("DATE(created_at) as date")
        
        # Count distinct users per day
        results = {}
        (0...days).each do |i|
          date = Date.current - i.days
          date_str = date.to_s
          
          user_ids = ErrorOccurrence
            .where("DATE(created_at) = ?", date)
            .where.not(user_id: nil)
            .distinct
            .count(:user_id)
          
          user_emails = ErrorOccurrence
            .where("DATE(created_at) = ?", date)
            .where.not(user_email: nil)
            .distinct
            .count(:user_email)
          
          results[date_str] = [ user_ids, user_emails ].max
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
        
        # Fill in missing dates with zero counts
        results = {}
        (0...days).each do |i|
          date = (Date.current - i.days).to_s
          results[date] = occurrences_by_date[date] || 0
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
        
        # Fill in missing dates with zero counts
        results = {}
        (0...days).each do |i|
          date = (Date.current - i.days).to_s
          results[date] = errors_by_date[date] || 0
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
