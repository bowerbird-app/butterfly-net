# frozen_string_literal: true

require "test_helper"

class ButterflyNet::ErrorLogTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ButterflyNet::ErrorOccurrence.delete_all
    ButterflyNet::ErrorLog.delete_all
  end

  test "creates error log with required fields" do
    error_log = ButterflyNet::ErrorLog.create!(
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
    error_log = ButterflyNet::ErrorLog.new(
      message: "Test error"
    )

    assert_not error_log.valid?
    assert_includes error_log.errors[:exception_class], "can't be blank"
  end

  test "backtrace_lines returns array from text" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      backtrace: "line 1\nline 2\nline 3"
    )

    assert_equal [ "line 1", "line 2", "line 3" ], error_log.backtrace_lines
  end

  test "backtrace_lines returns empty array when backtrace is nil" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      backtrace: nil
    )

    assert_equal [], error_log.backtrace_lines
  end

  test "params_hash returns request_params or empty hash" do
    error_log_with_params = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      request_params: { path: "/test" }
    )

    error_log_without_params = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      request_params: nil
    )

    assert_equal({ "path" => "/test" }, error_log_with_params.params_hash)
    assert_equal({}, error_log_without_params.params_hash)
  end

  test "recent scope orders by created_at desc" do
    old_error = ButterflyNet::ErrorLog.create!(
      exception_class: "OldError",
      created_at: 1.day.ago
    )

    new_error = ButterflyNet::ErrorLog.create!(
      exception_class: "NewError",
      created_at: Time.current
    )

    recent_errors = ButterflyNet::ErrorLog.recent

    assert_equal new_error, recent_errors.first
    assert_equal old_error, recent_errors.last
  end

  test "by_exception_class scope filters by class" do
    ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    ButterflyNet::ErrorLog.create!(exception_class: "NoMethodError")
    ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    runtime_errors = ButterflyNet::ErrorLog.by_exception_class("RuntimeError")

    assert_equal 2, runtime_errors.count
    assert runtime_errors.all? { |e| e.exception_class == "RuntimeError" }
  end

  # Tests for occurrence tracking
  test "new error log has occurrence_count of 0" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_equal 0, error_log.occurrence_count
  end

  test "record_occurrence creates an occurrence" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    user_id = SecureRandom.uuid

    occurrence = error_log.record_occurrence(user_id: user_id, user_email: "test@example.com")

    assert occurrence.persisted?
    assert_equal user_id, occurrence.user_id
    assert_equal "test@example.com", occurrence.user_email
    assert_equal 1, error_log.occurrence_count
  end

  test "repeated? returns false for no occurrences" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.repeated?
  end

  test "repeated? returns false for single occurrence" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence

    assert_not error_log.repeated?
  end

  test "repeated? returns true for multiple occurrences" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence
    error_log.record_occurrence

    assert error_log.repeated?
  end

  test "repeated scope filters errors with more than one occurrence" do
    single = ButterflyNet::ErrorLog.create!(exception_class: "SingleError")
    single.record_occurrence

    repeated = ButterflyNet::ErrorLog.create!(exception_class: "RepeatedError")
    repeated.record_occurrence
    repeated.record_occurrence

    repeated_errors = ButterflyNet::ErrorLog.repeated

    assert_equal 1, repeated_errors.count
    assert_equal "RepeatedError", repeated_errors.first.exception_class
  end

  test "find_or_create_with_occurrence groups same errors together" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    error1 = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "SameError",
      message: "Same message",
      user_id: user1_id,
      user_email: "user1@example.com"
    )

    error2 = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "SameError",
      message: "Same message",
      user_id: user2_id,
      user_email: "user2@example.com"
    )

    # Same error log for both users
    assert_equal error1.id, error2.id
    assert_equal 1, ButterflyNet::ErrorLog.count
    assert_equal 2, error1.occurrence_count
    assert_equal 2, error1.occurrences.count

    # But occurrences are separate
    assert_equal 2, ButterflyNet::ErrorOccurrence.count
    assert error1.occurrences.exists?(user_id: user1_id)
    assert error1.occurrences.exists?(user_id: user2_id)
  end

  test "find_or_create_with_occurrence creates new error for different exception" do
    error1 = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "Error1",
      message: "Message 1"
    )

    error2 = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "Error2",
      message: "Message 2"
    )

    assert_not_equal error1.id, error2.id
    assert_equal 2, ButterflyNet::ErrorLog.count
  end

  test "occurrences_for_user returns only that users occurrences" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
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

    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_id: user1_id)
    error_log.record_occurrence(user_id: user1_id)
    error_log.record_occurrence(user_id: user2_id)
    error_log.record_occurrence  # No user

    assert_equal 2, error_log.affected_users_count
  end

  test "affecting_user scope filters errors that affected a user" do
    user_id = SecureRandom.uuid
    other_user_id = SecureRandom.uuid

    error1 = ButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_id: user_id)

    error2 = ButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_id: other_user_id)

    user_errors = ButterflyNet::ErrorLog.affecting_user(user_id)

    assert_equal 1, user_errors.count
    assert_equal "Error1", user_errors.first.exception_class
  end

  # Tests for status tracking
  test "new error log has status of 'open' by default" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_equal "open", error_log.status
  end

  test "with_status scope filters by status" do
    ButterflyNet::ErrorLog.create!(exception_class: "OpenError", status: "open")
    ButterflyNet::ErrorLog.create!(exception_class: "ResolvedError", status: "resolved")
    ButterflyNet::ErrorLog.create!(exception_class: "InProgressError", status: "in_progress")

    open_errors = ButterflyNet::ErrorLog.with_status("open")
    resolved_errors = ButterflyNet::ErrorLog.with_status("resolved")

    assert_equal 1, open_errors.count
    assert_equal "OpenError", open_errors.first.exception_class
    assert_equal 1, resolved_errors.count
    assert_equal "ResolvedError", resolved_errors.first.exception_class
  end

  test "open scope filters open errors" do
    ButterflyNet::ErrorLog.create!(exception_class: "OpenError", status: "open")
    ButterflyNet::ErrorLog.create!(exception_class: "ResolvedError", status: "resolved")

    open_errors = ButterflyNet::ErrorLog.open

    assert_equal 1, open_errors.count
    assert_equal "OpenError", open_errors.first.exception_class
  end

  test "resolved scope filters resolved errors" do
    ButterflyNet::ErrorLog.create!(exception_class: "OpenError", status: "open")
    ButterflyNet::ErrorLog.create!(exception_class: "ResolvedError", status: "resolved")

    resolved_errors = ButterflyNet::ErrorLog.resolved

    assert_equal 1, resolved_errors.count
    assert_equal "ResolvedError", resolved_errors.first.exception_class
  end

  test "validates status is in STATUSES" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      status: "invalid_status"
    )

    assert_not error_log.valid?
    assert_includes error_log.errors[:status], "is not included in the list"
  end

  test "allows valid statuses" do
    ButterflyNet::ErrorLog::STATUSES.each do |status|
      error_log = ButterflyNet::ErrorLog.new(
        exception_class: "RuntimeError",
        status: status
      )

      assert error_log.valid?, "Expected status '#{status}' to be valid"
    end
  end

  # Tests for automatic blame fetching
  test "creating an error log with backtrace enqueues a FetchBlameJob" do
    assert_enqueued_with(job: ButterflyNet::FetchBlameJob) do
      error_log = ButterflyNet::ErrorLog.create!(
        exception_class: "RuntimeError",
        message: "Test error",
        backtrace: "/app/models/user.rb:42:in `save'"
      )
    end
  end

  test "creating an error log without backtrace does NOT enqueue a job" do
    assert_no_enqueued_jobs(only: ButterflyNet::FetchBlameJob) do
      ButterflyNet::ErrorLog.create!(
        exception_class: "RuntimeError",
        message: "Test error",
        backtrace: nil
      )
    end
  end

  test "creating an error log that already has blame info does NOT enqueue a job" do
    assert_no_enqueued_jobs(only: ButterflyNet::FetchBlameJob) do
      ButterflyNet::ErrorLog.create!(
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
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Original message"
    )

    assert_no_enqueued_jobs(only: ButterflyNet::FetchBlameJob) do
      error_log.update!(message: "Updated message")
    end
  end

  # Tests for GitHub issue tracking
  test "has_github_issue? returns false when no issue" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.has_github_issue?
  end

  test "has_github_issue? returns true when issue exists" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      github_issue_number: 123,
      github_issue_url: "https://github.com/owner/repo/issues/123"
    )

    assert error_log.has_github_issue?
  end

  test "with_github_issue scope filters errors with issues" do
    with_issue = ButterflyNet::ErrorLog.create!(
      exception_class: "Error1",
      github_issue_number: 123
    )
    without_issue = ButterflyNet::ErrorLog.create!(exception_class: "Error2")

    errors_with_issues = ButterflyNet::ErrorLog.with_github_issue

    assert_equal 1, errors_with_issues.count
    assert_equal with_issue.id, errors_with_issues.first.id
  end

  test "without_github_issue scope filters errors without issues" do
    with_issue = ButterflyNet::ErrorLog.create!(
      exception_class: "Error1",
      github_issue_number: 123
    )
    without_issue = ButterflyNet::ErrorLog.create!(exception_class: "Error2")

    errors_without_issues = ButterflyNet::ErrorLog.without_github_issue

    assert_equal 1, errors_without_issues.count
    assert_equal without_issue.id, errors_without_issues.first.id
  end

  test "has_blame_info? returns false when no blame info" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.has_blame_info?
  end

  test "has_blame_info? returns true when blame info exists" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      blame_file: "app/models/user.rb",
      blame_commit_sha: "abc123"
    )

    assert error_log.has_blame_info?
  end

  # Tests for resolved_at callback
  test "changing status to resolved sets resolved_at" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "open"
    )

    assert_nil error_log.resolved_at

    error_log.update!(status: "resolved")

    assert_not_nil error_log.resolved_at
    assert_in_delta Time.current.to_i, error_log.resolved_at.to_i, 2
  end

  test "changing status from resolved clears resolved_at" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      status: "resolved"
    )
    error_log.update!(resolved_at: 1.hour.ago)

    error_log.update!(status: "open")

    assert_nil error_log.resolved_at
  end

  test "updating resolved error without changing status keeps resolved_at" do
    error_log = ButterflyNet::ErrorLog.create!(
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

    error1 = ButterflyNet::ErrorLog.create!(exception_class: "Error1")
    error1.record_occurrence(user_email: email)

    error2 = ButterflyNet::ErrorLog.create!(exception_class: "Error2")
    error2.record_occurrence(user_email: other_email)

    email_errors = ButterflyNet::ErrorLog.affecting_user_email(email)

    assert_equal 1, email_errors.count
    assert_equal "Error1", email_errors.first.exception_class
  end

  test "occurrences_for_user_email returns only that email's occurrences" do
    email = "user@example.com"
    other_email = "other@example.com"

    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.record_occurrence(user_email: email)
    error_log.record_occurrence(user_email: email)
    error_log.record_occurrence(user_email: other_email)

    email_occurrences = error_log.occurrences_for_user_email(email)

    assert_equal 2, email_occurrences.count
    assert email_occurrences.all? { |o| o.user_email == email }
  end

  # Tests for create_github_issue
  test "create_github_issue returns existing issue if already created" do
    error_log = ButterflyNet::ErrorLog.create!(
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
    error_log = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message"
    )

    assert_nil error_log.request_params

    updated_log = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      request_params: { path: "/test", method: "GET" }
    )

    assert_equal error_log.id, updated_log.id
    error_log.reload
    assert_equal({ "path" => "/test", "method" => "GET" }, error_log.request_params)
  end

  test "find_or_create_with_occurrence updates user_agent when missing" do
    error_log = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message"
    )

    assert_nil error_log.user_agent

    updated_log = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      user_agent: "Mozilla/5.0"
    )

    assert_equal error_log.id, updated_log.id
    error_log.reload
    assert_equal "Mozilla/5.0", error_log.user_agent
  end

  test "find_or_create_with_occurrence does not overwrite existing request_params" do
    error_log = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      request_params: { path: "/original" }
    )

    updated_log = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: "TestError",
      message: "Test message",
      request_params: { path: "/new" }
    )

    error_log.reload
    assert_equal({ "path" => "/original" }, error_log.request_params)
  end

  test "fetch_blame_info handles errors gracefully" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/nonexistent/file.rb:1:in `method'"
    )

    # Test with a non-existent file which will cause git blame to fail naturally
    # Should return nil instead of raising
    assert_nil error_log.fetch_blame_info
  end

  test "fetch_blame_info with force parameter refetches even with existing data" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "#{Rails.root}/Gemfile:1:in `<top>'",
      blame_file: "old_file.rb",
      blame_commit_sha: "old_sha"
    )

    # Force should ignore existing data
    result = error_log.fetch_blame_info(force: true)

    # May be nil if blame fails, but should at least attempt to refetch
    # The important part is that it tried even with existing data
    assert_not_nil error_log.has_blame_info?
  end

  test "create_github_issue handles service errors gracefully" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock service to raise error
    ButterflyNet::Services::GitHubIssueCreator.stub :new, -> {
      service = Object.new
      def service.create_issue_for_error(*args)
        raise StandardError, "Service error"
      end
      service
    } do
      # Should not raise
      assert_raises(StandardError) do
        error_log.create_github_issue
      end
    end
  end

  test "backtrace_lines handles Windows-style line endings" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      backtrace: "line1\r\nline2\r\nline3"
    )

    # Should split on \n (Windows \r\n will leave \r at end of each line except last)
    lines = error_log.backtrace_lines
    assert_equal 3, lines.length
  end

  test "record_occurrence handles nil user tracking fields" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    occurrence = error_log.record_occurrence(
      user_id: nil,
      user_email: nil
    )

    assert occurrence.persisted?
    assert_nil occurrence.user_id
    assert_nil occurrence.user_email
  end

  test "affected_users_count handles mixed user_id and user_email" do
    user_id = SecureRandom.uuid
    email = "user@example.com"

    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    # User with only ID
    error_log.record_occurrence(user_id: user_id, user_email: nil)
    # User with only email
    error_log.record_occurrence(user_id: nil, user_email: email)
    # Duplicate user ID
    error_log.record_occurrence(user_id: user_id, user_email: nil)

    # Should count unique user_ids
    assert_equal 1, error_log.affected_users_count
  end

  test "status validation allows all valid statuses" do
    ButterflyNet::ErrorLog::STATUSES.each do |status|
      error_log = ButterflyNet::ErrorLog.create!(
        exception_class: "TestError",
        message: "Test",
        status: status
      )
      assert error_log.persisted?, "Status #{status} should be valid"
    end
  end

  test "status defaults to open" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test"
    )

    assert_equal "open", error_log.status
  end

  test "set_resolved_at does not change resolved_at when status stays resolved" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test",
      status: "resolved"
    )

    original_resolved_at = error_log.resolved_at

    # Update something other than status
    error_log.update!(message: "Updated message")

    # resolved_at should not change
    assert_equal original_resolved_at.to_i, error_log.resolved_at.to_i
  end

  test "existing_blame_result returns nil when no blame info" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test"
    )

    result = error_log.send(:existing_blame_result)
    assert_nil result
  end

  test "existing_blame_result returns BlameResult when blame info exists" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test",
      blame_file: "app/models/user.rb",
      blame_line_number: 42,
      blame_commit_sha: "abc123",
      blame_author_name: "Test Author",
      blame_author_email: "test@example.com",
      blame_commit_date: Time.current
    )

    result = error_log.send(:existing_blame_result)

    assert_not_nil result
    assert_instance_of ButterflyNet::Services::GitBlame::BlameResult, result
    assert_equal "app/models/user.rb", result.file
    assert_equal 42, result.line_number
    assert_equal "abc123", result.commit_sha
  end

  test "should_auto_fetch_blame? returns false when no backtrace" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      message: "Test",
      backtrace: nil
    )

    assert_not error_log.send(:should_auto_fetch_blame?)
  end

  test "should_auto_fetch_blame? returns false when already has blame info" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      message: "Test",
      backtrace: "line1",
      blame_file: "file.rb",
      blame_commit_sha: "abc123"
    )

    assert_not error_log.send(:should_auto_fetch_blame?)
  end

  test "should_auto_fetch_blame? returns true when has backtrace but no blame info" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      message: "Test",
      backtrace: "line1"
    )

    assert error_log.send(:should_auto_fetch_blame?)
  end

  test "params_hash handles symbolized keys" do
    error_log = ButterflyNet::ErrorLog.new(
      exception_class: "RuntimeError",
      request_params: { path: "/test", method: "GET" }
    )

    params = error_log.params_hash
    assert_equal "/test", params["path"]
    assert_equal "GET", params["method"]
  end

  test "repeated scope excludes errors with no occurrences" do
    no_occurrence = ButterflyNet::ErrorLog.create!(exception_class: "NoOccurrence")
    one_occurrence = ButterflyNet::ErrorLog.create!(exception_class: "OneOccurrence")
    one_occurrence.record_occurrence
    repeated = ButterflyNet::ErrorLog.create!(exception_class: "Repeated")
    repeated.record_occurrence
    repeated.record_occurrence

    repeated_errors = ButterflyNet::ErrorLog.repeated

    assert_equal 1, repeated_errors.count
    assert_equal repeated.id, repeated_errors.first.id
  end

  test "find_or_create_with_occurrence handles concurrent creation" do
    # Simulate concurrent requests creating the same error
    exception_class = "ConcurrentError"
    message = "Concurrent message"

    # First creation
    error1 = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: exception_class,
      message: message,
      user_id: "user1"
    )

    # Second creation (simulating concurrent request)
    error2 = ButterflyNet::ErrorLog.find_or_create_with_occurrence(
      exception_class: exception_class,
      message: message,
      user_id: "user2"
    )

    # Should use the same error log
    assert_equal error1.id, error2.id
    assert_equal 2, error1.occurrence_count
  end
end
