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
end
