# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

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

  # Tests for fetch_blame action
  test "fetch_blame updates error_log with blame information" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    # Mock the GitBlame service
    mock_result = MarcoButterflyNet::Services::GitBlame::BlameResult.new(
      file: "app/models/user.rb",
      line_number: 42,
      commit_sha: "abc123def456",
      author_name: "Test Developer",
      author_email: "dev@example.com",
      commit_date: Time.current,
      line_content: "def save"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, mock_result, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      post marco_butterfly_net.fetch_blame_dashboard_path(error_log)
    end

    error_log.reload
    assert_equal "app/models/user.rb", error_log.blame_file
    assert_equal 42, error_log.blame_line_number
    assert_equal "abc123def456", error_log.blame_commit_sha
    assert_equal "Test Developer", error_log.blame_author_name
    assert_equal "dev@example.com", error_log.blame_author_email
    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_equal "Git blame information retrieved successfully.", flash[:notice]

    service_mock.verify
  end

  test "fetch_blame with force parameter refetches existing blame" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'",
      blame_file: "old_file.rb",
      blame_line_number: 10,
      blame_commit_sha: "old123",
      blame_author_name: "Old Author",
      blame_author_email: "old@example.com",
      blame_commit_date: 1.day.ago
    )

    mock_result = MarcoButterflyNet::Services::GitBlame::BlameResult.new(
      file: "app/models/user.rb",
      line_number: 42,
      commit_sha: "new456",
      author_name: "New Author",
      author_email: "new@example.com",
      commit_date: Time.current,
      line_content: "def save"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, mock_result, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      post marco_butterfly_net.fetch_blame_dashboard_path(error_log), params: { force: "true" }
    end

    error_log.reload
    assert_equal "new456", error_log.blame_commit_sha
    assert_equal "New Author", error_log.blame_author_name
    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)

    service_mock.verify
  end

  test "fetch_blame when git blame service returns nil" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, nil, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      post marco_butterfly_net.fetch_blame_dashboard_path(error_log)
    end

    error_log.reload
    assert_nil error_log.blame_file
    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_equal "Could not retrieve git blame information. The file may not be in the repository.", flash[:alert]

    service_mock.verify
  end

  test "fetch_blame redirects back to error detail page" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, nil, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      post marco_butterfly_net.fetch_blame_dashboard_path(error_log)
    end

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)

    service_mock.verify
  end

  test "fetch_blame flash messages for success and failure cases" do
    # Success case
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    mock_result = MarcoButterflyNet::Services::GitBlame::BlameResult.new(
      file: "app/models/user.rb",
      line_number: 42,
      commit_sha: "abc123",
      author_name: "Test Developer",
      author_email: "dev@example.com",
      commit_date: Time.current,
      line_content: "def save"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, mock_result, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      post marco_butterfly_net.fetch_blame_dashboard_path(error_log)
    end
    assert_equal "Git blame information retrieved successfully.", flash[:notice]
    service_mock.verify
  end

  test "fetch_blame flash message for failure case" do
    # Failure case
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "/app/models/user.rb:42:in `save'"
    )

    service_mock = Minitest::Mock.new
    service_mock.expect(:blame_from_backtrace, nil, [ error_log.backtrace_lines ])

    MarcoButterflyNet::Services::GitBlame.stub(:new, service_mock) do
      post marco_butterfly_net.fetch_blame_dashboard_path(error_log)
    end
    assert_equal "Could not retrieve git blame information. The file may not be in the repository.", flash[:alert]
    service_mock.verify
  end

  # Tests for create_issue action
  test "create_issue updates error_log with GitHub issue information" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    mock_result = MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
      success: true,
      issue_number: 123,
      issue_url: "https://github.com/test_owner/test_repo/issues/123",
      error_message: nil
    )

    # Mock the service to avoid calling GitHub API
    service_mock = Minitest::Mock.new
    def service_mock.create_issue_for_error(*args, **kwargs)
      @create_issue_called = true
      MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
        success: true,
        issue_number: 123,
        issue_url: "https://github.com/test_owner/test_repo/issues/123",
        error_message: nil
      )
    end

    MarcoButterflyNet::Services::GitHubIssueCreator.stub(:new, service_mock) do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end

    error_log.reload
    assert_equal 123, error_log.github_issue_number
    assert_equal "https://github.com/test_owner/test_repo/issues/123", error_log.github_issue_url
    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_equal "GitHub issue #123 created successfully.", flash[:notice]

    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue when GitHub is not configured shows alert" do
    MarcoButterflyNet.reset_configuration!

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    post marco_butterfly_net.create_issue_dashboard_path(error_log)

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_equal "GitHub integration is not configured. Please set github_access_token, github_repo_owner, and github_repo_name.", flash[:alert]
  end

  test "create_issue when issue creation fails" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    service_mock = Minitest::Mock.new
    def service_mock.create_issue_for_error(*args, **kwargs)
      MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
        success: false,
        issue_number: nil,
        issue_url: nil,
        error_message: "API rate limit exceeded"
      )
    end

    MarcoButterflyNet::Services::GitHubIssueCreator.stub(:new, service_mock) do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end

    error_log.reload
    assert_nil error_log.github_issue_number
    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_equal "Failed to create GitHub issue: API rate limit exceeded", flash[:alert]

    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue when issue already exists returns existing issue" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      github_issue_number: 456,
      github_issue_url: "https://github.com/test_owner/test_repo/issues/456"
    )

    # When error already has a GitHub issue, create_github_issue returns early without calling the service
    post marco_butterfly_net.create_issue_dashboard_path(error_log)

    error_log.reload
    assert_equal 456, error_log.github_issue_number
    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
    assert_equal "GitHub issue #456 created successfully.", flash[:notice]

    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue flash messages for success and failure cases" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    # Success case
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    service_mock = Minitest::Mock.new
    def service_mock.create_issue_for_error(*args, **kwargs)
      MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
        success: true,
        issue_number: 789,
        issue_url: "https://github.com/test_owner/test_repo/issues/789",
        error_message: nil
      )
    end

    MarcoButterflyNet::Services::GitHubIssueCreator.stub(:new, service_mock) do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end
    assert_equal "GitHub issue #789 created successfully.", flash[:notice]

    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue flash message for failure case" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
    end

    # Failure case
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    service_mock = Minitest::Mock.new
    def service_mock.create_issue_for_error(*args, **kwargs)
      MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
        success: false,
        issue_number: nil,
        issue_url: nil,
        error_message: "Network error"
      )
    end

    MarcoButterflyNet::Services::GitHubIssueCreator.stub(:new, service_mock) do
      post marco_butterfly_net.create_issue_dashboard_path(error_log)
    end
    assert_equal "Failed to create GitHub issue: Network error", flash[:alert]

    MarcoButterflyNet.reset_configuration!
  end

  test "create_issue redirects back to error detail page" do
    MarcoButterflyNet.reset_configuration!

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    post marco_butterfly_net.create_issue_dashboard_path(error_log)

    assert_redirected_to marco_butterfly_net.dashboard_path(error_log)
  end

  # Tests for analytics action
  test "analytics page renders successfully" do
    get marco_butterfly_net.analytics_path

    assert_response :success
  end

  test "analytics page returns 200 status" do
    get marco_butterfly_net.analytics_path

    assert_response 200
  end
end
