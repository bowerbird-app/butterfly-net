require_relative "lib/marco_butterfly_net/version"

Gem::Specification.new do |spec|
  spec.name        = "marco_butterfly_net"
  spec.version     = MarcoButterflyNet::VERSION
  spec.authors     = [ "MarcoButterflyNet Contributors" ]
  spec.email       = [ "marco@butterfly.net" ]
  spec.homepage    = "https://github.com/bowerbird-app/marco-butterfly-net"
  spec.summary     = "Self-hosted error tracking dashboard for Rails applications."
  spec.description = "MarcoButterflyNet is a mountable Rails engine that provides a self-hosted error tracking dashboard with Rack middleware for exception interception."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/marco-butterfly-net"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/marco-butterfly-net/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.1"
end
