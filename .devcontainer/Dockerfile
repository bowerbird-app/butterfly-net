FROM mcr.microsoft.com/devcontainers/ruby:1-3.3-bullseye

# Remove stale Yarn repo whose GPG key is no longer valid, then install packages
RUN rm -f /etc/apt/sources.list.d/yarn.list \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends postgresql-client \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Node.js (for Rails assets)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set up bundle path
ENV BUNDLE_PATH=/usr/local/bundle
