namespace :marco_butterfly_net do
  namespace :tailwindcss do
    desc "Build Tailwind CSS for MarcoButterflyNet engine"
    task :build do
      require "tailwindcss/ruby"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/marco_butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/marco_butterfly_net/application.css")

      command = [
        Tailwindcss::Ruby.executable,
        "-i", input_file,
        "-o", output_file,
        "--minify"
      ]

      puts "Building MarcoButterflyNet Tailwind CSS..."
      system(*command) || raise("Tailwind CSS build failed")
      puts "Tailwind CSS built successfully!"
    end

    desc "Watch and rebuild Tailwind CSS for MarcoButterflyNet engine"
    task :watch do
      require "tailwindcss/ruby"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/marco_butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/marco_butterfly_net/application.css")

      command = [
        Tailwindcss::Ruby.executable,
        "-i", input_file,
        "-o", output_file,
        "--watch"
      ]

      puts "Watching MarcoButterflyNet Tailwind CSS for changes..."
      system(*command)
    end
  end
end
