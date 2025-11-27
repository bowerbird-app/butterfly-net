ARG RUBY_VERSION=3.3.6
FROM docker.io/library/ruby:${RUBY_VERSION}-slim

# Install essential packages for Rails development
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libyaml-dev \
    libvips \
    pkg-config \
    postgresql-client \
    nodejs \
    npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set environment for development
ENV RAILS_ENV=development
ENV BUNDLE_PATH=/usr/local/bundle
