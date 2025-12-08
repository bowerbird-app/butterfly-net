# frozen_string_literal: true

require "test_helper"
require "ostruct"

class MarcoButterflyNet::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    MarcoButterflyNet::ErrorOccurrence.delete_all
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
    # Create 30 errors with incrementing timestamps to ensure proper ordering
    30.times do |i|
      travel_to(i.seconds.from_now) do
        MarcoButterflyNet::ErrorLog.create!(
          exception_class: "Error#{i}",
          message: "Message #{i}"
        )
      end
    end

    get marco_butterfly_net.dashboard_index_path
    assert_response :success
    # Should show first 25 items (most recent, Error29 down to Error5)
    assert_match /Error29/, response.body
    assert_match /Error5/, response.body
    # Should not show item 26 on first page (Error4 and earlier)
    assert_no_match /Error4/, response.body

    get marco_butterfly_net.dashboard_index_path(page: 2)
    assert_response :success
    # Should show remaining items on page 2 (Error4 down to Error0)
    assert_match /Error4/, response.body
    assert_match /Error0/, response.body
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

  test "index returns JSON for API requests" do
    3.times do |i|
      MarcoButterflyNet::ErrorLog.create!(
        exception_class: "Error#{i}",
        message: "Message #{i}"
      )
    end

    get marco_butterfly_net.dashboard_index_path, headers: { "Accept" => "application/json" }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 3, json_response["error_logs"].length
    assert_not_nil json_response["pagy"]
    assert_equal 1, json_response["pagy"]["page"]
  end

  test "index JSON includes affected user counts" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "TestError",
      message: "Test message"
    )
    error_log.occurrences.create!(user_id: "user1")
    error_log.occurrences.create!(user_id: "user2")

    get marco_butterfly_net.dashboard_index_path, headers: { "Accept" => "application/json" }

    assert_response :success
    json_response = JSON.parse(response.body)
    error_data = json_response["error_logs"].first
    assert_equal 2, error_data["affected_count"]
  end

  test "fetch_blame retrieves blame info successfully" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "#{Rails.root}/Gemfile:1:in `<top>'"
    )

    post marco_butterfly_net.fetch_blame_dashboard_path(error_log)

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
  end

  test "fetch_blame handles missing blame info" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/nonexistent/file.rb:1:in `<top>'"
    )

    post marco_butterfly_net.fetch_blame_dashboard_path(error_log)

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_match /Could not retrieve/, flash[:alert]
  end

  test "fetch_blame with force parameter refetches blame" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "#{Rails.root}/Gemfile:1:in `<top>'"
    )

    post marco_butterfly_net.fetch_blame_dashboard_path(error_log), params: { force: "true" }

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
  end

  test "create_issue fails when GitHub not configured" do
    MarcoButterflyNet.reset_configuration!
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    post marco_butterfly_net.create_issue_dashboard_path(error_log)

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_match /GitHub integration is not configured/, flash[:alert]
  ensure
    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue succeeds when GitHub is configured" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "fake_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock the Octokit client to avoid actual API calls
    mock_client = Minitest::Mock.new
    mock_issue = OpenStruct.new(number: 123, html_url: "https://github.com/test_owner/test_repo/issues/123")
    mock_client.expect(:create_issue, mock_issue, [String, String, String, Hash])

    MarcoButterflyNet::Services::GitHubIssueCreator.stub :new, -> { 
      creator = Object.new
      def creator.configured?; true; end
      def creator.repo; "test_owner/test_repo"; end
      def creator.client; @client; end
      def creator.client=(c); @client = c; end
      def creator.create_issue_for_error(*args)
        MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
          success: true,
          issue_number: 123,
          issue_url: "https://github.com/test_owner/test_repo/issues/123",
          error_message: nil
        )
      end
      creator
    } do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    follow_redirect!
    assert_match /GitHub issue #123 created successfully/, flash[:notice]
  ensure
    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue handles API failures gracefully" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "fake_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock the service to return a failure result
    MarcoButterflyNet::Services::GitHubIssueCreator.stub :new, -> {
      creator = Object.new
      def creator.configured?; true; end
      def creator.repo; "test_owner/test_repo"; end
      def creator.create_issue_for_error(*args)
        MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
          success: false,
          issue_number: nil,
          issue_url: nil,
          error_message: "API rate limit exceeded"
        )
      end
      creator
    } do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_match /Failed to create GitHub issue: API rate limit exceeded/, flash[:alert]
  ensure
    MarcoButterflyNet.reset_configuration!
  end

  test "analytics action renders successfully" do
    get marco_butterfly_net.analytics_path

    assert_response :success
  end

  test "show displays GitHub configuration status" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    get marco_butterfly_net.dashboard_path(error_log)

    assert_response :success
    # Should have create issue button when configured
    assert_select "form[action=?]", marco_butterfly_net.create_issue_dashboard_path(error_log)
  ensure
    MarcoButterflyNet.reset_configuration!
  end
end
