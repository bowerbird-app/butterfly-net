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

APP_RAKEFILE = File.expand_path("test/#{ENV.fetch('DUMMY_APP', 'dummy')}/Rakefile", __dir__)
load "rails/tasks/engine.rake"

require "bundler/gem_tasks"
require "flatpack/checker"

namespace :flatpack do
  desc "Scan app/views, app/components, and app/helpers for raw HTML that should be migrated to Flatpack components"
  task :check do
    unless Flatpack::Checker.supported_environment?
      puts Rainbow("flatpack-checker only runs in development and test environments.").yellow
      next
    end

    violations = Flatpack::Checker::Checker.new(root: __dir__).call
    raise SystemExit, 1 if violations.any?
  end

  namespace :install do
    desc "Create a GitHub Actions workflow for flatpack:check when .github/workflows exists"
    task :github_actions do
      Flatpack::Checker::WorkflowInstaller.new(root: __dir__).call
    end
  end
end

task default: "app:test"
