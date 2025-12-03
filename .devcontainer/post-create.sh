#!/bin/bash

set -e

echo "🚀 Setting up MarcoButterflyNet development environment..."

# Install Ruby dependencies
echo "📦 Installing Ruby gems..."
bundle install

# Set up the test dummy app database
echo "🗄️  Setting up test database..."
cd test/dummy
bin/rails marco_butterfly_net:install:migrations
bin/rails db:migrate
bin/rails db:seed

echo "✅ Development environment ready!"
echo "🌐 Rails server will start automatically via postStartCommand"
