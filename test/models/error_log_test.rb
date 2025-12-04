# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::ErrorLogTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    MarcoButterflyNet::ErrorOccurrence.delete_all
    MarcoButterflyNet::ErrorLog.delete_all
  end

  test "creates error log with required fields" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error message",
      backtrace: "line 1\nline 2\nline 3",
      request_params: { path: "/test", method: "GET" },
      user_agent: "Test Browser"
    )

    assert error_log.persisted?
    assert_equal "RuntimeError", error_log.exception_class
    assert_equal "Test error message", error_log.message
    assert_equal "Test Browser", error_log.user_agent
  end

  test "requires exception_class" do
    error_log = MarcoButterflyNet::ErrorLog.new(
      message: "Test error"
    )

    assert_not error_log.valid?
    assert_includes error_log.errors[:exception_class], "can't be blank"
  end

  test "backtrace_lines returns array from text" do
    error_log = MarcoButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      backtrace: "line 1\nline 2\nline 3"
    )

    assert_equal [ "line 1", "line 2", "line 3" ], error_log.backtrace_lines
  end

  test "backtrace_lines returns empty array when backtrace is nil" do
    error_log = MarcoButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      backtrace: nil
    )

    assert_equal [], error_log.backtrace_lines
  end

  test "params_hash returns request_params or empty hash" do
    error_log_with_params = MarcoButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      request_params: { path: "/test" }
    )

    error_log_without_params = MarcoButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      request_params: nil
    )

    assert_equal({ "path" => "/test" }, error_log_with_params.params_hash)
    assert_equal({}, error_log_without_params.params_hash)
  end

  test "recent scope orders by created_at desc" do
    old_error = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "OldError",
      created_at: 1.day.ago
    )

    new_error = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "NewError",
      created_at: Time.current
    )

    recent_errors = MarcoButterflyNet::ErrorLog.recent

    assert_equal new_error, recent_errors.first
    assert_equal old_error, recent_errors.last
  end

  test "by_exception_class scope filters by class" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "NoMethodError")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    runtime_errors = MarcoButterflyNet::ErrorLog.by_exception_class("RuntimeError")

    assert_equal 2, runtime_errors.count
    assert runtime_errors.all? { |e| e.exception_class == "RuntimeError" }
  end

  # Tests for occurrence tracking
  test "new error log has occurrence_count of 0" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_equal 0, error_log.occurrence_count
  end

  test "record_occurrence creates an occurrence" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    user_id = SecureRandom.uuid

    occurrence = error_log.record_occurrence(user_id: user_id, user_email: "test@example.com")

    assert occurrence.persisted?
    assert_equal user_id, occurrence.user_id
    assert_equal "test@example.com", occurrence.user_email
    assert_equal 1, error_log.occurrence_count
  end

  test "repeated? returns false for no occurrences" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.repeated?
  end

  test "repeated? returns false for single occurrence" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence

    assert_not error_log.repeated?
  end

  test "repeated? returns true for multiple occurrences" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence
    error_log.record_occurrence

    assert error_log.repeated?
  end

  test "repeated scope filters errors with more than one occurrence" do
    single = MarcoButterflyNet::ErrorLog.create!(exception_class: "SingleError")
    single.record_occurrence

    repeated = MarcoButterflyNet::ErrorLog.create!(exception_class: "RepeatedError")
    repeated.record_occurrence
    repeated.record_occurrence

    repeated_errors = MarcoButterflyNet::ErrorLog.repeated

    assert_equal 1, repeated_errors.count
    assert_equal "RepeatedError", repeated_errors.first.exception_class
  end

  test "find_or_create_with_occurrence groups same errors together" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    error1 = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "SameError",
      message: "Same message",
      user_id: user1_id,
      user_email: "user1@example.com"
    )

    error2 = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "SameError",
      message: "Same message",
      user_id: user2_id,
      user_email: "user2@example.com"
    )

    # Same error log for both users
    assert_equal error1.id, error2.id
    assert_equal 1, MarcoButterflyNet::ErrorLog.count
    assert_equal 2, error1.occurrence_count
    assert_equal 2, error1.occurrences.count

    # But occurrences are separate
    assert_equal 2, MarcoButterflyNet::ErrorOccurrence.count
    assert error1.occurrences.exists?(user_id: user1_id)
    assert error1.occurrences.exists?(user_id: user2_id)
  end

  test "find_or_create_with_occurrence creates new error for different exception" do
    error1 = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "Error1",
      message: "Message 1"
    )

    error2 = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "Error2",
      message: "Message 2"
    )

    assert_not_equal error1.id, error2.id
    assert_equal 2, MarcoButterflyNet::ErrorLog.count
  end

  test "occurrences_for_user returns only that users occurrences" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_id: user1_id)
    error_log.record_occurrence(user_id: user1_id)
    error_log.record_occurrence(user_id: user2_id)

    user1_occurrences = error_log.occurrences_for_user(user1_id)

    assert_equal 2, user1_occurrences.count
    assert user1_occurrences.all? { |o| o.user_id == user1_id }
  end

  test "affected_users_count returns unique user count" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_id: user1_id)
    error_log.record_occurrence(user_id: user1_id)
    error_log.record_occurrence(user_id: user2_id)
    error_log.record_occurrence  # No user

    assert_equal 2, error_log.affected_users_count
  end

  test "affecting_user scope filters errors that affected a user" do
    user_id = SecureRandom.uuid
    other_user_id = SecureRandom.uuid

    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_id: user_id)

    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_id: other_user_id)

    user_errors = MarcoButterflyNet::ErrorLog.affecting_user(user_id)

    assert_equal 1, user_errors.count
    assert_equal "Error1", user_errors.first.exception_class
  end

  # Tests for status tracking
  test "new error log has status of 'open' by default" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_equal "open", error_log.status
  end

  test "with_status scope filters by status" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "OpenError", status: "open")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "ResolvedError", status: "resolved")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "InProgressError", status: "in_progress")

    open_errors = MarcoButterflyNet::ErrorLog.with_status("open")
    resolved_errors = MarcoButterflyNet::ErrorLog.with_status("resolved")

    assert_equal 1, open_errors.count
    assert_equal "OpenError", open_errors.first.exception_class
    assert_equal 1, resolved_errors.count
    assert_equal "ResolvedError", resolved_errors.first.exception_class
  end

  test "open scope filters open errors" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "OpenError", status: "open")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "ResolvedError", status: "resolved")

    open_errors = MarcoButterflyNet::ErrorLog.open

    assert_equal 1, open_errors.count
    assert_equal "OpenError", open_errors.first.exception_class
  end

  test "resolved scope filters resolved errors" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "OpenError", status: "open")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "ResolvedError", status: "resolved")

    resolved_errors = MarcoButterflyNet::ErrorLog.resolved

    assert_equal 1, resolved_errors.count
    assert_equal "ResolvedError", resolved_errors.first.exception_class
  end

  test "validates status is in STATUSES" do
    error_log = MarcoButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      status: "invalid_status"
    )

    assert_not error_log.valid?
    assert_includes error_log.errors[:status], "is not included in the list"
  end

  test "allows valid statuses" do
    MarcoButterflyNet::ErrorLog::STATUSES.each do |status|
      error_log = MarcoButterflyNet::ErrorLog.new(
        exception_class: "RuntimeError",
        status: status
      )

      assert error_log.valid?, "Expected status '#{status}' to be valid"
    end
  end

  # Tests for automatic blame fetching
  test "creating an error log with backtrace enqueues a FetchBlameJob" do
    assert_enqueued_with(job: MarcoButterflyNet::FetchBlameJob) do
      error_log = MarcoButterflyNet::ErrorLog.create!(
        exception_class: "RuntimeError",
        message: "Test error",
        backtrace: "/app/models/user.rb:42:in `save'"
      )
    end
  end

  test "creating an error log without backtrace does NOT enqueue a job" do
    assert_no_enqueued_jobs(only: MarcoButterflyNet::FetchBlameJob) do
      MarcoButterflyNet::ErrorLog.create!(
        exception_class: "RuntimeError",
        message: "Test error",
        backtrace: nil
      )
    end
  end

  test "creating an error log that already has blame info does NOT enqueue a job" do
    assert_no_enqueued_jobs(only: MarcoButterflyNet::FetchBlameJob) do
      MarcoButterflyNet::ErrorLog.create!(
        exception_class: "RuntimeError",
        message: "Test error",
        backtrace: "/app/models/user.rb:42:in `save'",
        blame_file: "app/models/user.rb",
        blame_line_number: 42,
        blame_commit_sha: "abc123",
        blame_author_name: "Test Author",
        blame_author_email: "test@example.com",
        blame_commit_date: Time.current
      )
    end
  end

  test "updating an existing error log does NOT enqueue a job" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Original message"
    )

    assert_no_enqueued_jobs(only: MarcoButterflyNet::FetchBlameJob) do
      error_log.update!(message: "Updated message")
    end
  end

  # Tests for GitHub issue scopes
  test "with_github_issue scope returns only errors with github_issue_number" do
    with_issue = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "ErrorWithIssue",
      github_issue_number: 123
    )

    without_issue = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "ErrorWithoutIssue"
    )

    errors_with_issue = MarcoButterflyNet::ErrorLog.with_github_issue

    assert_equal 1, errors_with_issue.count
    assert_includes errors_with_issue, with_issue
    assert_not_includes errors_with_issue, without_issue
  end

  test "without_github_issue scope returns only errors without github_issue_number" do
    with_issue = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "ErrorWithIssue",
      github_issue_number: 123
    )

    without_issue = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "ErrorWithoutIssue"
    )

    errors_without_issue = MarcoButterflyNet::ErrorLog.without_github_issue

    assert_equal 1, errors_without_issue.count
    assert_includes errors_without_issue, without_issue
    assert_not_includes errors_without_issue, with_issue
  end

  test "has_github_issue? returns true when github_issue_number present" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      github_issue_number: 456
    )

    assert error_log.has_github_issue?
  end

  test "has_github_issue? returns false when github_issue_number is nil" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      github_issue_number: nil
    )

    assert_not error_log.has_github_issue?
  end

  # Tests for blame information methods
  test "has_blame_info? returns true when blame_file and blame_commit_sha present" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      blame_file: "app/models/user.rb",
      blame_commit_sha: "abc123"
    )

    assert error_log.has_blame_info?
  end

  test "has_blame_info? returns false when blame fields are missing" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError"
    )

    assert_not error_log.has_blame_info?
  end

  test "has_blame_info? returns false when only blame_file is set" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      blame_file: "app/models/user.rb",
      blame_commit_sha: nil
    )

    assert_not error_log.has_blame_info?
  end

  test "has_blame_info? returns false when only blame_commit_sha is set" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      blame_file: nil,
      blame_commit_sha: "abc123"
    )

    assert_not error_log.has_blame_info?
  end

  # Tests for user email filtering
  test "affecting_user_email scope filters errors by user email" do
    user_email = "test@example.com"
    other_email = "other@example.com"

    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_email: user_email)

    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_email: other_email)

    user_errors = MarcoButterflyNet::ErrorLog.affecting_user_email(user_email)

    assert_equal 1, user_errors.count
    assert_equal "Error1", user_errors.first.exception_class
  end

  test "affecting_user_email scope returns empty when email not found" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error_log.record_occurrence(user_email: "other@example.com")

    user_errors = MarcoButterflyNet::ErrorLog.affecting_user_email("notfound@example.com")

    assert_equal 0, user_errors.count
  end

  test "occurrences_for_user_email returns only occurrences for that email" do
    user_email = "test@example.com"
    other_email = "other@example.com"

    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_email: user_email)
    error_log.record_occurrence(user_email: user_email)
    error_log.record_occurrence(user_email: other_email)

    user_occurrences = error_log.occurrences_for_user_email(user_email)

    assert_equal 2, user_occurrences.count
    assert user_occurrences.all? { |o| o.user_email == user_email }
  end

  test "occurrences_for_user_email returns empty array when email not found" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_email: "other@example.com")

    user_occurrences = error_log.occurrences_for_user_email("notfound@example.com")

    assert_equal 0, user_occurrences.count
  end

  # Tests for resolved timestamp callback
  test "resolved_at is set when status changes to 'resolved'" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    travel_to Time.zone.local(2025, 12, 4, 12, 0, 0) do
      error_log.update!(status: "resolved")
    end

    error_log.reload
    assert_not_nil error_log.resolved_at
    assert_equal Time.zone.local(2025, 12, 4, 12, 0, 0), error_log.resolved_at
  end

  test "resolved_at is NOT set when creating with status 'resolved'" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "resolved"
    )

    assert_nil error_log.resolved_at
  end

  test "resolved_at is cleared when status changes from 'resolved' to another status" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    error_log.update!(status: "resolved")
    assert_not_nil error_log.resolved_at

    error_log.update!(status: "open")
    error_log.reload
    assert_nil error_log.resolved_at
  end

  test "resolved_at remains unchanged when status doesn't change" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    error_log.update!(status: "resolved")
    original_resolved_at = error_log.resolved_at

    travel_to 1.hour.from_now do
      error_log.update!(message: "Updated message")
    end

    error_log.reload
    assert_equal original_resolved_at, error_log.resolved_at
  end

  test "resolved_at updates to current time when re-resolving an error" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    # First resolution
    travel_to Time.zone.local(2025, 12, 4, 12, 0, 0) do
      error_log.update!(status: "resolved")
    end
    first_resolved_at = error_log.reload.resolved_at

    # Change status away from resolved
    error_log.update!(status: "open")

    # Re-resolve
    travel_to Time.zone.local(2025, 12, 4, 14, 0, 0) do
      error_log.update!(status: "resolved")
    end

    error_log.reload
    assert_not_equal first_resolved_at, error_log.resolved_at
    assert_equal Time.zone.local(2025, 12, 4, 14, 0, 0), error_log.resolved_at
  end
end
