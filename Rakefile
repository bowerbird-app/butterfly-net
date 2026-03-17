require "bundler/setup"

# Start SimpleCov before loading Rails if COVERAGE is set
# This ensures SimpleCov can track all code from the moment it's loaded
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

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

require "bundler/gem_tasks"

task default: "app:test"
