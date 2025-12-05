# frozen_string_literal: true

module MarcoButterflyNet
  # Controller for analytics and metrics endpoints
  # Provides JSON responses for dashboard visualizations
  class AnalyticsController < ApplicationController
    # Returns summary KPI metrics
    # GET /marco_butterfly_net/analytics/summary
    def summary
      analytics = Services::Analytics.new

      render json: {
        total_open_errors: analytics.total_open_errors,
        total_affected_users_today: analytics.total_affected_users_today,
        mean_time_to_resolution: analytics.mean_time_to_resolution,
        total_occurrences_today: analytics.total_occurrences_today,
        status_breakdown: analytics.error_status_breakdown
      }
    end

    # Returns top 10 most frequent errors
    # GET /marco_butterfly_net/analytics/top_errors
    def top_errors
      analytics = Services::Analytics.new
      limit = params[:limit]&.to_i || 10

      render json: {
        top_errors: analytics.top_frequent_errors(limit: limit)
      }
    end

    # Returns time series data for charts
    # GET /marco_butterfly_net/analytics/time_series
    def time_series
      analytics = Services::Analytics.new
      days = params[:days]&.to_i || 30

      render json: {
        affected_users: analytics.affected_users_over_time(days: days),
        occurrences: analytics.error_occurrences_over_time(days: days),
        new_errors: analytics.new_errors_over_time(days: days)
      }
    end
  end
end
