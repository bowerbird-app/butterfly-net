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
end
