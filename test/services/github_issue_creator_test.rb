# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::Services::GitHubIssueCreatorTest < ActiveSupport::TestCase
  setup do
    MarcoButterflyNet.reset_configuration!
    MarcoButterflyNet::ErrorOccurrence.delete_all
    MarcoButterflyNet::ErrorLog.delete_all
  end

  teardown do
    MarcoButterflyNet.reset_configuration!
  end

  test "initializes with default configuration" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new
    assert_not service.configured?
  end

  test "initializes with custom configuration" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "test_token",
      repo: "owner/repo"
    )
    assert service.configured?
    assert_equal "owner/repo", service.repo
  end

  test "uses global configuration when available" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "configured_token"
      config.github_repo_owner = "configured_owner"
      config.github_repo_name = "configured_repo"
    end

    service = MarcoButterflyNet::Services::GitHubIssueCreator.new
    assert service.configured?
    assert_equal "configured_owner/configured_repo", service.repo
  end

  test "configured? returns false when access token is missing" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: nil,
      repo: "owner/repo"
    )
    assert_not service.configured?
  end

  test "configured? returns false when repo is missing" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: nil
    )
    assert_not service.configured?
  end

  test "create_issue_for_error returns error when client not configured" do
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    service = MarcoButterflyNet::Services::GitHubIssueCreator.new
    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_equal "GitHub client not configured", result.error_message
  end

  test "create_issue_for_error returns error when repo not configured" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: nil
    )
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_equal "Repository not configured", result.error_message
  end

  test "IssueResult struct has expected attributes" do
    result = MarcoButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
      success: true,
      issue_number: 123,
      issue_url: "https://github.com/owner/repo/issues/123",
      error_message: nil
    )

    assert result.success
    assert_equal 123, result.issue_number
    assert_equal "https://github.com/owner/repo/issues/123", result.issue_url
    assert_nil result.error_message
  end

  test "build_issue_title truncates long messages" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    long_message = "a" * 200
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: long_message
    )

    title = service.send(:build_issue_title, error_log)

    # Title includes "[Error] RuntimeError: " prefix plus truncated message
    assert title.length <= 110  # Allow for prefix
    assert_includes title, "[Error] RuntimeError:"
  end

  test "build_issue_body includes error details" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "StandardError",
      message: "Test error message",
      backtrace: "line1\nline2\nline3"
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "## Error Details"
    assert_includes body, "StandardError"
    assert_includes body, "Test error message"
    assert_includes body, "## Stack Trace"
  end

  test "build_issue_body includes blame information when provided" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    blame_result = MarcoButterflyNet::Services::GitBlame::BlameResult.new(
      file: "app/controllers/test_controller.rb",
      line_number: 42,
      commit_sha: "abc123def456",
      author_name: "Test Author",
      author_email: "test@example.com",
      commit_date: Time.now.utc,
      line_content: "raise RuntimeError"
    )

    body = service.send(:build_issue_body, error_log, blame_result)

    assert_includes body, "## Git Blame Information"
    assert_includes body, "Test Author"
    assert_includes body, "test@example.com"
    assert_includes body, "abc123de"
    assert_includes body, "raise RuntimeError"
  end

  test "build_issue_body includes request details when present" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      request_params: { path: "/api/users", method: "POST" },
      user_agent: "Mozilla/5.0"
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "## Request Details"
    assert_includes body, "/api/users"
    assert_includes body, "POST"
    assert_includes body, "Mozilla/5.0"
  end

  test "build_issue_body limits backtrace to 30 lines" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    backtrace_lines = (1..50).map { |i| "line #{i}" }
    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: backtrace_lines.join("\n")
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "... (20 more lines)"
  end

  test "build_labels includes default labels" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [])

    assert_includes labels, "bug"
    assert_includes labels, "error-tracking"
  end

  test "build_labels merges additional labels" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [ "critical", "production" ])

    assert_includes labels, "bug"
    assert_includes labels, "error-tracking"
    assert_includes labels, "critical"
    assert_includes labels, "production"
  end

  test "build_labels removes duplicates" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [ "bug", "custom" ])

    assert_equal 3, labels.length
    assert_equal 1, labels.count("bug")
  end

  test "create_client creates Octokit client" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "test_token",
      repo: "owner/repo"
    )

    assert_not_nil service.client
    assert_instance_of Octokit::Client, service.client
  end

  test "build_issue_title handles nil message" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: nil
    )

    title = service.send(:build_issue_title, error_log)

    assert_includes title, "[Error] RuntimeError"
  end

  test "build_issue_body handles empty backtrace" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: ""
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "## Error Details"
    assert_includes body, "RuntimeError"
  end

  test "build_issue_body handles nil request_params" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      request_params: nil
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "## Error Details"
  end

  test "configured? returns true only when all required fields present" do
    # All present
    service1 = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )
    assert service1.configured?

    # Missing token
    service2 = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "",
      repo: "owner/repo"
    )
    assert_not service2.configured?

    # Missing repo
    service3 = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: ""
    )
    assert_not service3.configured?
  end

  test "repo returns properly formatted string" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    assert_equal "owner/repo", service.repo
  end

  test "build_labels handles empty additional_labels" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [])

    assert_includes labels, "bug"
    assert_includes labels, "error-tracking"
    assert_equal 2, labels.length
  end

  test "create_issue_for_error handles 401 Unauthorized error" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "invalid_token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock Octokit client to raise Unauthorized error
    mock_client = Minitest::Mock.new
    mock_client.expect(:create_issue, nil) do |*args|
      raise Octokit::Unauthorized, "Bad credentials"
    end

    service.instance_variable_set(:@client, mock_client)

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "Bad credentials"
    mock_client.verify
  end

  test "create_issue_for_error handles 404 NotFound error" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "nonexistent/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock Octokit client to raise NotFound error
    mock_client = Minitest::Mock.new
    mock_client.expect(:create_issue, nil) do |*args|
      raise Octokit::NotFound, "Not Found"
    end

    service.instance_variable_set(:@client, mock_client)

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "Not Found"
    mock_client.verify
  end

  test "create_issue_for_error handles rate limit error" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock Octokit client to raise TooManyRequests error
    mock_client = Minitest::Mock.new
    mock_client.expect(:create_issue, nil) do |*args|
      raise Octokit::TooManyRequests, "API rate limit exceeded"
    end

    service.instance_variable_set(:@client, mock_client)

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "rate limit"
    mock_client.verify
  end

  test "create_issue_for_error handles network errors" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Mock Octokit client to raise a network error
    mock_client = Minitest::Mock.new
    mock_client.expect(:create_issue, nil) do |*args|
      raise Faraday::ConnectionFailed, "Connection failed"
    end

    service.instance_variable_set(:@client, mock_client)

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "Unexpected error"
    mock_client.verify
  end

  test "create_issue_for_error successfully creates issue with mocked client" do
    service = MarcoButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = MarcoButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: "line1\nline2"
    )

    # Mock successful issue creation
    mock_response = Object.new
    def mock_response.number; 42; end
    def mock_response.html_url; "https://github.com/owner/repo/issues/42"; end

    mock_client = Minitest::Mock.new
    mock_client.expect(:create_issue, mock_response, [ String, String, String, Hash ])

    service.instance_variable_set(:@client, mock_client)

    result = service.create_issue_for_error(error_log)

    assert result.success
    assert_equal 42, result.issue_number
    assert_equal "https://github.com/owner/repo/issues/42", result.issue_url
    assert_nil result.error_message
    mock_client.verify
  end
end
