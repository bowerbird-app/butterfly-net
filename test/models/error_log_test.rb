# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::ErrorLogTest < ActiveSupport::TestCase
  setup do
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

  # Tests for user tracking functionality
  test "creates error log with user_id and user_email" do
    user_id = SecureRandom.uuid
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "User error",
      user_id: user_id,
      user_email: "test@example.com"
    )

    assert error_log.persisted?
    assert_equal user_id, error_log.user_id
    assert_equal "test@example.com", error_log.user_email
  end

  test "for_user scope filters by user_id" do
    user_id = SecureRandom.uuid
    other_user_id = SecureRandom.uuid

    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError", user_id: user_id)
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError", user_id: other_user_id)
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError", user_id: user_id)

    user_errors = MarcoButterflyNet::ErrorLog.for_user(user_id)

    assert_equal 2, user_errors.count
    assert user_errors.all? { |e| e.user_id == user_id }
  end

  test "for_user_email scope filters by user_email" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError", user_email: "user1@example.com")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError", user_email: "user2@example.com")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError", user_email: "user1@example.com")

    user_errors = MarcoButterflyNet::ErrorLog.for_user_email("user1@example.com")

    assert_equal 2, user_errors.count
    assert user_errors.all? { |e| e.user_email == "user1@example.com" }
  end

  # Tests for occurrence tracking
  test "new error log has occurrence_count of 1 by default" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_equal 1, error_log.occurrence_count
  end

  test "increment_occurrence! increments occurrence_count" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_equal 1, error_log.occurrence_count

    error_log.increment_occurrence!

    assert_equal 2, error_log.occurrence_count
  end

  test "repeated? returns false for single occurrence" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")

    assert_not error_log.repeated?
  end

  test "repeated? returns true for multiple occurrences" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "RuntimeError")
    error_log.increment_occurrence!

    assert error_log.repeated?
  end

  test "repeated scope filters errors with occurrence_count > 1" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "SingleError")
    repeated = MarcoButterflyNet::ErrorLog.create!(exception_class: "RepeatedError")
    repeated.increment_occurrence!

    repeated_errors = MarcoButterflyNet::ErrorLog.repeated

    assert_equal 1, repeated_errors.count
    assert_equal "RepeatedError", repeated_errors.first.exception_class
  end

  test "find_or_create_for_user creates new error for new exception with user" do
    user_id = SecureRandom.uuid
    error = MarcoButterflyNet::ErrorLog.find_or_create_for_user(
      exception_class: "NewError",
      message: "This is new",
      user_id: user_id
    )

    assert error.persisted?
    assert_equal 1, error.occurrence_count
    assert_equal user_id, error.user_id
  end

  test "find_or_create_for_user always creates new error when no user identifiers provided" do
    error1 = MarcoButterflyNet::ErrorLog.find_or_create_for_user(
      exception_class: "NoUserError",
      message: "No user"
    )

    error2 = MarcoButterflyNet::ErrorLog.find_or_create_for_user(
      exception_class: "NoUserError",
      message: "No user"
    )

    assert_not_equal error1.id, error2.id
    assert_equal 1, error1.occurrence_count
    assert_equal 1, error2.occurrence_count
    assert_equal 2, MarcoButterflyNet::ErrorLog.count
  end

  test "find_or_create_for_user increments occurrence for existing error with same user" do
    user_id = SecureRandom.uuid
    MarcoButterflyNet::ErrorLog.create!(
      exception_class: "ExistingError",
      message: "Already exists",
      user_id: user_id
    )

    error = MarcoButterflyNet::ErrorLog.find_or_create_for_user(
      exception_class: "ExistingError",
      message: "Already exists",
      user_id: user_id
    )

    assert_equal 2, error.occurrence_count
    assert_equal 1, MarcoButterflyNet::ErrorLog.count
  end

  test "find_or_create_for_user creates separate entries for different users" do
    user1_id = SecureRandom.uuid
    user2_id = SecureRandom.uuid

    error1 = MarcoButterflyNet::ErrorLog.find_or_create_for_user(
      exception_class: "SameError",
      message: "Same message",
      user_id: user1_id
    )

    error2 = MarcoButterflyNet::ErrorLog.find_or_create_for_user(
      exception_class: "SameError",
      message: "Same message",
      user_id: user2_id
    )

    assert_not_equal error1.id, error2.id
    assert_equal 2, MarcoButterflyNet::ErrorLog.count
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
end
