#!/bin/bash

set -e

echo "🚀 Setting up ButterflyNet development environment..."

# Install Ruby dependencies
echo "📦 Installing Ruby gems..."
bundle install

# Set up the test dummy app database
echo "🗄️  Setting up test database..."
cd test/dummy
bin/rails butterfly_net:install:migrations
bin/rails db:migrate
bin/rails db:seed
cd ../..

# Build Tailwind CSS
echo "🎨 Building Tailwind CSS..."
bundle exec rake app:butterfly_net:tailwindcss:build

# Start Tailwind watcher in background
echo "👀 Starting Tailwind CSS watcher..."
nohup ./bin/tailwind-watch > /tmp/tailwind-watch.log 2>&1 &
echo $! > /tmp/tailwind-watch.pid

echo "✅ Development environment ready!"
echo "🌐 Rails server will start automatically via postStartCommand"
echo "📝 Tailwind CSS is being watched for changes (logs: /tmp/tailwind-watch.log)"
