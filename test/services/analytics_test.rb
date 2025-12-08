# frozen_string_literal: true

require "test_helper"

# Ensure the Analytics service is loaded
require_relative "../../lib/marco_butterfly_net/services/analytics"

module MarcoButterflyNet
  module Services
    class AnalyticsTest < ActiveSupport::TestCase
      setup do
        @analytics = Analytics.new
        ErrorOccurrence.delete_all
        ErrorLog.delete_all
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

      test "total_affected_users_today counts users by ID and email separately" do
        today = Time.current.beginning_of_day

        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # Some users with IDs
        error_log.occurrences.create!(user_id: "user1", created_at: today)
        error_log.occurrences.create!(user_id: "user2", created_at: today)

        # Some users with emails (different from IDs)
        error_log.occurrences.create!(user_email: "email1@test.com", created_at: today)
        error_log.occurrences.create!(user_email: "email2@test.com", created_at: today)

        # Duplicate IDs and emails should be counted once
        error_log.occurrences.create!(user_id: "user1", created_at: today)
        error_log.occurrences.create!(user_email: "email1@test.com", created_at: today)

        # Total unique identifiers: user1, user2, email1@test.com, email2@test.com = 4
        assert_equal 4, @analytics.total_affected_users_today
      end

      test "mean_time_to_resolution handles mix of resolved and unresolved errors" do
        # Create resolved error from 10 hours ago
        error1 = ErrorLog.create!(
          exception_class: "Error1",
          message: "msg1",
          status: "resolved",
          created_at: 10.hours.ago
        )
        error1.update!(resolved_at: Time.current)

        # Create unresolved error (should be ignored)
        ErrorLog.create!(
          exception_class: "Error2",
          message: "msg2",
          status: "open",
          created_at: 20.hours.ago
        )

        # Only resolved error should be counted
        assert_in_delta 10.0, @analytics.mean_time_to_resolution, 0.1
      end

      test "top_frequent_errors returns empty array when no errors exist" do
        top_errors = @analytics.top_frequent_errors(limit: 10)

        assert_equal [], top_errors
      end

      test "top_frequent_errors includes errors with zero occurrences" do
        # Create error with no occurrences
        error_without_occurrences = ErrorLog.create!(exception_class: "NoOccurrenceError", message: "msg")

        # Create error with occurrences
        error_with_occurrences = ErrorLog.create!(exception_class: "HasOccurrenceError", message: "msg")
        error_with_occurrences.occurrences.create!

        top_errors = @analytics.top_frequent_errors(limit: 10)

        # Only errors with occurrences are included (due to inner join)
        assert_equal 1, top_errors.length
        assert_equal "HasOccurrenceError", top_errors[0][:exception_class]
        assert_equal 1, top_errors[0][:occurrence_count]
      end

      test "affected_users_over_time handles dates with no data" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # Create occurrence only on one specific day
        3.days.ago.to_date.tap do |date|
          error_log.occurrences.create!(user_id: "user1", created_at: date.to_time)
        end

        data = @analytics.affected_users_over_time(days: 5)

        # Should have 5 days of data
        assert_equal 5, data.length

        # Days without data should have count 0
        zero_count_days = data.select { |d| d[:count] == 0 }
        assert_equal 4, zero_count_days.length

        # Day with data should have count 1
        data_day = data.find { |d| d[:date] == 3.days.ago.to_date.to_s }
        assert_equal 1, data_day[:count]
      end

      test "error_occurrences_over_time handles multiple occurrences on same day" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # Create multiple occurrences on the same day
        today = Date.current
        5.times { error_log.occurrences.create!(created_at: today.to_time) }

        data = @analytics.error_occurrences_over_time(days: 1)

        today_data = data.find { |d| d[:date] == today.to_s }
        assert_equal 5, today_data[:count]
      end

      test "new_errors_over_time counts each error once even with multiple occurrences" do
        # Create error on a specific day
        3.days.ago.to_date.tap do |date|
          error = ErrorLog.create!(
            exception_class: "TestError",
            message: "msg",
            created_at: date.to_time
          )
          # Add multiple occurrences
          3.times { error.occurrences.create!(created_at: date.to_time) }
        end

        data = @analytics.new_errors_over_time(days: 5)

        three_days_ago_data = data.find { |d| d[:date] == 3.days.ago.to_date.to_s }
        # Should count the error only once, not 3 times
        assert_equal 1, three_days_ago_data[:count]
      end

      test "error_status_breakdown returns zero for statuses with no errors" do
        # Create only open errors
        ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")

        breakdown = @analytics.error_status_breakdown

        assert_equal 1, breakdown["open"]
        assert_equal 0, breakdown["in_progress"]
        assert_equal 0, breakdown["resolved"]
        assert_equal 0, breakdown["dismissed"]
      end

      # Additional edge case tests for complete coverage
      test "total_affected_users_today handles users with both ID and email" do
        today = Time.current.beginning_of_day

        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # User with both ID and email (should count as one user by ID)
        error_log.occurrences.create!(user_id: "user1", user_email: "user1@test.com", created_at: today)
        # Same user ID, different email (should still count as one user)
        error_log.occurrences.create!(user_id: "user1", user_email: "different@test.com", created_at: today)
        # Different user ID
        error_log.occurrences.create!(user_id: "user2", user_email: "user2@test.com", created_at: today)

        # user1 and user2 = 2 users
        assert_equal 2, @analytics.total_affected_users_today
      end

      test "total_affected_users_today ignores occurrences without user identification" do
        today = Time.current.beginning_of_day

        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        error_log.occurrences.create!(user_id: "user1", created_at: today)
        error_log.occurrences.create!(user_email: "user2@test.com", created_at: today)
        # Occurrence with neither user_id nor user_email
        error_log.occurrences.create!(user_id: nil, user_email: nil, created_at: today)
        # Occurrence with blank values
        error_log.occurrences.create!(user_id: "", user_email: "", created_at: today)

        # Only user1 and user2@test.com should count
        assert_equal 2, @analytics.total_affected_users_today
      end

      test "mean_time_to_resolution handles resolved errors with same created and resolved time" do
        # Error resolved immediately
        error = ErrorLog.create!(
          exception_class: "FastError",
          message: "msg",
          status: "resolved",
          created_at: Time.current
        )
        error.update!(resolved_at: error.created_at)

        # Should return 0.0 hours
        assert_equal 0.0, @analytics.mean_time_to_resolution
      end

      test "mean_time_to_resolution only includes errors with resolved_at set" do
        # Resolved error without resolved_at (should be ignored)
        ErrorLog.create!(
          exception_class: "Error1",
          message: "msg1",
          status: "resolved",
          resolved_at: nil,
          created_at: 10.hours.ago
        )

        # Resolved error with resolved_at
        error2 = ErrorLog.create!(
          exception_class: "Error2",
          message: "msg2",
          status: "resolved",
          created_at: 5.hours.ago
        )
        error2.update!(resolved_at: Time.current)

        # Should only count error2
        assert_in_delta 5.0, @analytics.mean_time_to_resolution, 0.1
      end

      test "top_frequent_errors handles errors with same occurrence count" do
        error1 = ErrorLog.create!(exception_class: "Error1", message: "msg1")
        error2 = ErrorLog.create!(exception_class: "Error2", message: "msg2")
        error3 = ErrorLog.create!(exception_class: "Error3", message: "msg3")

        # All have same number of occurrences
        2.times { error1.occurrences.create! }
        2.times { error2.occurrences.create! }
        2.times { error3.occurrences.create! }

        top_errors = @analytics.top_frequent_errors(limit: 10)

        assert_equal 3, top_errors.length
        # All should have occurrence_count of 2
        top_errors.each do |error|
          assert_equal 2, error[:occurrence_count]
        end
      end

      test "affected_users_over_time handles same user on multiple days" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # Same user on different days
        3.days.ago.to_date.tap do |date|
          error_log.occurrences.create!(user_id: "user1", created_at: date.to_time)
        end

        1.day.ago.to_date.tap do |date|
          error_log.occurrences.create!(user_id: "user1", created_at: date.to_time)
        end

        data = @analytics.affected_users_over_time(days: 5)

        # Should count user1 on each day separately
        three_days_ago_data = data.find { |d| d[:date] == 3.days.ago.to_date.to_s }
        assert_equal 1, three_days_ago_data[:count]

        one_day_ago_data = data.find { |d| d[:date] == 1.day.ago.to_date.to_s }
        assert_equal 1, one_day_ago_data[:count]
      end

      test "error_occurrences_over_time returns data in ascending date order" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # Create occurrences on different dates
        2.days.ago.to_date.tap do |date|
          error_log.occurrences.create!(created_at: date.to_time)
        end

        Date.current.tap do |date|
          error_log.occurrences.create!(created_at: date.to_time)
        end

        data = @analytics.error_occurrences_over_time(days: 3)

        # Data should be sorted by date ascending
        dates = data.map { |d| d[:date] }
        assert_equal dates.sort, dates
      end

      test "new_errors_over_time returns data in ascending date order" do
        2.days.ago.to_date.tap do |date|
          ErrorLog.create!(
            exception_class: "OldError",
            message: "msg",
            created_at: date.to_time
          )
        end

        Date.current.tap do |date|
          ErrorLog.create!(
            exception_class: "NewError",
            message: "msg",
            created_at: date.to_time
          )
        end

        data = @analytics.new_errors_over_time(days: 3)

        # Data should be sorted by date ascending
        dates = data.map { |d| d[:date] }
        assert_equal dates.sort, dates
      end

      test "total_occurrences_today counts all occurrences regardless of user" do
        today = Time.current.beginning_of_day
        yesterday = today - 1.day

        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        # Occurrences with users
        2.times { error_log.occurrences.create!(user_id: "user1", created_at: today) }
        # Occurrences without users
        1.times { error_log.occurrences.create!(created_at: today) }
        # Yesterday's occurrences (should not count)
        2.times { error_log.occurrences.create!(created_at: yesterday) }

        assert_equal 3, @analytics.total_occurrences_today
      end

      test "affected_users_over_time with days parameter of 1 returns only today" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        Date.current.tap do |date|
          error_log.occurrences.create!(user_id: "user1", created_at: date.to_time)
        end

        data = @analytics.affected_users_over_time(days: 1)

        assert_equal 1, data.length
        assert_equal Date.current.to_s, data.first[:date]
      end

      test "error_occurrences_over_time with days parameter of 1 returns only today" do
        error_log = ErrorLog.create!(exception_class: "Error", message: "msg")

        Date.current.tap do |date|
          error_log.occurrences.create!(created_at: date.to_time)
        end

        data = @analytics.error_occurrences_over_time(days: 1)

        assert_equal 1, data.length
        assert_equal Date.current.to_s, data.first[:date]
      end

      test "new_errors_over_time with days parameter of 1 returns only today" do
        Date.current.tap do |date|
          ErrorLog.create!(
            exception_class: "TodayError",
            message: "msg",
            created_at: date.to_time
          )
        end

        data = @analytics.new_errors_over_time(days: 1)

        assert_equal 1, data.length
        assert_equal Date.current.to_s, data.first[:date]
      end
    end
  end
end
