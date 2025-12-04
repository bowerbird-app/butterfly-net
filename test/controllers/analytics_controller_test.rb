# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    MarcoButterflyNet::ErrorOccurrence.delete_all
    MarcoButterflyNet::ErrorLog.delete_all
  end

  test "summary returns JSON with all KPI metrics" do
    # Create test data
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "TestError",
      message: "test message",
      status: "open"
    )
    error_log.occurrences.create!(user_id: "user1", created_at: Time.current)

    get marco_butterfly_net.analytics_summary_path, headers: { "Accept" => "application/json" }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_nil json_response["total_open_errors"]
    assert_not_nil json_response["total_affected_users_today"]
    assert_not_nil json_response["mean_time_to_resolution"]
    assert_not_nil json_response["total_occurrences_today"]
    assert_not_nil json_response["status_breakdown"]
  end

  test "summary returns correct open error count" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2", message: "msg2", status: "open")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "Error3", message: "msg3", status: "resolved")

    get marco_butterfly_net.analytics_summary_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 2, json_response["total_open_errors"]
  end

  test "summary returns status breakdown" do
    MarcoButterflyNet::ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
    MarcoButterflyNet::ErrorLog.create!(exception_class: "Error2", message: "msg2", status: "in_progress")

    get marco_butterfly_net.analytics_summary_path

    assert_response :success
    json_response = JSON.parse(response.body)

    breakdown = json_response["status_breakdown"]
    assert_equal 1, breakdown["open"]
    assert_equal 1, breakdown["in_progress"]
    assert_equal 0, breakdown["resolved"]
    assert_equal 0, breakdown["dismissed"]
  end

  test "top_errors returns JSON with top errors" do
    error1 = MarcoButterflyNet::ErrorLog.create!(exception_class: "FrequentError", message: "msg1")
    error2 = MarcoButterflyNet::ErrorLog.create!(exception_class: "RareError", message: "msg2")

    5.times { error1.occurrences.create! }
    2.times { error2.occurrences.create! }

    get marco_butterfly_net.analytics_top_errors_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_nil json_response["top_errors"]
    assert_equal 2, json_response["top_errors"].length
    assert_equal "FrequentError", json_response["top_errors"][0]["exception_class"]
    assert_equal 5, json_response["top_errors"][0]["occurrence_count"]
  end

  test "top_errors respects limit parameter" do
    5.times do |i|
      error = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error#{i}", message: "msg#{i}")
      (i + 1).times { error.occurrences.create! }
    end

    get marco_butterfly_net.analytics_top_errors_path(limit: 3)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 3, json_response["top_errors"].length
  end

  test "time_series returns JSON with all time series data" do
    error_log = MarcoButterflyNet::ErrorLog.create!(exception_class: "Error", message: "msg")
    error_log.occurrences.create!(user_id: "user1")

    get marco_butterfly_net.analytics_time_series_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_nil json_response["affected_users"]
    assert_not_nil json_response["occurrences"]
    assert_not_nil json_response["new_errors"]
  end

  test "time_series returns correct data structure" do
    get marco_butterfly_net.analytics_time_series_path(days: 7)

    assert_response :success
    json_response = JSON.parse(response.body)

    # Check data structure
    assert_equal 7, json_response["affected_users"].length
    assert_equal 7, json_response["occurrences"].length
    assert_equal 7, json_response["new_errors"].length

    # Check each item has required keys
    json_response["affected_users"].each do |item|
      assert_not_nil item["date"]
      assert_not_nil item["count"]
    end
  end

  test "time_series respects days parameter" do
    get marco_butterfly_net.analytics_time_series_path(days: 14)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 14, json_response["affected_users"].length
    assert_equal 14, json_response["occurrences"].length
    assert_equal 14, json_response["new_errors"].length
  end
end
