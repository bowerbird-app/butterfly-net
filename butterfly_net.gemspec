require_relative "lib/butterfly_net/version"

Gem::Specification.new do |spec|
  spec.name        = "butterfly_net"
  spec.version     = ButterflyNet::VERSION
  spec.authors     = [ "ButterflyNet Contributors" ]
  spec.email       = [ "marco@butterfly.net" ]
  spec.homepage    = "https://github.com/bowerbird-app/marco-butterfly-net"
  spec.summary     = "Self-hosted error tracking dashboard for Rails applications."
  spec.description = "ButterflyNet is a mountable Rails engine that provides a self-hosted error tracking dashboard with Rack middleware for exception interception, user tracking, git blame integration, and GitHub issue creation."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/marco-butterfly-net"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/marco-butterfly-net/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", ">= 8.1.1"
  spec.add_dependency "octokit", "~> 10.0"
  spec.add_dependency "faraday-retry"
  spec.add_dependency "tailwindcss-ruby", "~> 4.0"
  spec.add_dependency "pagy", "~> 9.0"
end
