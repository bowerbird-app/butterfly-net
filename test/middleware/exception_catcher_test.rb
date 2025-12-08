# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::Middleware::ExceptionCatcherTest < ActiveSupport::TestCase
  setup do
    MarcoButterflyNet.clear_captured_exceptions
  end

  teardown do
    MarcoButterflyNet.clear_captured_exceptions
  end

  test "middleware passes through successful requests" do
    app = ->(_env) { [ 200, {}, [ "OK" ] ] }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    status, _headers, body = middleware.call({})

    assert_equal 200, status
    assert_equal [ "OK" ], body
    assert_empty MarcoButterflyNet.captured_exceptions
  end

  test "middleware captures exception and re-raises it" do
    error = StandardError.new("Test error")
    app = ->(_env) { raise error }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(StandardError) do
      middleware.call({})
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal error, captured[:exception]
    assert_respond_to captured[:captured_at], :to_time
  end

  test "middleware captures exception with env context" do
    error = RuntimeError.new("Runtime error")
    app = ->(_env) { raise error }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }

    assert_raises(RuntimeError) do
      middleware.call(env)
    end

    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal env, captured[:env]
  end

  test "middleware captures multiple exceptions" do
    app = ->(_env) { raise StandardError.new("Error") }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    3.times do
      assert_raises(StandardError) do
        middleware.call({})
      end
    end

    assert_equal 3, MarcoButterflyNet.captured_exceptions.length
  end

  test "middleware captures NameError" do
    app = ->(_env) { raise NameError, "uninitialized constant MediaKitsController::MediaKi" }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(NameError) do
      middleware.call({})
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal NameError, captured[:exception].class
    assert_includes captured[:exception].message, "uninitialized constant"
  end

  test "middleware captures NoMethodError" do
    app = ->(_env) { raise NoMethodError, "undefined method `foo' for nil:NilClass" }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(NoMethodError) do
      middleware.call({})
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal NoMethodError, captured[:exception].class
  end

  test "middleware captures ArgumentError" do
    app = ->(_env) { raise ArgumentError, "wrong number of arguments (given 1, expected 0)" }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(ArgumentError) do
      middleware.call({})
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal ArgumentError, captured[:exception].class
  end

  test "middleware captures TypeError" do
    app = ->(_env) { raise TypeError, "no implicit conversion of Integer into String" }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(TypeError) do
      middleware.call({})
    end

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal TypeError, captured[:exception].class
  end

  test "handle_intercepted_exception captures exceptions via class method" do
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }
    error = NameError.new("uninitialized constant SomeController::SomeConstant")

    MarcoButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(error, env)

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal error, captured[:exception]
    assert_equal env, captured[:env]
  end

  test "middleware does not duplicate capture when already handled by interceptor" do
    error = StandardError.new("Test error")
    app = ->(_env) { raise error }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)
    env = { "marco_butterfly_net.exception_handled" => true }

    assert_raises(StandardError) do
      middleware.call(env)
    end

    # Should not capture since it was already handled
    assert_equal 0, MarcoButterflyNet.captured_exceptions.length
  end

  test "filters sensitive parameters from request params" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    params = {
      "username" => "john",
      "password" => "secret123",
      "password_confirmation" => "secret123",
      "api_key" => "abc123",
      "data" => { "token" => "xyz789", "name" => "test" }
    }

    filtered = middleware.send(:filter_params, params)

    assert_equal "john", filtered["username"]
    assert_equal "[FILTERED]", filtered["password"]
    assert_equal "[FILTERED]", filtered["password_confirmation"]
    assert_equal "[FILTERED]", filtered["api_key"]
    assert_equal "[FILTERED]", filtered["data"]["token"]
    assert_equal "test", filtered["data"]["name"]
  end

  test "filters sensitive parameters from query string" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    query_string = "username=john&password=secret123&token=abc"

    filtered = middleware.send(:filter_query_string, query_string)

    assert_includes filtered, "username=john"
    assert_includes filtered, "password=[FILTERED]"
    assert_includes filtered, "token=[FILTERED]"
  end

  test "handles blank query string" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    assert_equal "", middleware.send(:filter_query_string, "")
    assert_nil middleware.send(:filter_query_string, nil)
  end

  test "handles deep nested params with recursion limit" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create deeply nested hash
    params = { "level1" => { "password" => "secret" } }

    filtered = middleware.send(:filter_params, params)
    assert_equal "[FILTERED]", filtered["level1"]["password"]
  end

  test "handles non-hash params" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    assert_equal "string", middleware.send(:filter_params, "string")
    assert_equal [ 1, 2, 3 ], middleware.send(:filter_params, [ 1, 2, 3 ])
  end

  test "safe_params rescues errors" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    request = Object.new
    def request.params
      raise StandardError, "params error"
    end

    result = middleware.send(:safe_params, request)
    assert_equal({}, result)
  end

  test "persist_exception creates error log" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    exception = StandardError.new("Test error")
    exception.set_backtrace([ "line1", "line2" ])

    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/api/test",
      "QUERY_STRING" => "key=value",
      "HTTP_USER_AGENT" => "TestAgent/1.0",
      "error_tracking.user_id" => "user123",
      "error_tracking.user_email" => "user@example.com",
      "rack.input" => StringIO.new
    }

    middleware.send(:persist_exception, exception, env)

    error_log = MarcoButterflyNet::ErrorLog.last
    assert_not_nil error_log
    assert_equal "StandardError", error_log.exception_class
    assert_equal "Test error", error_log.message
    assert_includes error_log.backtrace, "line1"
  end

  test "persist_exception handles database errors gracefully" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    exception = StandardError.new("Test error")
    env = {}

    # Mock the ErrorLog class method to raise error
    original_method = MarcoButterflyNet::ErrorLog.method(:find_or_create_with_occurrence)
    MarcoButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence) do |*args|
      raise StandardError, "DB error"
    end

    begin
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    ensure
      # Restore original method
      MarcoButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence, original_method)
    end
  end

  test "extract_request_params extracts all relevant data" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/api/users",
      "QUERY_STRING" => "token=abc123&name=john",
      "rack.input" => StringIO.new("username=john&password=secret")
    }

    params = middleware.send(:extract_request_params, env)

    assert_equal "/api/users", params[:path]
    assert_equal "POST", params[:method]
    assert_includes params[:query_string], "token=[FILTERED]"
    assert_includes params[:query_string], "name=john"
  end

  test "sensitive_key? detects sensitive parameters" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    assert middleware.send(:sensitive_key?, "password")
    assert middleware.send(:sensitive_key?, "user_password")
    assert middleware.send(:sensitive_key?, "api_key")
    assert middleware.send(:sensitive_key?, "access_token")
    assert middleware.send(:sensitive_key?, "credit_card")
    assert middleware.send(:sensitive_key?, "ssn")

    assert_not middleware.send(:sensitive_key?, "username")
    assert_not middleware.send(:sensitive_key?, "email")
    assert_not middleware.send(:sensitive_key?, "name")
  end

  test "filters all sensitive parameter types" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    params = {
      "password" => "secret",
      "password_confirmation" => "secret",
      "secret" => "key",
      "token" => "abc",
      "api_key" => "xyz",
      "access_token" => "123",
      "refresh_token" => "456",
      "credit_card" => "1234",
      "card_number" => "5678",
      "cvv" => "999",
      "ssn" => "123-45-6789",
      "social_security" => "987-65-4321"
    }

    filtered = middleware.send(:filter_params, params)

    params.keys.each do |key|
      assert_equal "[FILTERED]", filtered[key], "Expected #{key} to be filtered"
    end
  end
end
