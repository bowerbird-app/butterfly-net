require "test_helper"

class ButterflyNetTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert ButterflyNet::VERSION
  end

  test "version number is a string" do
    assert_kind_of String, ButterflyNet::VERSION
  end

  test "version number matches expected format" do
    assert_match /\A\d+\.\d+\.\d+\z/, ButterflyNet::VERSION
  end

  test "module has captured_exceptions method" do
    assert_respond_to ButterflyNet, :captured_exceptions
  end

  test "module has capture_exception method" do
    assert_respond_to ButterflyNet, :capture_exception
  end

  test "module has error method" do
    assert_respond_to ButterflyNet, :error
  end

  test "module has clear_captured_exceptions method" do
    assert_respond_to ButterflyNet, :clear_captured_exceptions
  end

  test "capture_exception stores exception data" do
    ButterflyNet.clear_captured_exceptions

    exception = StandardError.new("Test error")
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }

    ButterflyNet.capture_exception(exception, env)

    assert_equal 1, ButterflyNet.captured_exceptions.length
    captured = ButterflyNet.captured_exceptions.first
    assert_equal exception, captured[:exception]
    assert_equal env, captured[:env]
    # ActiveSupport::TimeWithZone is a subclass/extension of Time
    assert_respond_to captured[:captured_at], :to_time
  end

  test "clear_captured_exceptions removes all captured exceptions" do
    exception = StandardError.new("Test error")
    env = { "REQUEST_METHOD" => "GET" }

    ButterflyNet.capture_exception(exception, env)
    assert ButterflyNet.captured_exceptions.any?

    ButterflyNet.clear_captured_exceptions
    assert_empty ButterflyNet.captured_exceptions
  end

  test "error reports rescued exception through shared pipeline" do
    ButterflyNet.clear_captured_exceptions

    exception = RuntimeError.new("Handled failure")
    exception.set_backtrace(["app/services/worker.rb:10:in `perform'"])

    ButterflyNet.error(exception, 123)

    captured = ButterflyNet.captured_exceptions.last
    assert_equal exception, captured[:exception]
    assert_equal({}, captured[:env])

    error_log = ButterflyNet::ErrorLog.last
    assert_equal "RuntimeError", error_log.exception_class
    assert_equal "Handled failure", error_log.message
    assert_equal({ "context" => 123 }, error_log.request_params)
    assert_includes error_log.backtrace, "app/services/worker.rb:10"
  end

  test "error reports message with structured metadata" do
    ButterflyNet.clear_captured_exceptions

    ButterflyNet.error("Aircall transcription fetch error", aircall_id: "ac-123", job: "transcription")

    captured = ButterflyNet.captured_exceptions.last
    assert_equal StandardError, captured[:exception].class
    assert_equal "Aircall transcription fetch error", captured[:exception].message

    error_log = ButterflyNet::ErrorLog.last
    assert_equal "StandardError", error_log.exception_class
    assert_equal "Aircall transcription fetch error", error_log.message
    assert_equal(
      {
        "metadata" => {
          "aircall_id" => "ac-123",
          "job" => "transcription"
        }
      },
      error_log.request_params
    )
  end

  test "error reports message with embedded exception details" do
    ButterflyNet.clear_captured_exceptions

    original = StandardError.new("timeout while fetching")
    original.set_backtrace(["app/services/transcriber.rb:42:in `call'"])

    ButterflyNet.error(
      "Aircall transcription fetch error: #{original.message}",
      aircall_id: "meeting-42",
      error: original
    )

    captured = ButterflyNet.captured_exceptions.last
    assert_equal StandardError, captured[:exception].class
    assert_equal "Aircall transcription fetch error: timeout while fetching", captured[:exception].message
    assert_equal original.backtrace, captured[:exception].backtrace

    error_log = ButterflyNet::ErrorLog.last
    assert_equal "StandardError", error_log.exception_class
    assert_equal "Aircall transcription fetch error: timeout while fetching", error_log.message
    assert_includes error_log.backtrace, "app/services/transcriber.rb:42"
    assert_equal(
      {
        "metadata" => {
          "aircall_id" => "meeting-42"
        }
      },
      error_log.request_params
    )
  end
end

class EngineInitializationTest < ActiveSupport::TestCase
  test "middleware is inserted at position 0" do
    # Get the middleware stack from the test app
    middleware_stack = Rails.application.middleware.middlewares

    # Find the ExceptionCatcher middleware
    exception_catcher_index = middleware_stack.find_index do |middleware|
      middleware.name == "ButterflyNet::Middleware::ExceptionCatcher"
    end

    # Assert it was found and is at position 0
    assert_not_nil exception_catcher_index, "ExceptionCatcher middleware not found in stack"
    assert_equal 0, exception_catcher_index, "ExceptionCatcher middleware should be at position 0"
  end

  test "ActionDispatch::DebugExceptions interceptor is registered" do
    # The interceptor should be registered during initialization
    # We can test this by checking if the class has interceptors
    assert_respond_to ActionDispatch::DebugExceptions, :interceptors

    # Verify that interceptors exist (this confirms registration happened)
    assert ActionDispatch::DebugExceptions.interceptors.any?,
      "No interceptors registered with ActionDispatch::DebugExceptions"
  end
end
