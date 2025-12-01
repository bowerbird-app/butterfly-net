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
end
