namespace :butterfly_net do
  namespace :tailwindcss do
    def resolved_tailwind_input(input_file)
      flat_pack_spec = Gem.loaded_specs["flat_pack"]
      raise "flat_pack gem is not installed" unless flat_pack_spec

      File.read(input_file).gsub(
        "__FLAT_PACK_COMPONENTS__",
        File.join(flat_pack_spec.full_gem_path, "app/components/**/*.{rb,erb}")
      )
    end

    desc "Build Tailwind CSS for ButterflyNet engine"
    task :build do
      require "tailwindcss/ruby"
      require "tempfile"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/application.css")

      puts "Building ButterflyNet Tailwind CSS..."
      Tempfile.create(["butterfly_net_tailwind", ".css"], File.dirname(input_file)) do |resolved_input|
        resolved_input.write(resolved_tailwind_input(input_file))
        resolved_input.flush

        command = [
          Tailwindcss::Ruby.executable,
          "-i", resolved_input.path,
          "-o", output_file,
          "--minify"
        ]

        system(*command) || raise("Tailwind CSS build failed")
      end

      puts "Tailwind CSS built successfully!"
    end

    desc "Watch and rebuild Tailwind CSS for ButterflyNet engine"
    task :watch do
      require "tailwindcss/ruby"
      require "tempfile"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/application.css")

      puts "Watching ButterflyNet Tailwind CSS for changes..."

      Tempfile.create(["butterfly_net_tailwind", ".css"], File.dirname(input_file)) do |resolved_input|
        resolved_input.write(resolved_tailwind_input(input_file))
        resolved_input.flush

        command = [
          Tailwindcss::Ruby.executable,
          "-i", resolved_input.path,
          "-o", output_file,
          "--watch"
        ]

        system(*command)
      end
    end
  end
end
