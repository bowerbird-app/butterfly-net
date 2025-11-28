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
end
