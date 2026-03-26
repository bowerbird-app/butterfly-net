# frozen_string_literal: true

module ButterflyNet
  class Configuration
    # GitHub personal access token for API authentication
    attr_accessor :github_access_token

    # GitHub repository owner (e.g., "github" in github/docs)
    attr_accessor :github_repo_owner

    # GitHub repository name (e.g., "docs" in github/docs)
    attr_accessor :github_repo_name

    # Path to the local git repository (defaults to Rails.root)
    attr_accessor :repo_path

    # Host for the ButterflyNet dashboard (e.g., "https://myapp.com")
    # Used to generate links back to the dashboard in GitHub issues.
    attr_accessor :dashboard_host

    # GitHub organisation that owns bowerbird-app dependencies (default: "bowerbird-app").
    # Used to route issues directly to upstream gem repos.
    attr_accessor :bowerbird_org

    # Map of bundler gem names to GitHub repo names under bowerbird_org.
    # e.g. { "flatpack" => "flatpack", "butterfly_net" => "marco-butterfly-net" }
    # When a backtrace line contains a matching gem path the UI will offer
    # a button to file the issue in that upstream repo.
    attr_accessor :bowerbird_gem_repos

    # Environments in which GitHub issue creation is permitted.
    # Defaults to production and staging only — development is excluded
    # to prevent noise from local errors.
    attr_accessor :github_issue_environments

    def initialize
      @github_access_token = nil
      @github_repo_owner = nil
      @github_repo_name = nil
      @repo_path = nil
      @dashboard_host = nil
      @bowerbird_org = "bowerbird-app"
      @bowerbird_gem_repos = {}
      @github_issue_environments = %w[production staging]
    end

    # Returns the full repository name in "owner/repo" format
    def full_repo_name
      return nil unless github_repo_owner.present? && github_repo_name.present?

      "#{github_repo_owner}/#{github_repo_name}"
    end

    # Checks if GitHub integration is properly configured and allowed in the current environment
    def github_configured?
      return false unless github_access_token.present? && github_repo_owner.present? && github_repo_name.present?

      current_env = defined?(Rails) ? Rails.env.to_s : ENV.fetch("RAILS_ENV", "development")
      github_issue_environments.include?(current_env)
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
