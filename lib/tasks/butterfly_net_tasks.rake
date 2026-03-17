namespace :butterfly_net do
  namespace :tailwindcss do
    desc "Build Tailwind CSS for ButterflyNet engine"
    task :build do
      require "tailwindcss/ruby"

      gem_root = File.expand_path("../..", __dir__)
      input_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/tailwind.css")
      output_file = File.join(gem_root, "app/assets/stylesheets/butterfly_net/application.css")

      command = [
        Tailwindcss::Ruby.executable,
        "-i", input_file,
        "-o", output_file,
        "--minify"
      ]

      puts "Building ButterflyNet Tailwind CSS..."
      system(*command) || raise("Tailwind CSS build failed")
      puts "Tailwind CSS built successfully!"
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
