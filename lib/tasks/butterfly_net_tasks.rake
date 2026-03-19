namespace :butterfly_net do
  namespace :tailwindcss do
    desc "Build Tailwind CSS for ButterflyNet engine"
    task :build do
      require "tailwindcss/ruby"
      require "tempfile"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/application.css")

      # Resolve @import "flat_pack/variables.css" and @source for FlatPack
      # components at build time, since the standalone Tailwind binary cannot
      # resolve gem asset paths from the temp file location.
      css_content = File.read(input_file)
      begin
        flatpack_spec = Gem::Specification.find_by_name("flat_pack")
        flatpack_variables = File.join(flatpack_spec.gem_dir, "app/assets/stylesheets/flat_pack/variables.css")
        flatpack_components = File.join(flatpack_spec.gem_dir, "app/components")

        # Replace @import "flat_pack/variables.css" with the actual file content
        # so the standalone Tailwind binary can process it without gem path resolution.
        if File.exist?(flatpack_variables)
          variables_content = File.read(flatpack_variables)
          css_content = css_content.gsub('@import "flat_pack/variables.css";', variables_content)
        end

        # Append @source for FlatPack component files so Tailwind scans them for class usage.
        css_content += "\n/* FlatPack components - scanned for Tailwind class usage */\n"
        css_content += "@source \"#{flatpack_components}\";\n"
      rescue Gem::MissingSpecError
        # flat_pack not installed yet, skip dynamic injection
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
