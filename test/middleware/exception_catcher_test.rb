# frozen_string_literal: true

require "test_helper"

class ButterflyNet::Middleware::ExceptionCatcherTest < ActiveSupport::TestCase
  setup do
    ButterflyNet.clear_captured_exceptions
  end

  teardown do
    ButterflyNet.clear_captured_exceptions
  end

  test "middleware passes through successful requests" do
    app = ->(_env) { [ 200, {}, [ "OK" ] ] }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    status, _headers, body = middleware.call({})

    assert_equal 200, status
    assert_equal [ "OK" ], body
    assert_empty ButterflyNet.captured_exceptions
  end

  test "middleware captures exception and re-raises it" do
    error = StandardError.new("Test error")
    app = ->(_env) { raise error }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(StandardError) do
      middleware.call({})
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal error, captured[:exception]
    assert_respond_to captured[:captured_at], :to_time
  end

  test "middleware captures exception with env context" do
    error = RuntimeError.new("Runtime error")
    app = ->(_env) { raise error }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }

    assert_raises(RuntimeError) do
      middleware.call(env)
    end

    captured = ButterflyNet.captured_exceptions.first
    assert_equal env, captured[:env]
  end

  test "middleware captures multiple exceptions" do
    app = ->(_env) { raise StandardError.new("Error") }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    3.times do
      assert_raises(StandardError) do
        middleware.call({})
      end
    end

    assert_equal 3, ButterflyNet.captured_exceptions.length
  end

  test "middleware captures NameError" do
    app = ->(_env) { raise NameError, "uninitialized constant MediaKitsController::MediaKi" }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(NameError) do
      middleware.call({})
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal NameError, captured[:exception].class
    assert_includes captured[:exception].message, "uninitialized constant"
  end

  test "middleware captures NoMethodError" do
    app = ->(_env) { raise NoMethodError, "undefined method `foo' for nil:NilClass" }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(NoMethodError) do
      middleware.call({})
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal NoMethodError, captured[:exception].class
  end

  test "middleware captures ArgumentError" do
    app = ->(_env) { raise ArgumentError, "wrong number of arguments (given 1, expected 0)" }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(ArgumentError) do
      middleware.call({})
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal ArgumentError, captured[:exception].class
  end

  test "middleware captures TypeError" do
    app = ->(_env) { raise TypeError, "no implicit conversion of Integer into String" }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(TypeError) do
      middleware.call({})
    end

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal TypeError, captured[:exception].class
  end

  test "handle_intercepted_exception captures exceptions via class method" do
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }
    error = NameError.new("uninitialized constant SomeController::SomeConstant")

    ButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(error, env)

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal error, captured[:exception]
    assert_equal env, captured[:env]
  end

  test "middleware does not duplicate capture when already handled by interceptor" do
    error = StandardError.new("Test error")
    app = ->(_env) { raise error }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)
    env = { "butterfly_net.exception_handled" => true }

    assert_raises(StandardError) do
      middleware.call(env)
    end

    # Should not capture since it was already handled
    assert_equal 0, ButterflyNet.captured_exceptions.length
  end

  test "filters sensitive parameters from request params" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

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
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    query_string = "username=john&password=secret123&token=abc"

    filtered = middleware.send(:filter_query_string, query_string)

    assert_includes filtered, "username=john"
    assert_includes filtered, "password=[FILTERED]"
    assert_includes filtered, "token=[FILTERED]"
  end

  test "handles blank query string" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    assert_equal "", middleware.send(:filter_query_string, "")
    assert_nil middleware.send(:filter_query_string, nil)
  end

  test "handles deep nested params with recursion limit" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create deeply nested hash
    params = { "level1" => { "password" => "secret" } }

    filtered = middleware.send(:filter_params, params)
    assert_equal "[FILTERED]", filtered["level1"]["password"]
  end

  test "handles non-hash params" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    assert_equal "string", middleware.send(:filter_params, "string")
    assert_equal [ 1, 2, 3 ], middleware.send(:filter_params, [ 1, 2, 3 ])
  end

  test "safe_params rescues errors" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    request = Object.new
    def request.params
      raise StandardError, "params error"
    end

    result = middleware.send(:safe_params, request)
    assert_equal({}, result)
  end

  test "persist_exception creates error log" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

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

    error_log = ButterflyNet::ErrorLog.last
    assert_not_nil error_log
    assert_equal "StandardError", error_log.exception_class
    assert_equal "Test error", error_log.message
    assert_includes error_log.backtrace, "line1"
  end

  test "capture_and_persist sends unhandled errors through shared reporter" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Unhandled error")
    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/reports",
      "QUERY_STRING" => "token=secret&visible=true",
      "HTTP_USER_AGENT" => "TestAgent/2.0",
      "rack.input" => StringIO.new
    }

    middleware.capture_and_persist(exception, env)

    captured = ButterflyNet.captured_exceptions.last
    assert_equal exception, captured[:exception]
    assert_equal env, captured[:env]

    error_log = ButterflyNet::ErrorLog.last
    assert_equal "/reports", error_log.request_params["path"]
    assert_equal "GET", error_log.request_params["method"]
    assert_includes error_log.request_params["query_string"], "token=[FILTERED]"
    assert_equal "TestAgent/2.0", error_log.user_agent
  end

  test "persist_exception handles database errors gracefully" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    exception = StandardError.new("Test error")
    env = {}

    # Mock the ErrorLog class method to raise error
    original_method = ButterflyNet::ErrorLog.method(:find_or_create_with_occurrence)
    ButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence) do |*args|
      raise StandardError, "DB error"
    end

    begin
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    ensure
      # Restore original method
      ButterflyNet::ErrorLog.define_singleton_method(:find_or_create_with_occurrence, original_method)
    end
  end

  test "extract_request_params extracts all relevant data" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

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
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

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
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

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

  test "persist_exception handles ActiveRecord::StatementInvalid gracefully" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Test error")
    env = {}

    # Mock database error - simulate database is down
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise ActiveRecord::StatementInvalid, "PG::ConnectionBad: connection failed"
    } do
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    end
  end

  test "persist_exception handles ActiveRecord::RecordInvalid gracefully" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Test error")
    env = {}

    # Mock validation error
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise ActiveRecord::RecordInvalid, "Validation failed"
    } do
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    end
  end

  test "persist_exception handles connection pool exhaustion" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Test error")
    env = {}

    # Mock connection pool error
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise ActiveRecord::ConnectionTimeoutError, "could not obtain a connection from the pool"
    } do
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    end
  end

  test "middleware re-raises original exception even when persistence fails" do
    error = StandardError.new("Original error")
    app = ->(_env) { raise error }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    # Mock persistence failure
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise StandardError, "DB error"
    } do
      # Should still raise the original error
      raised_error = assert_raises(StandardError) do
        middleware.call({})
      end

      assert_equal "Original error", raised_error.message
      assert_equal error, raised_error
    end
  end

  test "capture_and_persist marks exception as handled in env" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Test error")
    env = {}

    middleware.capture_and_persist(exception, env)

    assert env["butterfly_net.exception_handled"]
  end

  test "handle_intercepted_exception class method creates handler and captures" do
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }
    error = RuntimeError.new("Test error")
    error.set_backtrace([ "line1" ])

    ButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(error, env)

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal error, captured[:exception]
  end

  test "filter_params prevents infinite recursion with depth limit" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create deeply nested hash (12 levels)
    params = { "level1" => {} }
    current = params["level1"]
    11.times do |i|
      current["level#{i + 2}"] = {}
      current = current["level#{i + 2}"]
    end
    current["password"] = "secret"

    # Should not raise StackLevelTooDeep
    assert_nothing_raised do
      filtered = middleware.send(:filter_params, params)
      # The password at depth 12 should not be filtered due to depth limit
      assert_not_nil filtered
    end
  end

  test "extract_request_params handles missing rack.input" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    env = {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/test",
      "QUERY_STRING" => "key=value"
      # Deliberately omitting rack.input
    }

    # Should not raise
    assert_nothing_raised do
      params = middleware.send(:extract_request_params, env)
      assert_equal "/test", params[:path]
      assert_equal "GET", params[:method]
    end
  end

  test "filter_query_string handles special characters" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    query_string = "name=John+Doe&password=secret%21%40&email=test%40example.com"

    filtered = middleware.send(:filter_query_string, query_string)

    assert_includes filtered, "name=John+Doe"
    assert_includes filtered, "password=[FILTERED]"
    assert_includes filtered, "email=test%40example.com"
  end

  # Edge Case: Database connection failures during exception capture
  test "persist_exception handles database connection not established error" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Test error")
    env = {}

    # Simulate database connection not established
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise ActiveRecord::ConnectionNotEstablished, "Database connection not established"
    } do
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    end
  end

  test "persist_exception handles database unavailable scenario" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)
    exception = StandardError.new("Test error")
    env = {}

    # Simulate database completely unavailable
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise ActiveRecord::NoDatabaseError, "Database does not exist"
    } do
      # Should not raise, just log
      assert_nothing_raised do
        middleware.send(:persist_exception, exception, env)
      end
    end
  end

  test "middleware re-raises original exception when database fails" do
    error = RuntimeError.new("Original application error")
    app = ->(_env) { raise error }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    # Mock database failure during persistence
    ButterflyNet::ErrorLog.stub :find_or_create_with_occurrence, ->(*args) {
      raise ActiveRecord::ConnectionNotEstablished, "DB down"
    } do
      # Should still raise the original error, not the database error
      raised_error = assert_raises(RuntimeError) do
        middleware.call({})
      end

      assert_equal "Original application error", raised_error.message
      assert_equal error, raised_error
    end
  end

  # Edge Case: Circular references in params
  test "filter_params handles circular reference in hash" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create a hash with circular reference
    params = { "user" => { "name" => "John" } }
    params["user"]["self"] = params["user"]

    # Should not raise StackLevelTooDeep or SystemStackError
    assert_nothing_raised do
      filtered = middleware.send(:filter_params, params)
      # Verify basic filtering still works
      assert_equal "John", filtered["user"]["name"]
    end
  end

  test "filter_params handles deeply nested circular reference" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create multiple levels with circular reference
    params = { "level1" => { "level2" => { "password" => "secret" } } }
    params["level1"]["level2"]["circular"] = params

    # Should not crash due to depth limit
    assert_nothing_raised do
      filtered = middleware.send(:filter_params, params)
      assert_not_nil filtered
    end
  end

  test "safe_params handles circular references in request params" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    request = Object.new
    def request.params
      # Simulate params with circular reference
      p = { "data" => {} }
      p["data"]["self"] = p
      p
    end

    # Should handle gracefully without crashing
    assert_nothing_raised do
      result = middleware.send(:safe_params, request)
      # Verify we get a hash back (even if it has circular refs)
      assert_kind_of Hash, result
    end
  end

  # Edge Case: Very large backtrace handling
  test "persist_exception handles very large backtrace (1000+ lines)" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    exception = StandardError.new("Test error")
    # Create a backtrace with 1500 lines
    large_backtrace = (1..1500).map { |i| "/app/lib/file#{i}.rb:#{i}:in `method#{i}'" }
    exception.set_backtrace(large_backtrace)

    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/test",
      "rack.input" => StringIO.new
    }

    # Should handle large backtrace without memory issues
    assert_nothing_raised do
      middleware.send(:persist_exception, exception, env)
    end

    error_log = ButterflyNet::ErrorLog.last
    assert_not_nil error_log
    # Verify backtrace was stored (it will be a very long string)
    assert error_log.backtrace.length > 10000
  end

  test "extract_request_params handles very large params" do
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(nil)

    # Create very large params (simulate large file upload metadata)
    large_data = "x" * 100000
    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/upload",
      "QUERY_STRING" => "file_size=large",
      "rack.input" => StringIO.new("data=#{large_data}")
    }

    # Should handle large params without issues
    assert_nothing_raised do
      params = middleware.send(:extract_request_params, env)
      assert_equal "/upload", params[:path]
      assert_equal "POST", params[:method]
    end
  end

  test "middleware handles exception with extremely long message" do
    error = StandardError.new("Error: " + "x" * 50000)
    app = ->(_env) { raise error }
    middleware = ButterflyNet::Middleware::ExceptionCatcher.new(app)

    assert_raises(StandardError) do
      middleware.call({})
    end

    # Verify it was captured despite large message
    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal error, captured[:exception]
  end
end
