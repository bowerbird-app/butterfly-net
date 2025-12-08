# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Start SimpleCov for coverage reporting
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/db/"
    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Jobs", "app/jobs"
    add_group "Services", "lib/marco_butterfly_net/services"
    add_group "Middleware", "lib/marco_butterfly_net/middleware"
  end
end

require_relative "dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("dummy/db/migrate", __dir__) ]
# ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "minitest/mock"

# Eagerly load lib files for coverage tracking
if ENV["COVERAGE"]
  # Explicitly require lib files so SimpleCov can track them
  require_relative "../lib/marco_butterfly_net"
  require_relative "../lib/marco_butterfly_net/version"
  require_relative "../lib/marco_butterfly_net/configuration"
  require_relative "../lib/marco_butterfly_net/engine"
  require_relative "../lib/marco_butterfly_net/middleware/exception_catcher"
  require_relative "../lib/marco_butterfly_net/services/analytics"
  require_relative "../lib/marco_butterfly_net/services/git_blame"
  require_relative "../lib/marco_butterfly_net/services/github_issue_creator"
end

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end
