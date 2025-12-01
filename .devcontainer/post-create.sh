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
bin/rails db:create db:migrate
cd ../..

# Run tests to verify setup
echo "🧪 Running tests..."
bundle exec rake test

echo "✅ Development environment ready!"
echo ""
echo "To run the dummy app:"
echo "  cd test/dummy"
echo "  bin/rails server"
echo ""
echo "To run tests:"
echo "  bundle exec rake test"
echo ""
