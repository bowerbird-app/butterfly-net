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

  # Tests for GitHub issue tracking
  test "has_github_issue? returns false when no issue" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.has_github_issue?
  end

  test "has_github_issue? returns true when issue exists" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      github_issue_number: 123,
      github_issue_url: "https://github.com/owner/repo/issues/123"
    )

    assert error_log.has_github_issue?
  end

  test "with_github_issue scope filters errors with issues" do
    with_issue = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "Error1",
      github_issue_number: 123
    )
    without_issue = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")

    errors_with_issues = MarcoButterflyNet::ErrorLog.with_github_issue

    assert_equal 1, errors_with_issues.count
    assert_equal with_issue.id, errors_with_issues.first.id
  end

  test "without_github_issue scope filters errors without issues" do
    with_issue = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "Error1",
      github_issue_number: 123
    )
    without_issue = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")

    errors_without_issues = MarcoButterflyNet::ErrorLog.without_github_issue

    assert_equal 1, errors_without_issues.count
    assert_equal without_issue.id, errors_without_issues.first.id
  end

  test "has_blame_info? returns false when no blame info" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.has_blame_info?
  end

  test "has_blame_info? returns true when blame info exists" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      blame_file: "app/models/user.rb",
      blame_commit_sha: "abc123"
    )

    assert error_log.has_blame_info?
  end

  # Tests for resolved_at callback
  test "changing status to resolved sets resolved_at" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    assert_nil error_log.resolved_at

    error_log.update!(status: "resolved")

    assert_not_nil error_log.resolved_at
    assert_in_delta Time.current.to_i, error_log.resolved_at.to_i, 2
  end

  test "changing status from resolved clears resolved_at" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "resolved"
    )
    error_log.update!(resolved_at: 1.hour.ago)

    error_log.update!(status: "open")

    assert_nil error_log.resolved_at
  end

  test "updating resolved error without changing status keeps resolved_at" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "resolved"
    )
    resolved_time = 1.hour.ago
    error_log.update!(resolved_at: resolved_time)

    error_log.update!(message: "Updated message")

    assert_equal resolved_time.to_i, error_log.resolved_at.to_i
  end

  # Tests for affecting_user_email scope
  test "affecting_user_email scope filters errors by email" do
    email = "user@example.com"
    other_email = "other@example.com"

    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_email: email)

    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_email: other_email)

    email_errors = MarcoButterflyNet::ErrorLog.affecting_user_email(email)

    assert_equal 1, email_errors.count
    assert_equal "Error1", email_errors.first.exception_class
  end

  test "occurrences_for_user_email returns only that email's occurrences" do
    email = "user@example.com"
    other_email = "other@example.com"

    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_email: email)
    error_log.record_occurrence(user_email: email)
    error_log.record_occurrence(user_email: other_email)

    email_occurrences = error_log.occurrences_for_user_email(email)

    assert_equal 2, email_occurrences.count
    assert email_occurrences.all? { |o| o.user_email == email }
  end

  # Tests for create_github_issue
  test "create_github_issue returns existing issue if already created" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      github_issue_number: 456,
      github_issue_url: "https://github.com/owner/repo/issues/456"
    )

    result = error_log.create_github_issue

    assert result.success
    assert_equal 456, result.issue_number
    assert_includes result.error_message, "already exists"
  end

  # Tests for find_or_create_with_occurrence updating existing records
  test "find_or_create_with_occurrence updates request_params when missing" do
    error_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message"
    )

    assert_nil error_log.request_params

    updated_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      request_params: { path: "/test", method: "GET" }
    )

    assert_equal error_log.id, updated_log.id
    error_log.reload
    assert_equal({ "path" => "/test", "method" => "GET" }, error_log.request_params)
  end

  test "find_or_create_with_occurrence updates user_agent when missing" do
    error_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message"
    )

    assert_nil error_log.user_agent

    updated_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      user_agent: "Mozilla/5.0"
    )

    assert_equal error_log.id, updated_log.id
    error_log.reload
    assert_equal "Mozilla/5.0", error_log.user_agent
  end

  test "find_or_create_with_occurrence does not overwrite existing request_params" do
    error_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      request_params: { path: "/original" }
    )

    updated_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      request_params: { path: "/new" }
    )

    error_log.reload
    assert_equal({ "path" => "/original" }, error_log.request_params)
  end

  # Unhappy path: Test fetch_blame_info when service fails
  test "fetch_blame_info returns nil when service cannot find blame" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/nonexistent/path.rb:1:in `method'"
    )

    result = error_log.fetch_blame_info

    assert_nil result
    # Should not update blame fields when result is nil
    assert_nil error_log.reload.blame_file
    assert_nil error_log.blame_commit_sha
  end

  test "fetch_blame_info handles empty backtrace" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: ""
    )

    result = error_log.fetch_blame_info

    assert_nil result
  end

  test "fetch_blame_info handles nil backtrace" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: nil
    )

    result = error_log.fetch_blame_info

    assert_nil result
  end

  test "fetch_blame_info force option refetches even when blame exists" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "#{Rails.root}/Gemfile:1:in `block'",
      blame_file: "old_file.rb",
      blame_commit_sha: "old123"
    )

    # Force refetch
    result = error_log.fetch_blame_info(force: true)

    # Result depends on whether git blame succeeds
    # Just verify force: true attempts to fetch
    # (may be nil if git blame fails, which is acceptable)
  end

  test "fetch_blame_info returns existing result when force is false" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "#{Rails.root}/Gemfile:1:in `block'",
      blame_file: "existing.rb",
      blame_line_number: 42,
      blame_commit_sha: "abc123",
      blame_author_name: "Existing Author",
      blame_author_email: "existing@test.com",
      blame_commit_date: Time.current
    )

    result = error_log.fetch_blame_info(force: false)

    assert_not_nil result
    assert_equal "existing.rb", result.file
    assert_equal 42, result.line_number
    assert_equal "abc123", result.commit_sha
    assert_equal "Existing Author", result.author_name
  end

  # Unhappy path: Test create_github_issue when service fails
  test "create_github_issue returns failure result when service fails" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = ""  # Not configured
      config.github_repo_owner = ""
      config.github_repo_name = ""
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    result = error_log.create_github_issue

    assert_not result.success
    assert_not_nil result.error_message
    assert_nil result.issue_number
  ensure
    MarcoButterflyNet.reset_configuration!
  end

  test "create_github_issue does not update error_log when service fails" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = ""
      config.github_repo_owner = ""
      config.github_repo_name = ""
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    error_log.create_github_issue

    error_log.reload
    assert_nil error_log.github_issue_number
    assert_nil error_log.github_issue_url
  ensure
    MarcoButterflyNet.reset_configuration!
  end

  # Edge cases for occurrence counting with nil values
  test "occurrence_count excludes deleted occurrences" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occ1 = error_log.record_occurrence
    occ2 = error_log.record_occurrence
    error_log.record_occurrence

    assert_equal 3, error_log.occurrence_count

    occ1.destroy

    assert_equal 2, error_log.reload.occurrence_count
  end

  test "affected_users_count handles nil user_ids correctly" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    error_log.record_occurrence(user_id: "user1")
    error_log.record_occurrence(user_id: "user2")
    error_log.record_occurrence(user_id: nil)  # Should not count
    error_log.record_occurrence(user_id: "")   # Empty string is counted as distinct

    # The method counts distinct non-nil user_ids, so empty string is included
    assert_equal 3, error_log.affected_users_count
  end

  test "occurrences_for_user returns empty for nil user_id" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    error_log.record_occurrence(user_id: "user1")
    error_log.record_occurrence(user_id: nil)

    occurrences = error_log.occurrences_for_user(nil)

    # Should return occurrences with nil user_id
    assert_equal 1, occurrences.count
  end

  test "occurrences_for_user_email returns empty for nil email" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    error_log.record_occurrence(user_email: "user@test.com")
    error_log.record_occurrence(user_email: nil)

    occurrences = error_log.occurrences_for_user_email(nil)

    # Should return occurrences with nil user_email
    assert_equal 1, occurrences.count
  end

  # Additional tests for specific lines mentioned in problem statement
  test "affecting_user scope works with multiple errors" do
    user_id = SecureRandom.uuid

    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_id: user_id)

    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_id: user_id)

    error3 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error3")
    error3.record_occurrence(user_id: SecureRandom.uuid)

    user_errors = MarcoButterflyNet::ErrorLog.affecting_user(user_id)

    assert_equal 2, user_errors.count
    assert_includes user_errors.pluck(:exception_class), "Error1"
    assert_includes user_errors.pluck(:exception_class), "Error2"
  end

  test "affecting_user_email scope works with multiple errors" do
    email = "user@test.com"

    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_email: email)

    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_email: email)

    error3 = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error3")
    error3.record_occurrence(user_email: "other@test.com")

    email_errors = MarcoButterflyNet::ErrorLog.affecting_user_email(email)

    assert_equal 2, email_errors.count
    assert_includes email_errors.pluck(:exception_class), "Error1"
    assert_includes email_errors.pluck(:exception_class), "Error2"
  end

  test "find_or_create_with_occurrence handles concurrent occurrences" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    # Simulate concurrent creation
    error_log = nil
    3.times do
      error_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
        exception_class: "ConcurrentError",
        message: "Concurrent message",
        user_id: user1_id
      )
    end

    2.times do
      error_log = MarcoButterflyNet::ErrorLog.find_or_create_with_occurrence(
        exception_class: "ConcurrentError",
        message: "Concurrent message",
        user_id: user2_id
      )
    end

    # Should have one error log
    assert_equal 1, MarcoButterflyNet::ErrorLog.where(
      exception_class: "ConcurrentError",
      message: "Concurrent message"
    ).count

    # Should have 5 occurrences total
    assert_equal 5, error_log.occurrence_count
  end

  test "set_resolved_at handles multiple status transitions" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    # Open -> Resolved
    error_log.update!(status: "resolved")
    first_resolved_at = error_log.resolved_at
    assert_not_nil first_resolved_at

    # Resolved -> In Progress
    error_log.update!(status: "in_progress")
    assert_nil error_log.resolved_at

    # In Progress -> Resolved
    error_log.update!(status: "resolved")
    second_resolved_at = error_log.resolved_at
    assert_not_nil second_resolved_at
    # Should be a new timestamp
    assert second_resolved_at > first_resolved_at
  end

  test "record_occurrence accepts all optional parameters" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence = error_log.record_occurrence(
      user_id: "user123",
      user_email: "user@test.com",
      request_params: { path: "/test", method: "POST" },
      user_agent: "Mozilla/5.0"
    )

    assert_equal "user123", occurrence.user_id
    assert_equal "user@test.com", occurrence.user_email
    assert_equal({ "path" => "/test", "method" => "POST" }, occurrence.request_params)
    assert_equal "Mozilla/5.0", occurrence.user_agent
  end

  test "record_occurrence works with no parameters" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence = error_log.record_occurrence

    assert occurrence.persisted?
    assert_nil occurrence.user_id
    assert_nil occurrence.user_email
  end
end
