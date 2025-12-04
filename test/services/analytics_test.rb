# frozen_string_literal: true

require "test_helper"

# Ensure the Analytics service is loaded
require_relative "../../lib/marco_butterfly_net/services/analytics"

module MarcoButterflyNet
  module Services
    class AnalyticsTest < ActiveSupport::TestCase
      setup do
        @analytics = Analytics.new
        ErrorLog.delete_all
        ErrorOccurrence.delete_all
      end

      test "total_open_errors returns count of open errors" do
        ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
        ErrorLog.create!(exception_class: "Error2", message: "msg2", status: "open")
        ErrorLog.create!(exception_class: "Error3", message: "msg3", status: "resolved")
        
        assert_equal 2, @analytics.total_open_errors
      end

      test "total_affected_users_today returns unique users affected today" do
        today = Time.current.beginning_of_day
        yesterday = today - 1.day
        
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")
        
        # Create occurrences today
        error_log.occurrences.create!(user_id: "user1", created_at: today)
        error_log.occurrences.create!(user_id: "user1", created_at: today + 1.hour)
        error_log.occurrences.create!(user_id: "user2", created_at: today)
        
        # Create occurrence yesterday (should not count)
        error_log.occurrences.create!(user_id: "user3", created_at: yesterday)
        
        assert_equal 2, @analytics.total_affected_users_today
      end

      test "total_affected_users_today handles users with emails" do
        today = Time.current.beginning_of_day
        
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")
        
        error_log.occurrences.create!(user_email: "user1@test.com", created_at: today)
        error_log.occurrences.create!(user_email: "user2@test.com", created_at: today)
        
        assert_equal 2, @analytics.total_affected_users_today
      end

      test "mean_time_to_resolution calculates average in hours" do
        # Create resolved error from 10 hours ago
        error1 = ErrorLog.create!(
          exception_class: "Error1",
          message: "msg1",
          status: "resolved",
          created_at: 10.hours.ago
        )
        error1.update!(resolved_at: Time.current)
        
        # Create resolved error from 20 hours ago
        error2 = ErrorLog.create!(
          exception_class: "Error2",
          message: "msg2",
          status: "resolved",
          created_at: 20.hours.ago
        )
        error2.update!(resolved_at: Time.current)
        
        # Average should be 15 hours
        assert_in_delta 15.0, @analytics.mean_time_to_resolution, 0.1
      end

      test "mean_time_to_resolution returns 0 when no resolved errors" do
        ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
        
        assert_equal 0.0, @analytics.mean_time_to_resolution
      end

      test "error_status_breakdown returns counts for all statuses" do
        ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
        ErrorLog.create!(exception_class: "Error2", message: "msg2", status: "open")
        ErrorLog.create!(exception_class: "Error3", message: "msg3", status: "in_progress")
        ErrorLog.create!(exception_class: "Error4", message: "msg4", status: "resolved")
        
        breakdown = @analytics.error_status_breakdown
        
        assert_equal 2, breakdown["open"]
        assert_equal 1, breakdown["in_progress"]
        assert_equal 1, breakdown["resolved"]
        assert_equal 0, breakdown["dismissed"]
      end

      test "top_frequent_errors returns errors sorted by occurrence count" do
        error1 = ErrorLog.create!(exception_class: "FrequentError", message: "msg1")
        error2 = ErrorLog.create!(exception_class: "RareError", message: "msg2")
        error3 = ErrorLog.create!(exception_class: "MediumError", message: "msg3")
        
        # Create different numbers of occurrences
        5.times { error1.occurrences.create! }
        2.times { error2.occurrences.create! }
        3.times { error3.occurrences.create! }
        
        top_errors = @analytics.top_frequent_errors(limit: 10)
        
        assert_equal 3, top_errors.length
        assert_equal "FrequentError", top_errors[0][:exception_class]
        assert_equal 5, top_errors[0][:occurrence_count]
        assert_equal "MediumError", top_errors[1][:exception_class]
        assert_equal 3, top_errors[1][:occurrence_count]
      end

      test "top_frequent_errors respects limit parameter" do
        5.times do |i|
          error = ErrorLog.create!(exception_class: "Error#{i}", message: "msg#{i}")
          (i + 1).times { error.occurrences.create! }
        end
        
        top_errors = @analytics.top_frequent_errors(limit: 3)
        
        assert_equal 3, top_errors.length
      end

      test "affected_users_over_time returns daily counts" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")
        
        # Create occurrences on different dates
        3.days.ago.to_date.tap do |date|
          error_log.occurrences.create!(user_id: "user1", created_at: date.to_time)
          error_log.occurrences.create!(user_id: "user2", created_at: date.to_time)
        end
        
        1.day.ago.to_date.tap do |date|
          error_log.occurrences.create!(user_id: "user3", created_at: date.to_time)
        end
        
        data = @analytics.affected_users_over_time(days: 5)
        
        assert_equal 5, data.length
        
        # Check specific date has correct count
        three_days_ago_data = data.find { |d| d[:date] == 3.days.ago.to_date.to_s }
        assert_equal 2, three_days_ago_data[:count]
        
        one_day_ago_data = data.find { |d| d[:date] == 1.day.ago.to_date.to_s }
        assert_equal 1, one_day_ago_data[:count]
      end

      test "error_occurrences_over_time returns daily occurrence counts" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")
        
        # Create occurrences on different dates
        2.days.ago.to_date.tap do |date|
          3.times { error_log.occurrences.create!(created_at: date.to_time) }
        end
        
        Date.current.tap do |date|
          2.times { error_log.occurrences.create!(created_at: date.to_time) }
        end
        
        data = @analytics.error_occurrences_over_time(days: 5)
        
        assert_equal 5, data.length
        
        two_days_ago_data = data.find { |d| d[:date] == 2.days.ago.to_date.to_s }
        assert_equal 3, two_days_ago_data[:count]
        
        today_data = data.find { |d| d[:date] == Date.current.to_s }
        assert_equal 2, today_data[:count]
      end

      test "new_errors_over_time returns daily new error counts" do
        # Create errors on different dates
        3.days.ago.to_date.tap do |date|
          2.times do |i|
            ErrorLog.create!(
              exception_class: "Error#{i}",
              message: "msg#{i}",
              created_at: date.to_time
            )
          end
        end
        
        Date.current.tap do |date|
          ErrorLog.create!(
            exception_class: "RecentError",
            message: "msg",
            created_at: date.to_time
          )
        end
        
        data = @analytics.new_errors_over_time(days: 5)
        
        assert_equal 5, data.length
        
        three_days_ago_data = data.find { |d| d[:date] == 3.days.ago.to_date.to_s }
        assert_equal 2, three_days_ago_data[:count]
        
        today_data = data.find { |d| d[:date] == Date.current.to_s }
        assert_equal 1, today_data[:count]
      end

      test "total_occurrences_today returns count of occurrences today" do
        today = Time.current.beginning_of_day
        yesterday = today - 1.day
        
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")
        
        3.times { error_log.occurrences.create!(created_at: today) }
        2.times { error_log.occurrences.create!(created_at: yesterday) }
        
        assert_equal 3, @analytics.total_occurrences_today
      end
    end
  end
end
