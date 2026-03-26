# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Start SimpleCov for coverage reporting BEFORE any code is loaded
# This ensures SimpleCov can track all code from the moment it's loaded
# Note: SimpleCov may have already been started in Rakefile when running via rake tasks,
# but calling start again is safe and won't reset coverage tracking
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/db/"
    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Jobs", "app/jobs"
    add_group "Services", "lib/butterfly_net/services"
    add_group "Middleware", "lib/butterfly_net/middleware"
  end
end

dummy_app = ENV.fetch("DUMMY_APP", "dummy")
require File.expand_path("#{dummy_app}/config/environment", __dir__)
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("#{dummy_app}/db/migrate", __dir__) ]
# ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Explicitly require the main gem file using require_relative to ensure all lib files
# are loaded and tracked by SimpleCov. The main file will require all its dependencies.
# Using require_relative instead of relying on autoloading ensures consistent code
# loading and better coverage tracking.
require_relative "../lib/butterfly_net"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end
