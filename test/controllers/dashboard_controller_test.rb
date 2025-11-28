# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    MarcoButterflyNet::ErrorLog.delete_all
  end

  test "index displays empty state when no errors" do
    get marco_butterfly_net.dashboard_index_path

    assert_response :success
    assert_match /No errors recorded yet/, response.body
  end

  test "index displays error logs" do
    MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error message"
    )

    get marco_butterfly_net.dashboard_index_path

    assert_response :success
    assert_match /RuntimeError/, response.body
    assert_match /Test error message/, response.body
  end

  test "index paginates results" do
    30.times do |i|
      MarcoButterflyNet::ErrorLog.create!(
        exception_class: "Error#{i}",
        message: "Message #{i}"
      )
    end

    get marco_butterfly_net.dashboard_index_path
    assert_response :success
    assert_match /Page 1 of 2/, response.body

    get marco_butterfly_net.dashboard_index_path(page: 2)
    assert_response :success
    assert_match /Page 2 of 2/, response.body
  end

  test "show displays error details" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "NoMethodError",
      message: "undefined method 'foo'",
      backtrace: "line1\nline2",
      request_params: { path: "/test", method: "GET" },
      user_agent: "Test Browser"
    )

    get marco_butterfly_net.dashboard_path(error_log)

    assert_response :success
    assert_match /NoMethodError/, response.body
    assert_match /undefined method/, response.body
    assert_match /line1/, response.body
    assert_match /Test Browser/, response.body
  end

  test "root redirects to dashboard index" do
    get marco_butterfly_net.root_path

    assert_response :success
  end
end
