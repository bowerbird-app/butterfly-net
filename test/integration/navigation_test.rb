# frozen_string_literal: true

require "test_helper"

class ErrorCaptureIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    MarcoButterflyNet.clear_captured_exceptions
    MarcoButterflyNet::ErrorLog.delete_all
  end

  teardown do
    MarcoButterflyNet.clear_captured_exceptions
  end

  test "captures NameError from controller" do
    assert_raises(NameError) do
      get "/test/name_error"
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal NameError, captured[:exception].class
    assert_includes captured[:exception].message, "SomeUndefinedConstant"
  end

  test "captures NoMethodError from controller" do
    assert_raises(NoMethodError) do
      get "/test/no_method_error"
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal NoMethodError, captured[:exception].class
  end

  test "captures ArgumentError from controller" do
    assert_raises(ArgumentError) do
      get "/test/argument_error"
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal ArgumentError, captured[:exception].class
  end

  test "captures TypeError from controller" do
    assert_raises(TypeError) do
      get "/test/type_error"
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal TypeError, captured[:exception].class
  end

  test "captures RuntimeError from controller" do
    assert_raises(RuntimeError) do
      get "/test/runtime_error"
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal RuntimeError, captured[:exception].class
  end

  test "successful request does not capture exceptions" do
    get "/test/success"

    assert_response :success
    assert_equal 0, MarcoButterflyNet.captured_exceptions.length
  end

  test "persists error to database" do
    assert_raises(NameError) do
      get "/test/name_error"
    end

    assert_equal 1, MarcoButterflyNet::ErrorLog.count
    error_log = MarcoButterflyNet::ErrorLog.last
    assert_equal "NameError", error_log.exception_class
    assert_includes error_log.message, "SomeUndefinedConstant"
    assert_not_nil error_log.backtrace
    assert_not_nil error_log.request_params
    assert_equal "/test/name_error", error_log.request_params["path"]
    assert_equal "GET", error_log.request_params["method"]
  end
end
