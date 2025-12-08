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

  # Happy path: Integration test for ErrorLog and ErrorOccurrence creation
  test "middleware creates ErrorLog and ErrorOccurrence on exception" do
    MarcoButterflyNet::ErrorLog.delete_all
    MarcoButterflyNet::ErrorOccurrence.delete_all

    error = StandardError.new("Integration test error")
    app = ->(_env) { raise error }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)
    
    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/api/test",
      "QUERY_STRING" => "param=value",
      "HTTP_USER_AGENT" => "TestAgent/1.0",
      "error_tracking.user_id" => "user123",
      "error_tracking.user_email" => "user@test.com",
      "rack.input" => StringIO.new
    }

    assert_raises(StandardError) do
      middleware.call(env)
    end

    # Verify ErrorLog was created
    error_log = MarcoButterflyNet::ErrorLog.last
    assert_not_nil error_log
    assert_equal "StandardError", error_log.exception_class
    assert_equal "Integration test error", error_log.message

    # Verify ErrorOccurrence was created
    occurrence = error_log.occurrences.last
    assert_not_nil occurrence
    assert_equal "user123", occurrence.user_id
    assert_equal "user@test.com", occurrence.user_email
  end

  # Happy path: Verify exception is re-raised
  test "middleware re-raises exception after capture" do
    custom_error = Class.new(StandardError)
    error = custom_error.new("Should be re-raised")
    app = ->(_env) { raise error }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    exception_raised = false
    begin
      middleware.call({})
    rescue custom_error => e
      exception_raised = true
      assert_equal error, e
      assert_equal "Should be re-raised", e.message
    end

    assert exception_raised, "Expected exception to be re-raised"
  end

  # Happy path: Test handle_intercepted_exception
  test "handle_intercepted_exception creates error log" do
    MarcoButterflyNet::ErrorLog.delete_all

    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/test/path",
      "rack.input" => StringIO.new
    }
    error = RuntimeError.new("Intercepted error")

    MarcoButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(error, env)

    # Verify error was captured
    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    
    # Verify ErrorLog was created
    error_log = MarcoButterflyNet::ErrorLog.last
    assert_not_nil error_log
    assert_equal "RuntimeError", error_log.exception_class
    assert_equal "Intercepted error", error_log.message
  end

  # Unhappy path: Test persistence failure doesn't crash app
  test "persist_exception logs error but doesn't crash when database fails" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    exception = StandardError.new("Test error")
    env = { "rack.input" => StringIO.new }

    # Mock ErrorLog.find_or_create_with_occurrence to raise database error
    original_method = MarcoButterflyNet::ErrorLog.method(:find_or_create_with_occurrence)
    MarcoButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence) do |*args|
      raise ActiveRecord::ConnectionNotEstablished.new("Database is down")
    end

    begin
      # Should not raise, just log the error
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    ensure
      # Restore original method
      MarcoButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence, original_method)
    end
  end

  test "middleware continues to work even if persistence fails" do
    error_count = 0
    app = ->(_env) { 
      error_count += 1
      raise StandardError.new("Error #{error_count}")
    }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)

    # Mock persistence to fail
    original_method = MarcoButterflyNet::ErrorLog.method(:find_or_create_with_occurrence)
    MarcoButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence) do |*args|
      raise ActiveRecord::StatementInvalid.new("SQL error")
    end

    begin
      # First exception should still be raised even if persistence fails
      assert_raises(StandardError) do
        middleware.call({ "rack.input" => StringIO.new })
      end

      # Second exception should also work
      assert_raises(StandardError) do
        middleware.call({ "rack.input" => StringIO.new })
      end

      assert_equal 2, error_count
    ensure
      MarcoButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence, original_method)
    end
  end

  # Unhappy path: Test parameter filtering with deeply nested structures
  test "filter_params handles deeply nested structures" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    params = {
      "user" => {
        "name" => "John",
        "credentials" => {
          "password" => "secret123",
          "api_key" => "xyz789",
          "profile" => {
            "email" => "john@example.com",
            "secret_answer" => "my secret"
          }
        }
      }
    }

    filtered = middleware.send(:filter_params, params)

    assert_equal "John", filtered["user"]["name"]
    assert_equal "[FILTERED]", filtered["user"]["credentials"]["password"]
    assert_equal "[FILTERED]", filtered["user"]["credentials"]["api_key"]
    assert_equal "john@example.com", filtered["user"]["credentials"]["profile"]["email"]
    assert_equal "[FILTERED]", filtered["user"]["credentials"]["profile"]["secret_answer"]
  end

  test "filter_params prevents infinite recursion with depth limit" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create a deeply nested structure (12 levels deep, exceeding limit of 10)
    params = { "level1" => {} }
    current = params["level1"]
    11.times do |i|
      current["level#{i + 2}"] = {}
      current = current["level#{i + 2}"]
    end
    current["password"] = "should_not_be_filtered_due_to_depth"

    filtered = middleware.send(:filter_params, params)

    # Should handle gracefully without infinite recursion
    assert_not_nil filtered
  end

  test "filter_params handles arrays within hashes" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    params = {
      "users" => [
        { "name" => "Alice", "password" => "secret1" },
        { "name" => "Bob", "password" => "secret2" }
      ]
    }

    filtered = middleware.send(:filter_params, params)

    # Arrays should be preserved as-is
    assert_instance_of Array, filtered["users"]
    assert_equal 2, filtered["users"].length
  end

  test "filter_query_string handles query strings with special characters" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    query_string = "username=john%40example.com&password=secret%20123&token=abc%3Dxyz"

    filtered = middleware.send(:filter_query_string, query_string)

    assert_includes filtered, "username=john%40example.com"
    assert_includes filtered, "password=[FILTERED]"
    assert_includes filtered, "token=[FILTERED]"
  end

  test "filter_query_string handles query strings without values" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    query_string = "debug&password&verbose"

    filtered = middleware.send(:filter_query_string, query_string)

    assert_includes filtered, "debug"
    assert_includes filtered, "password=[FILTERED]"
    assert_includes filtered, "verbose"
  end

  test "extract_request_params handles request with no params" do
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(nil)

    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/",
      "QUERY_STRING" => "",
      "rack.input" => StringIO.new
    }

    params = middleware.send(:extract_request_params, env)

    assert_equal "/", params[:path]
    assert_equal "GET", params[:method]
    assert_equal "", params[:query_string]
    assert_equal({}, params[:params])
  end

  test "capture_and_persist marks exception as handled" do
    app = ->(_env) { raise StandardError.new("Test") }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)
    env = { "rack.input" => StringIO.new }

    begin
      middleware.call(env)
    rescue StandardError
      # Exception expected
    end

    assert_equal true, env["marco_butterfly_net.exception_handled"]
  end

  test "middleware respects exception_handled flag" do
    error = StandardError.new("Already handled")
    app = ->(_env) { raise error }
    middleware = MarcoButterflyNet::Middleware::ExceptionCatcher.new(app)
    
    # Mark as already handled
    env = { "marco_butterfly_net.exception_handled" => true }

    MarcoButterflyNet.clear_captured_exceptions

    assert_raises(StandardError) do
      middleware.call(env)
    end

    # Should not capture since already handled
    assert_equal 0, MarcoButterflyNet.captured_exceptions.length
  end
end
