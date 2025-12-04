# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ErrorTrackingWorkflowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    MarcoButterflyNet.clear_captured_exceptions
    MarcoButterflyNet::ErrorOccurrence.delete_all
    MarcoButterflyNet::ErrorLog.delete_all
  end

  teardown do
    MarcoButterflyNet.clear_captured_exceptions
  end

  # Tests for complete error tracking workflow
  test "error capture to automatic blame fetch to manual issue creation workflow" do
    # Step 1: Capture an error
    assert_raises(RuntimeError) do
      get "/test/runtime_error"
    end

    # Verify error was captured and persisted
    assert_equal 1, MarcoButterflyNet::ErrorLog.count
    error_log = MarcoButterflyNet::ErrorLog.last
    assert_equal "RuntimeError", error_log.exception_class
    assert_not_nil error_log.backtrace

    # Step 2: The FetchBlameJob would have been enqueued automatically, 
    # but since we're in test mode, we manually trigger it
    # Clear blame info first to ensure we're testing the fetch
    error_log.update_columns(
      blame_file: nil,
      blame_line_number: nil,
      blame_commit_sha: nil,
      blame_author_name: nil,
      blame_author_email: nil,
      blame_commit_date: nil
    )

    # Mock the GitBlame service
    blame_result = MarcoButterflyNet::Services::GitBlame::BlameResult.new(
      file: "app/controllers/test_errors_controller.rb",
      line_number: 10,
      commit_sha: "abc123",
      author_name: "Test Author",
      author_email: "test@example.com",
      commit_date: Time.current,
      line_content: "raise RuntimeError"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, blame_result, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      # Manually perform the job
      MarcoButterflyNet::FetchBlameJob.perform_now(error_log.id)
    end

    # Verify blame information was fetched
    error_log.reload
    assert_equal "app/controllers/test_errors_controller.rb", error_log.blame_file
    assert_equal 10, error_log.blame_line_number
    assert_equal "abc123", error_log.blame_commit_sha

    service_mock.verify

    # Step 3: Manual issue creation
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    # Mock GitHub issue creation
    github_mock = Minitest::Mock.new
    def github_mock.create_issue_for_error(*args, **kwargs)
      MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
        success: true,
        issue_number: 123,
        issue_url: "https://github.com/test_owner/test_repo/issues/123",
        error_message: nil
      )
    end

    MarcoButterflyNet::Services::GitHubIssueCreator.stub(:new, github_mock) do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end

    # Verify issue was created
    error_log.reload
    assert_equal 123, error_log.github_issue_number
    assert_equal "https://github.com/test_owner/test_repo/issues/123", error_log.github_issue_url

    MarcoButterflyNet.reset_configuration!
  end

  test "multiple occurrences of same error groups correctly" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    # Create same error twice with different users
    2.times do
      error_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
        exception_class: "RepeatedError",
        message: "This error happens multiple times",
        user_id: user1_id,
        user_email: "user1@example.com"
      )
    end

    MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "RepeatedError",
      message: "This error happens multiple times",
      user_id: user2_id,
      user_email: "user2@example.com"
    )

    # Verify only one error log was created
    assert_equal 1, MarcoButterflyNet::ErrorLog.count
    error_log = MarcoButterflyNet::ErrorLog.last

    # Verify it has 3 occurrences
    assert_equal 3, error_log.occurrence_count
    assert error_log.repeated?

    # Verify it affected 2 users
    assert_equal 2, error_log.affected_users_count
  end

  test "error status lifecycle: open to in_progress to resolved" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Initially open
    assert_equal "open", error_log.status
    assert_nil error_log.resolved_at

    # Move to in_progress
    error_log.update!(status: "in_progress")
    assert_equal "in_progress", error_log.status
    assert_nil error_log.resolved_at

    # Move to resolved
    travel_to Time.zone.local(2025, 12, 4, 12, 0, 0) do
      error_log.update!(status: "resolved")
    end

    error_log.reload
    assert_equal "resolved", error_log.status
    assert_not_nil error_log.resolved_at
    assert_equal Time.zone.local(2025, 12, 4, 12, 0, 0), error_log.resolved_at

    # Reopen the error
    error_log.update!(status: "open")
    error_log.reload
    assert_equal "open", error_log.status
    assert_nil error_log.resolved_at
  end

  test "user-specific error filtering and tracking" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid
    user1_email = "user1@example.com"
    user2_email = "user2@example.com"

    # Create errors affecting different users
    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_id: user1_id, user_email: user1_email)
    error1.record_occurrence(user_id: user1_id, user_email: user1_email)

    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_id: user2_id, user_email: user2_email)

    error3 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error3")
    error3.record_occurrence(user_id: user1_id, user_email: user1_email)
    error3.record_occurrence(user_id: user2_id, user_email: user2_email)

    # Filter by user1_id
    user1_errors = MarcoButterflyNet::ErrorLog.affecting_user(user1_id)
    assert_equal 2, user1_errors.count
    assert_includes user1_errors.pluck(:exception_class), "Error1"
    assert_includes user1_errors.pluck(:exception_class), "Error3"

    # Filter by user1_email
    user1_email_errors = MarcoButterflyNet::ErrorLog.affecting_user_email(user1_email)
    assert_equal 2, user1_email_errors.count

    # Filter by user2_id
    user2_errors = MarcoButterflyNet::ErrorLog.affecting_user(user2_id)
    assert_equal 2, user2_errors.count
    assert_includes user2_errors.pluck(:exception_class), "Error2"
    assert_includes user2_errors.pluck(:exception_class), "Error3"

    # Check occurrences for specific user
    user1_occurrences_for_error1 = error1.occurrences_for_user(user1_id)
    assert_equal 2, user1_occurrences_for_error1.count
  end

  # Tests for analytics dashboard workflow
  test "visiting analytics page loads successfully" do
    # Create some test data
    3.times do |i|
      error_log = MarcoButterflyNet::ErrorLog.create!(
        exception_class: "Error#{i}",
        message: "Message #{i}"
      )
      error_log.record_occurrence
    end

    get marco_butterfly_net.analytics_path

    assert_response :success
    assert_match /Analytics/, response.body
  end

  test "analytics API endpoints return expected JSON structure" do
    # Create test data with different statuses and dates
    travel_to 2.days.ago do
      error1 = MarcoButterflyNet::ErrorLog.create!(
        exception_class: "OldError",
        message: "Old error",
        status: "resolved"
      )
      error1.record_occurrence
    end

    travel_to 1.day.ago do
      error2 = MarcoButterflyNet::ErrorLog.create!(
        exception_class: "RecentError",
        message: "Recent error",
        status: "open"
      )
      error2.record_occurrence
      error2.record_occurrence
    end

    # Test time series endpoint
    get marco_butterfly_net.analytics_time_series_path(days: 7), headers: { "Accept" => "application/json" }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response.key?("affected_users")
    assert json_response.key?("occurrences")
    assert json_response.key?("new_errors")
    assert json_response["affected_users"].is_a?(Array)
    assert json_response["occurrences"].is_a?(Array)
    assert json_response["new_errors"].is_a?(Array)
  end

  test "time series data for different date ranges" do
    # Create errors over different time periods
    travel_to 30.days.ago do
      error = MarcoButterflyNet::ErrorLog.create!(exception_class: "MonthOldError")
      error.record_occurrence
    end

    travel_to 7.days.ago do
      error = MarcoButterflyNet::ErrorLog.create!(exception_class: "WeekOldError")
      error.record_occurrence
    end

    travel_to 1.day.ago do
      error = MarcoButterflyNet::ErrorLog.create!(exception_class: "DayOldError")
      error.record_occurrence
    end

    # Test 30 days period
    get marco_butterfly_net.analytics_time_series_path(days: 30), headers: { "Accept" => "application/json" }
    assert_response :success
    month_data = JSON.parse(response.body)
    assert_equal 30, month_data["affected_users"].length
    assert_equal 30, month_data["occurrences"].length
    assert_equal 30, month_data["new_errors"].length

    # Test 7 days period
    get marco_butterfly_net.analytics_time_series_path(days: 7), headers: { "Accept" => "application/json" }
    assert_response :success
    week_data = JSON.parse(response.body)
    assert_equal 7, week_data["affected_users"].length
    assert_equal 7, week_data["occurrences"].length
    assert_equal 7, week_data["new_errors"].length

    # Test 1 day period
    get marco_butterfly_net.analytics_time_series_path(days: 1), headers: { "Accept" => "application/json" }
    assert_response :success
    day_data = JSON.parse(response.body)
    assert_equal 1, day_data["affected_users"].length
    assert_equal 1, day_data["occurrences"].length
    assert_equal 1, day_data["new_errors"].length
  end
end
