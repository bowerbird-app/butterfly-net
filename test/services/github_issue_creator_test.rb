# frozen_string_literal: true

require "test_helper"
require "ostruct"

class ButterflyNet::Services::GitHubIssueCreatorTest < ActiveSupport::TestCase
  setup do
    ButterflyNet.reset_configuration!
    ButterflyNet::ErrorOccurrence.delete_all
    ButterflyNet::ErrorLog.delete_all
  end

  teardown do
    ButterflyNet.reset_configuration!
  end

  test "initializes with default configuration" do
    service = ButterflyNet::Services::GitHubIssueCreator.new
    assert_not service.configured?
  end

  test "initializes with custom configuration" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "test_token",
      repo: "owner/repo"
    )
    assert service.configured?
    assert_equal "owner/repo", service.repo
  end

  test "uses global configuration when available" do
    ButterflyNet.configure do |config|
      config.github_access_token = "configured_token"
      config.github_repo_owner = "configured_owner"
      config.github_repo_name = "configured_repo"
    end

    service = ButterflyNet::Services::GitHubIssueCreator.new
    assert service.configured?
    assert_equal "configured_owner/configured_repo", service.repo
  end

  test "configured? returns false when access token is missing" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: nil,
      repo: "owner/repo"
    )
    assert_not service.configured?
  end

  test "configured? returns false when repo is missing" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: nil
    )
    assert_not service.configured?
  end

  test "create_issue_for_error returns error when client not configured" do
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    service = ButterflyNet::Services::GitHubIssueCreator.new
    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_equal "GitHub client not configured", result.error_message
  end

  test "create_issue_for_error returns error when repo not configured" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: nil
    )
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_equal "Repository not configured", result.error_message
  end

  test "IssueResult struct has expected attributes" do
    result = ButterflyNet::Services::GitHubIssueCreator::IssueResult.new(
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
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    long_message = "a" * 200
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: long_message
    )

    title = service.send(:build_issue_title, error_log)

    # Title includes "[Error] RuntimeError: " prefix plus truncated message
    assert title.length <= 110  # Allow for prefix
    assert_includes title, "[Error] RuntimeError:"
  end

  test "build_issue_body includes error details" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
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
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    blame_result = ButterflyNet::Services::GitBlame::BlameResult.new(
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
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
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
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    backtrace_lines = (1..50).map { |i| "line #{i}" }
    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: backtrace_lines.join("\n")
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "... (20 more lines)"
  end

  test "build_labels includes default labels" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [])

    assert_includes labels, "bug"
    assert_includes labels, "error-tracking"
  end

  test "build_labels merges additional labels" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
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
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [ "bug", "custom" ])

    assert_equal 3, labels.length
    assert_equal 1, labels.count("bug")
  end

  test "create_client creates Octokit client" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "test_token",
      repo: "owner/repo"
    )

    assert_not_nil service.client
    assert_instance_of Octokit::Client, service.client
  end

  test "build_issue_title handles nil message" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: nil
    )

    title = service.send(:build_issue_title, error_log)

    assert_includes title, "[Error] RuntimeError"
  end

  test "build_issue_body handles empty backtrace" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      backtrace: ""
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "## Error Details"
    assert_includes body, "RuntimeError"
  end

  test "build_issue_body handles nil request_params" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error",
      request_params: nil
    )

    body = service.send(:build_issue_body, error_log, nil)

    assert_includes body, "## Error Details"
  end

  test "configured? returns true only when all required fields present" do
    # All present
    service1 = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )
    assert service1.configured?

    # Missing token
    service2 = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "",
      repo: "owner/repo"
    )
    assert_not service2.configured?

    # Missing repo
    service3 = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: ""
    )
    assert_not service3.configured?
  end

  test "repo returns properly formatted string" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    assert_equal "owner/repo", service.repo
  end

  test "build_labels handles empty additional_labels" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    labels = service.send(:build_labels, error_log, [])

    assert_includes labels, "bug"
    assert_includes labels, "error-tracking"
    assert_equal 2, labels.length
  end

  # GitHub API failure tests
  test "create_issue_for_error handles Octokit::Unauthorized error" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "invalid_token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      response = OpenStruct.new(headers: {}, status: 401, body: { message: "Bad credentials" })
      raise Octokit::Unauthorized.new(response)
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "Bad credentials"
    assert_nil result.issue_number
    assert_nil result.issue_url
  end

  test "create_issue_for_error handles Octokit::Forbidden error" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      response = OpenStruct.new(headers: {}, status: 403, body: { message: "Resource not accessible by personal access token" })
      raise Octokit::Forbidden.new(response)
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "not accessible"
  end

  test "create_issue_for_error handles Octokit::NotFound error" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "nonexistent/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      response = OpenStruct.new(headers: {}, status: 404, body: { message: "Repository not found" })
      raise Octokit::NotFound.new(response)
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "not found"
  end

  test "create_issue_for_error handles Octokit::TooManyRequests (rate limiting)" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      response = OpenStruct.new(headers: {}, status: 429, body: { message: "API rate limit exceeded" })
      raise Octokit::TooManyRequests.new(response)
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "rate limit"
  end

  test "create_issue_for_error handles Octokit::ServerError" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      response = OpenStruct.new(headers: {}, status: 500, body: { message: "Internal server error" })
      raise Octokit::ServerError.new(response)
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "GitHub API error"
    assert_includes result.error_message, "Internal server error"
  end

  test "create_issue_for_error handles network timeout" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      raise Faraday::TimeoutError, "Request timeout"
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "Unexpected error"
    assert_includes result.error_message, "timeout"
  end

  test "create_issue_for_error handles connection failed error" do
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      raise Faraday::ConnectionFailed, "Connection refused"
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "Unexpected error"
    assert_includes result.error_message, "Connection"
  end

  test "create_issue_for_error handles invalid GitHub token format" do
    # Create service with clearly invalid token format
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "not-a-valid-token-format",
      repo: "owner/repo"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      response = OpenStruct.new(headers: {}, status: 401, body: { message: "Bad credentials" })
      raise Octokit::Unauthorized.new(response)
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    assert_includes result.error_message, "Bad credentials"
  end

  test "create_issue_for_error with malformed repo format" do
    # Test with repo that doesn't have owner/name format
    service = ButterflyNet::Services::GitHubIssueCreator.new(
      access_token: "token",
      repo: "invalid-repo-format"
    )

    error_log = ButterflyNet::ErrorLog.create!(
      exception_class: "RuntimeError",
      message: "Test error"
    )

    # Stub the create_issue method on the client instance
    # Note: Octokit::InvalidRepository is an ArgumentError, not an Octokit::Error
    client = service.client
    client.define_singleton_method(:create_issue) do |*_args, **_kwargs|
      raise Octokit::InvalidRepository, "Invalid repository format"
    end

    result = service.create_issue_for_error(error_log)

    assert_not result.success
    # InvalidRepository is an ArgumentError, so it's caught by StandardError rescue
    assert_includes result.error_message, "Unexpected error"
    assert_includes result.error_message, "Invalid repository format"
  end
end
