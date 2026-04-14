# frozen_string_literal: true

require "butterfly_net/analytics_date_range"

module ButterflyNet
  # Controller for analytics and metrics endpoints
  # Provides JSON responses for dashboard visualizations
  class AnalyticsController < ApplicationController
    before_action :set_date_range_and_analytics

    # Returns summary KPI metrics
    # GET /butterfly_net/analytics/summary
    def summary
      render json: {
        total_open_errors: @analytics.total_open_errors,
        total_affected_users: @analytics.total_affected_users,
        mean_time_to_resolution: @analytics.mean_time_to_resolution,
        total_occurrences: @analytics.total_occurrences,
        status_breakdown: @analytics.error_status_breakdown
      }
    end

    # Returns top 10 most frequent errors
    # GET /butterfly_net/analytics/top_errors
    def top_errors
      limit = params[:limit]&.to_i || 10

      render json: {
        top_errors: @analytics.top_frequent_errors(limit: limit)
      }
    end

    # Returns time series data for charts
    # GET /butterfly_net/analytics/time_series
    def time_series
      render json: {
        affected_users: @analytics.affected_users_over_time(start_date: @date_range.start_date, end_date: @date_range.end_date),
        occurrences: @analytics.error_occurrences_over_time(start_date: @date_range.start_date, end_date: @date_range.end_date),
        new_errors: @analytics.new_errors_over_time(start_date: @date_range.start_date, end_date: @date_range.end_date)
      }
    end

    private

    # Parses date range from params (defaults to past 7 days) and initializes the analytics service.
    def set_date_range_and_analytics
      @date_range = AnalyticsDateRange.from_params(
        start_date: params[:start_date],
        end_date: params[:end_date]
      )
      @analytics = Services::Analytics.new(start_time: @date_range.start_time, end_time: @date_range.end_time)
    end
  end
end
