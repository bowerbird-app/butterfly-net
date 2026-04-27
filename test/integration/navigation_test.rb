# frozen_string_literal: true

require "test_helper"

class ErrorCaptureIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    ButterflyNet.clear_captured_exceptions
    ButterflyNet::ErrorOccurrence.delete_all
    ButterflyNet::ErrorLog.delete_all
  end

  teardown do
    ButterflyNet.clear_captured_exceptions
  end

  test "captures NameError from controller" do
    assert_raises(NameError) do
      get "/test/name_error"
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal NameError, captured[:exception].class
    assert_includes captured[:exception].message, "SomeUndefinedConstant"
  end

  test "captures NoMethodError from controller" do
    assert_raises(NoMethodError) do
      get "/test/no_method_error"
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal NoMethodError, captured[:exception].class
  end

  test "captures ArgumentError from controller" do
    assert_raises(ArgumentError) do
      get "/test/argument_error"
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal ArgumentError, captured[:exception].class
  end

  test "captures TypeError from controller" do
    assert_raises(TypeError) do
      get "/test/type_error"
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal TypeError, captured[:exception].class
  end

  test "captures RuntimeError from controller" do
    assert_raises(RuntimeError) do
      get "/test/runtime_error"
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal RuntimeError, captured[:exception].class
  end

  test "captures JSON parser error with gem frame before controller" do
    assert_raises(JSON::ParserError) do
      get "/test/json_parser_error"
    end

    assert_equal 1, ButterflyNet::ErrorLog.count
    error_log = ButterflyNet::ErrorLog.last

    assert_equal "JSON::ParserError", error_log.exception_class
    assert_not_empty error_log.backtrace_lines
    refute_includes error_log.backtrace_lines.first, "test_errors_controller.rb"
    assert error_log.backtrace_lines.any? { |line| line.include?("test_errors_controller.rb") }
  end

  test "successful request does not capture exceptions" do
    get "/test/success"

    assert_response :success
    assert_equal 0, ButterflyNet.captured_exceptions.length
  end

  test "error simulator page renders trigger links" do
    get "/errors"

    assert_response :success
    assert_match /Error Simulator/, response.body
    assert_match %r{/test/name_error}, response.body
    assert_match %r{/test/no_method_error}, response.body
    assert_match %r{/test/argument_error}, response.body
    assert_match %r{/test/type_error}, response.body
    assert_match %r{/test/runtime_error}, response.body
    assert_match %r{/test/json_parser_error}, response.body
    assert_match %r{/test/success}, response.body
  end

  test "persists error to database" do
    assert_raises(NameError) do
      get "/test/name_error"
    end

    assert_equal 1, ButterflyNet::ErrorLog.count
    error_log = ButterflyNet::ErrorLog.last
    assert_equal "NameError", error_log.exception_class
    assert_includes error_log.message, "SomeUndefinedConstant"
    assert_not_nil error_log.backtrace
    assert_not_nil error_log.request_params
    assert_equal "/test/name_error", error_log.request_params["path"]
    assert_equal "GET", error_log.request_params["method"]
  end

  test "middleware intercepts exceptions early in the stack" do
    # This test verifies that the middleware is actually active in the stack
    # by confirming an exception is caught and stored before being re-raised
    assert_raises(RuntimeError) do
      get "/test/runtime_error"
    end

    # Verify the exception was captured by the middleware
    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first

    # Verify it has the env context from the request
    assert_not_nil captured[:env]
    assert_equal "GET", captured[:env]["REQUEST_METHOD"]
    assert_equal "/test/runtime_error", captured[:env]["PATH_INFO"]

    # Verify it was persisted to the database
    assert_equal 1, ButterflyNet::ErrorLog.count
    error_log = ButterflyNet::ErrorLog.last
    assert_equal "RuntimeError", error_log.exception_class
  end

  test "exceptions caught through ActionDispatch::DebugExceptions interceptor" do
    # The DebugExceptions interceptor should catch exceptions that would
    # otherwise only be rendered as error pages
    # This is important for development mode where some exceptions don't propagate

    # Trigger an exception
    assert_raises(NameError) do
      get "/test/name_error"
    end

    # Verify the exception was captured (either by middleware or interceptor)
    assert ButterflyNet.captured_exceptions.any?,
      "Exception should have been captured by middleware or DebugExceptions interceptor"

    captured = ButterflyNet.captured_exceptions.first
    assert_equal NameError, captured[:exception].class

    # Verify persistence happened
    assert ButterflyNet::ErrorLog.where(exception_class: "NameError").any?,
      "Exception should have been persisted to database"
  end
end
