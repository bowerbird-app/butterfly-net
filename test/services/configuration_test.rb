# frozen_string_literal: true

require "test_helper"

class ButterflyNet::ConfigurationTest < ActiveSupport::TestCase
  setup do
    ButterflyNet.reset_configuration!
  end

  teardown do
    ButterflyNet.reset_configuration!
  end

  test "configuration initializes with nil values" do
    config = ButterflyNet::Configuration.new
    assert_nil config.github_access_token
    assert_nil config.github_repo_owner
    assert_nil config.github_repo_name
    assert_nil config.repo_path
  end

  test "configure block sets values" do
    ButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
      config.repo_path = "/path/to/repo"
    end

    assert_equal "test_token", ButterflyNet.configuration.github_access_token
    assert_equal "test_owner", ButterflyNet.configuration.github_repo_owner
    assert_equal "test_repo", ButterflyNet.configuration.github_repo_name
    assert_equal "/path/to/repo", ButterflyNet.configuration.repo_path
  end

  test "full_repo_name returns owner/repo format" do
    ButterflyNet.configure do |config|
      config.github_repo_owner = "my_org"
      config.github_repo_name = "my_app"
    end

    assert_equal "my_org/my_app", ButterflyNet.configuration.full_repo_name
  end

  test "full_repo_name returns nil when owner is missing" do
    ButterflyNet.configure do |config|
      config.github_repo_name = "my_app"
    end

    assert_nil ButterflyNet.configuration.full_repo_name
  end

  test "full_repo_name returns nil when name is missing" do
    ButterflyNet.configure do |config|
      config.github_repo_owner = "my_org"
    end

    assert_nil ButterflyNet.configuration.full_repo_name
  end

  test "github_configured? returns true when all required fields set" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
      config.github_issue_environments = %w[test]
    end

    assert ButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false when token missing" do
    ButterflyNet.configure do |config|
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
    end

    assert_not ButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false when owner missing" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_name = "repo"
    end

    assert_not ButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false when name missing" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
    end

    assert_not ButterflyNet.configuration.github_configured?
  end

  test "reset_configuration! creates new configuration" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
    end

    ButterflyNet.reset_configuration!

    assert_nil ButterflyNet.configuration.github_access_token
  end

  test "configuration is a singleton" do
    config1 = ButterflyNet.configuration
    config2 = ButterflyNet.configuration

    assert_same config1, config2
  end

  # Runtime configuration changes
  test "runtime configuration changes take effect immediately" do
    # Set initial configuration
    ButterflyNet.configure do |config|
      config.github_access_token = "initial_token"
      config.github_repo_owner = "initial_owner"
      config.github_repo_name = "initial_repo"
      config.github_issue_environments = %w[test]
    end

    assert_equal "initial_token", ButterflyNet.configuration.github_access_token
    assert_equal "initial_owner/initial_repo", ButterflyNet.configuration.full_repo_name

    # Change configuration at runtime
    ButterflyNet.configure do |config|
      config.github_access_token = "new_token"
      config.github_repo_owner = "new_owner"
      config.github_repo_name = "new_repo"
      config.github_issue_environments = %w[test]
    end

    # Verify changes take effect immediately
    assert_equal "new_token", ButterflyNet.configuration.github_access_token
    assert_equal "new_owner/new_repo", ButterflyNet.configuration.full_repo_name
    assert ButterflyNet.configuration.github_configured?
  end

  test "partial runtime configuration changes preserve other values" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
      config.repo_path = "/path/to/repo"
    end

    # Only change one value
    ButterflyNet.configure do |config|
      config.github_access_token = "new_token"
    end

    # Verify other values are preserved
    assert_equal "new_token", ButterflyNet.configuration.github_access_token
    assert_equal "owner", ButterflyNet.configuration.github_repo_owner
    assert_equal "repo", ButterflyNet.configuration.github_repo_name
    assert_equal "/path/to/repo", ButterflyNet.configuration.repo_path
  end

  test "configuration reset clears all runtime changes" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
      config.repo_path = "/path/to/repo"
    end

    # Reset configuration
    ButterflyNet.reset_configuration!

    # Verify all values are cleared
    assert_nil ButterflyNet.configuration.github_access_token
    assert_nil ButterflyNet.configuration.github_repo_owner
    assert_nil ButterflyNet.configuration.github_repo_name
    assert_nil ButterflyNet.configuration.repo_path
    assert_not ButterflyNet.configuration.github_configured?
  end

  test "setting nil values at runtime works correctly" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
    end

    # Set to nil
    ButterflyNet.configure do |config|
      config.github_access_token = nil
    end

    assert_nil ButterflyNet.configuration.github_access_token
    assert_not ButterflyNet.configuration.github_configured?
  end

  test "setting empty string values at runtime" do
    ButterflyNet.configure do |config|
      config.github_access_token = ""
      config.github_repo_owner = ""
      config.github_repo_name = ""
    end

    # Empty strings should make it not configured
    assert_not ButterflyNet.configuration.github_configured?
    assert_nil ButterflyNet.configuration.full_repo_name
  end

  # Invalid GitHub credentials
  test "github_configured? returns false with blank access token" do
    ButterflyNet.configure do |config|
      config.github_access_token = "   "
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
    end

    assert_not ButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false with blank repo owner" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "   "
      config.github_repo_name = "repo"
    end

    assert_not ButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false with blank repo name" do
    ButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "   "
    end

    assert_not ButterflyNet.configuration.github_configured?
  end

  test "full_repo_name returns nil with blank owner" do
    ButterflyNet.configure do |config|
      config.github_repo_owner = "   "
      config.github_repo_name = "repo"
    end

    assert_nil ButterflyNet.configuration.full_repo_name
  end

  test "full_repo_name returns nil with blank name" do
    ButterflyNet.configure do |config|
      config.github_repo_owner = "owner"
      config.github_repo_name = "   "
    end

    assert_nil ButterflyNet.configuration.full_repo_name
  end
end
