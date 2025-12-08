require "test_helper"

class MarcoButterflyNetTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert MarcoButterflyNet::VERSION
  end

  test "version number is a string" do
    assert_kind_of String, MarcoButterflyNet::VERSION
  end

  test "version number matches expected format" do
    assert_match /\A\d+\.\d+\.\d+\z/, MarcoButterflyNet::VERSION
  end

  test "module has captured_exceptions method" do
    assert_respond_to MarcoButterflyNet, :captured_exceptions
  end

  test "module has capture_exception method" do
    assert_respond_to MarcoButterflyNet, :capture_exception
  end

  test "module has clear_captured_exceptions method" do
    assert_respond_to MarcoButterflyNet, :clear_captured_exceptions
  end

  test "capture_exception stores exception data" do
    MarcoButterflyNet.clear_captured_exceptions

    exception = StandardError.new("Test error")
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/test" }

    MarcoButterflyNet.capture_exception(exception, env)

    assert_equal 1, MarcoButterflyNet.captured_exceptions.length
    captured = MarcoButterflyNet.captured_exceptions.first
    assert_equal exception, captured[:exception]
    assert_equal env, captured[:env]
    # ActiveSupport::TimeWithZone is a subclass/extension of Time
    assert_respond_to captured[:captured_at], :to_time
  end

  test "clear_captured_exceptions removes all captured exceptions" do
    exception = StandardError.new("Test error")
    env = { "REQUEST_METHOD" => "GET" }

    MarcoButterflyNet.capture_exception(exception, env)
    assert MarcoButterflyNet.captured_exceptions.any?

    MarcoButterflyNet.clear_captured_exceptions
    assert_empty MarcoButterflyNet.captured_exceptions
  end
end
