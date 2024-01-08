# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.2.2
# FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base
FROM public.ecr.aws/docker/library/ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Setup Bundler environment variables
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

# Throw-away build stage to reduce size of final image
FROM base as build

RUN apt-get update -qq && \
    apt-get install -y build-essential build-essential git libvips pkg-config default-libmysqlclient-dev

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq-dev libvips default-libmysqlclient-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp config
USER rails:rails

# Build a discardable master.key and credentials.yml.enc file for docker deployment
RUN rm -rf config/credentials.yml.enc && \
    rm -rf config/master.key && \
    EDITOR=nano bundle exec rails credentials:edit

# Entrypoint prepares the database and fetches any necessary SSM params.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# The Docker command is handled by the docker-compose file
