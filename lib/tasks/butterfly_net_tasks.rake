namespace :butterfly_net do
  namespace :tailwindcss do
    desc "Build Tailwind CSS for ButterflyNet engine"
    task :build do
      require "tailwindcss/ruby"
      require "tempfile"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/application.css")

      # Dynamically append the FlatPack components source path so Tailwind scans them for class usage.
      # variables.css is inlined directly in tailwind.css so no @import injection is needed.
      css_content = File.read(input_file)
      begin
        flatpack_spec = Gem::Specification.find_by_name("flat_pack")
        flatpack_components = File.join(flatpack_spec.gem_dir, "app/components")
        css_content += "\n/* FlatPack components - scanned for Tailwind class usage */\n"
        css_content += "@source \"#{flatpack_components}\";\n"
      rescue Gem::MissingSpecError
        # flat_pack not installed yet, skip dynamic source injection
      end

      tmpfile = Tempfile.new([ "butterfly_net_tailwind", ".css" ])
      begin
        tmpfile.write(css_content)
        tmpfile.flush

        command = [
          Tailwindcss::Ruby.executable,
          "-i", tmpfile.path,
          "-o", output_file,
          "--minify"
        ]

        puts "Building ButterflyNet Tailwind CSS..."
        system(*command) || raise("Tailwind CSS build failed")
        puts "Tailwind CSS built successfully!"
      ensure
        tmpfile.close
        tmpfile.unlink
      end
    end

    desc "Watch and rebuild Tailwind CSS for ButterflyNet engine"
    task :watch do
      require "tailwindcss/ruby"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/application.css")

      command = [
        Tailwindcss::Ruby.executable,
        "-i", input_file,
        "-o", output_file,
        "--watch"
      ]

      puts "Watching ButterflyNet Tailwind CSS for changes..."
      system(*command)
    end
  end
end

