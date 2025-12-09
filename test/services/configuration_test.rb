# frozen_string_literal: true

require "test_helper"

class MarcoButterflyNet::ConfigurationTest < ActiveSupport::TestCase
  setup do
    MarcoButterflyNet.reset_configuration!
  end

  teardown do
    MarcoButterflyNet.reset_configuration!
  end

  test "configuration initializes with nil values" do
    config = MarcoButterflyNet::Configuration.new
    assert_nil config.github_access_token
    assert_nil config.github_repo_owner
    assert_nil config.github_repo_name
    assert_nil config.repo_path
  end

  test "configure block sets values" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "test_token"
      config.github_repo_owner = "test_owner"
      config.github_repo_name = "test_repo"
      config.repo_path = "/path/to/repo"
    end

    assert_equal "test_token", MarcoButterflyNet.configuration.github_access_token
    assert_equal "test_owner", MarcoButterflyNet.configuration.github_repo_owner
    assert_equal "test_repo", MarcoButterflyNet.configuration.github_repo_name
    assert_equal "/path/to/repo", MarcoButterflyNet.configuration.repo_path
  end

  test "full_repo_name returns owner/repo format" do
    MarcoButterflyNet.configure do |config|
      config.github_repo_owner = "my_org"
      config.github_repo_name = "my_app"
    end

    assert_equal "my_org/my_app", MarcoButterflyNet.configuration.full_repo_name
  end

  test "full_repo_name returns nil when owner is missing" do
    MarcoButterflyNet.configure do |config|
      config.github_repo_name = "my_app"
    end

    assert_nil MarcoButterflyNet.configuration.full_repo_name
  end

  test "full_repo_name returns nil when name is missing" do
    MarcoButterflyNet.configure do |config|
      config.github_repo_owner = "my_org"
    end

    assert_nil MarcoButterflyNet.configuration.full_repo_name
  end

  test "github_configured? returns true when all required fields set" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
    end

    assert MarcoButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false when token missing" do
    MarcoButterflyNet.configure do |config|
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
    end

    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false when owner missing" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_name = "repo"
    end

    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false when name missing" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
    end

    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "reset_configuration! creates new configuration" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
    end

    MarcoButterflyNet.reset_configuration!

    assert_nil MarcoButterflyNet.configuration.github_access_token
  end

  test "configuration is a singleton" do
    config1 = MarcoButterflyNet.configuration
    config2 = MarcoButterflyNet.configuration

    assert_same config1, config2
  end

  # Runtime configuration changes
  test "runtime configuration changes take effect immediately" do
    # Set initial configuration
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "initial_token"
      config.github_repo_owner = "initial_owner"
      config.github_repo_name = "initial_repo"
    end

    assert_equal "initial_token", MarcoButterflyNet.configuration.github_access_token
    assert_equal "initial_owner/initial_repo", MarcoButterflyNet.configuration.full_repo_name

    # Change configuration at runtime
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "new_token"
      config.github_repo_owner = "new_owner"
      config.github_repo_name = "new_repo"
    end

    # Verify changes take effect immediately
    assert_equal "new_token", MarcoButterflyNet.configuration.github_access_token
    assert_equal "new_owner/new_repo", MarcoButterflyNet.configuration.full_repo_name
    assert MarcoButterflyNet.configuration.github_configured?
  end

  test "partial runtime configuration changes preserve other values" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
      config.repo_path = "/path/to/repo"
    end

    # Only change one value
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "new_token"
    end

    # Verify other values are preserved
    assert_equal "new_token", MarcoButterflyNet.configuration.github_access_token
    assert_equal "owner", MarcoButterflyNet.configuration.github_repo_owner
    assert_equal "repo", MarcoButterflyNet.configuration.github_repo_name
    assert_equal "/path/to/repo", MarcoButterflyNet.configuration.repo_path
  end

  test "configuration reset clears all runtime changes" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
      config.repo_path = "/path/to/repo"
    end

    # Reset configuration
    MarcoButterflyNet.reset_configuration!

    # Verify all values are cleared
    assert_nil MarcoButterflyNet.configuration.github_access_token
    assert_nil MarcoButterflyNet.configuration.github_repo_owner
    assert_nil MarcoButterflyNet.configuration.github_repo_name
    assert_nil MarcoButterflyNet.configuration.repo_path
    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "setting nil values at runtime works correctly" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
    end

    # Set to nil
    MarcoButterflyNet.configure do |config|
      config.github_access_token = nil
    end

    assert_nil MarcoButterflyNet.configuration.github_access_token
    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "setting empty string values at runtime" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = ""
      config.github_repo_owner = ""
      config.github_repo_name = ""
    end

    # Empty strings should make it not configured
    assert_not MarcoButterflyNet.configuration.github_configured?
    assert_nil MarcoButterflyNet.configuration.full_repo_name
  end

  # Invalid GitHub credentials
  test "github_configured? returns false with blank access token" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "   "
      config.github_repo_owner = "owner"
      config.github_repo_name = "repo"
    end

    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false with blank repo owner" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "   "
      config.github_repo_name = "repo"
    end

    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "github_configured? returns false with blank repo name" do
    MarcoButterflyNet.configure do |config|
      config.github_access_token = "token"
      config.github_repo_owner = "owner"
      config.github_repo_name = "   "
    end

    assert_not MarcoButterflyNet.configuration.github_configured?
  end

  test "full_repo_name returns nil with blank owner" do
    MarcoButterflyNet.configure do |config|
      config.github_repo_owner = "   "
      config.github_repo_name = "repo"
    end

    assert_nil MarcoButterflyNet.configuration.full_repo_name
  end

  test "full_repo_name returns nil with blank name" do
    MarcoButterflyNet.configure do |config|
      config.github_repo_owner = "owner"
      config.github_repo_name = "   "
    end

    assert_nil MarcoButterflyNet.configuration.full_repo_name
  end
end
