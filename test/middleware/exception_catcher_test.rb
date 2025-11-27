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
    assert_instance_of Time, captured[:captured_at]
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
end
