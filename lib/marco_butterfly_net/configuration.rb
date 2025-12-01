# frozen_string_literal: true

module MarcoButterflyNet
  class Configuration
    # GitHub personal access token for API authentication
    attr_accessor :github_access_token

    # GitHub repository owner (e.g., "github" in github/docs)
    attr_accessor :github_repo_owner

    # GitHub repository name (e.g., "docs" in github/docs)
    attr_accessor :github_repo_name

    # Path to the local git repository (defaults to Rails.root)
    attr_accessor :repo_path

    def initialize
      @github_access_token = nil
      @github_repo_owner = nil
      @github_repo_name = nil
      @repo_path = nil
    end

    # Returns the full repository name in "owner/repo" format
    def full_repo_name
      return nil unless github_repo_owner && github_repo_name

      "#{github_repo_owner}/#{github_repo_name}"
    end

    # Checks if GitHub integration is properly configured
    def github_configured?
      github_access_token.present? && github_repo_owner.present? && github_repo_name.present?
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
