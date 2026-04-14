# frozen_string_literal: true

require "test_helper"

class ButterflyNet::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ButterflyNet::ErrorOccurrence.delete_all
    ButterflyNet::ErrorLog.delete_all
  end

  test "summary returns JSON with all KPI metrics" do
    # Create test data
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "TestError",
      message: "test message",
      status: "open"
    )
    error_log.occurrences.create!(user_id: "user1", created_at: Time.current)

    get butterfly_net.analytics_summary_path, headers: { "Accept" => "application/json" }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_nil json_response["total_open_errors"]
    assert_not_nil json_response["total_affected_users"]
    assert_not_nil json_response["mean_time_to_resolution"]
    assert_not_nil json_response["total_occurrences"]
    assert_not_nil json_response["status_breakdown"]
  end

  test "summary returns correct open error count" do
    e1 = ButterflyNet::ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
    e2 = ButterflyNet::ErrorLog.create!(exception_class: "Error2", message: "msg2", status: "open")
    e3 = ButterflyNet::ErrorLog.create!(exception_class: "Error3", message: "msg3", status: "resolved")
    e1.occurrences.create!(created_at: Time.current)
    e2.occurrences.create!(created_at: Time.current)
    e3.occurrences.create!(created_at: Time.current)

    get butterfly_net.analytics_summary_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 2, json_response["total_open_errors"]
  end

  test "summary returns status breakdown" do
    e1 = ButterflyNet::ErrorLog.create!(exception_class: "Error1", message: "msg1", status: "open")
    e2 = ButterflyNet::ErrorLog.create!(exception_class: "Error2", message: "msg2", status: "in_progress")
    e1.occurrences.create!(created_at: Time.current)
    e2.occurrences.create!(created_at: Time.current)

    get butterfly_net.analytics_summary_path

    assert_response :success
    json_response = JSON.parse(response.body)

    breakdown = json_response["status_breakdown"]
    assert_equal 1, breakdown["open"]
    assert_equal 1, breakdown["in_progress"]
    assert_equal 0, breakdown["resolved"]
    assert_equal 0, breakdown["dismissed"]
  end

  test "top_errors returns JSON with top errors" do
    error1 = ButterflyNet::ErrorLog.create!(exception_class: "FrequentError", message: "msg1")
    error2 = ButterflyNet::ErrorLog.create!(exception_class: "RareError", message: "msg2")

    5.times { error1.occurrences.create! }
    2.times { error2.occurrences.create! }

    get butterfly_net.analytics_top_errors_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_nil json_response["top_errors"]
    assert_equal 2, json_response["top_errors"].length
    assert_equal "FrequentError", json_response["top_errors"][0]["exception_class"]
    assert_equal 5, json_response["top_errors"][0]["occurrence_count"]
  end

  test "top_errors respects limit parameter" do
    5.times do |i|
      error = ButterflyNet::ErrorLog.create!(exception_class: "Error#{i}", message: "msg#{i}")
      (i + 1).times { error.occurrences.create! }
    end

    get butterfly_net.analytics_top_errors_path(limit: 3)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 3, json_response["top_errors"].length
  end

  test "time_series returns JSON with all time series data" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "Error", message: "msg")
    error_log.occurrences.create!(user_id: "user1")

    get butterfly_net.analytics_time_series_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not_nil json_response["affected_users"]
    assert_not_nil json_response["occurrences"]
    assert_not_nil json_response["new_errors"]
  end

  test "time_series returns correct data structure" do
    get butterfly_net.analytics_time_series_path(days: 7)

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

  test "time_series respects date range parameters" do
    start_date = (Date.current - 13).iso8601
    end_date = Date.current.iso8601

    get butterfly_net.analytics_time_series_path(start_date: start_date, end_date: end_date)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 14, json_response["affected_users"].length
    assert_equal 14, json_response["occurrences"].length
    assert_equal 14, json_response["new_errors"].length
  end

  test "summary handles empty database gracefully" do
    get butterfly_net.analytics_summary_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 0, json_response["total_open_errors"]
    assert_equal 0, json_response["total_affected_users"]
    assert_equal 0.0, json_response["mean_time_to_resolution"]
    assert_equal 0, json_response["total_occurrences"]
  end

  test "summary respects date range parameters" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RangeError", message: "msg", status: "open")
    in_range_time = 2.days.ago
    out_of_range_time = 12.days.ago

    error_log.occurrences.create!(user_id: "recent-user", created_at: in_range_time)
    error_log.occurrences.create!(user_id: "old-user", created_at: out_of_range_time)

    get butterfly_net.analytics_summary_path,
      params: { start_date: 6.days.ago.to_date.iso8601, end_date: Date.current.iso8601 }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 1, json_response["total_open_errors"]
    assert_equal 1, json_response["total_affected_users"]
    assert_equal 1, json_response["total_occurrences"]
  end

  test "time_series respects explicit date range parameters" do
    error_log = ButterflyNet::ErrorLog.create!(exception_class: "RangeError", message: "msg")
    error_log.occurrences.create!(user_id: "recent-user", created_at: 2.days.ago)
    error_log.occurrences.create!(user_id: "old-user", created_at: 10.days.ago)

    get butterfly_net.analytics_time_series_path,
      params: { start_date: 6.days.ago.to_date.iso8601, end_date: Date.current.iso8601 }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 7, json_response["affected_users"].length
    assert_equal 1, json_response["affected_users"].sum { |item| item["count"] }
  end

  test "top_errors handles empty database gracefully" do
    get butterfly_net.analytics_top_errors_path

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal [], json_response["top_errors"]
  end

  test "time_series handles empty database gracefully" do
    get butterfly_net.analytics_time_series_path(days: 7)

    assert_response :success
    json_response = JSON.parse(response.body)

    # Should return 7 days of zero counts
    assert_equal 7, json_response["affected_users"].length
    json_response["affected_users"].each do |item|
      assert_equal 0, item["count"]
    end
  end

  test "top_errors handles invalid limit parameter" do
    error = ButterflyNet::ErrorLog.create!(exception_class: "Error", message: "msg")
    error.occurrences.create!

    get butterfly_net.analytics_top_errors_path(limit: "invalid")

    assert_response :success
    json_response = JSON.parse(response.body)

    # Should default to 10 when invalid
    assert_not_nil json_response["top_errors"]
  end

  test "time_series handles invalid date parameters" do
    get butterfly_net.analytics_time_series_path(start_date: "invalid", end_date: "also-invalid")

    assert_response :success
    json_response = JSON.parse(response.body)

    # Invalid dates fall back to the default 7-day range
    assert_equal 7, json_response["affected_users"].length
  end

  test "time_series defaults to 7 days without date parameters" do
    get butterfly_net.analytics_time_series_path

    assert_response :success
    json_response = JSON.parse(response.body)

    # No params means default 7-day range from AnalyticsDateRange
    assert_equal 7, json_response["affected_users"].length
  end
end
