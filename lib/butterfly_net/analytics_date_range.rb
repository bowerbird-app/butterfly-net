# frozen_string_literal: true

module ButterflyNet
  class AnalyticsDateRange
    DEFAULT_DAYS = 7

    attr_reader :start_date, :end_date

    # Builds an AnalyticsDateRange from raw query string parameters.
    def self.from_params(start_date:, end_date:, default_days: DEFAULT_DAYS)
      new(
        start_date: parse_date(start_date),
        end_date: parse_date(end_date),
        default_days: default_days
      )
    end

    # Sets the date range from the given dates, falling back to the default range if invalid.
    def initialize(start_date: nil, end_date: nil, default_days: DEFAULT_DAYS)
      @default_days = [ default_days.to_i, 1 ].max

      if start_date.present? && end_date.present? && end_date >= start_date
        @start_date = start_date
        @end_date = end_date
      else
        apply_default_range
      end
    end

    # Returns the start date as a Time at the beginning of the day.
    def start_time
      start_date.beginning_of_day
    end

    # Returns the end date as a Time at the end of the day.
    def end_time
      end_date.end_of_day
    end

    # Returns the number of days in the range (inclusive).
    def days
      (end_date - start_date).to_i + 1
    end

    # Returns the range as a hash of ISO8601 strings suitable for URL params.
    def to_param_hash
      {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      }
    end

    # Returns a human-readable label, e.g. "Past 7 Days" or "Apr 8, 2026 - Apr 14, 2026".
    def label
      if days == DEFAULT_DAYS && end_date == Date.current
        "Past #{days} Days"
      else
        "#{start_date.strftime('%b %-d, %Y')} - #{end_date.strftime('%b %-d, %Y')}"
      end
    end

    private

    # Safely parses an ISO8601 date string, returning nil on invalid input.
    def self.parse_date(value)
      return if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    # Sets start_date and end_date to the default range (past N days ending today).
    def apply_default_range
      @end_date = Date.current
      @start_date = @end_date - (@default_days - 1).days
    end
  end
end
