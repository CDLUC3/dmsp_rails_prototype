source "https://rubygems.org"

ruby "3.2.2"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.2"

# Use GitHub's Trilogy adapter for MySQL
gem "trilogy"
# gem "activerecord-trilogy-adapter"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

# Generic connection pooling for Ruby.
# MongoDB has its own connection pool. ActiveRecord has its own connection pool. This is a
# generic connection pool that can be used with anything, e.g. Redis, Dalli etc.
#   https://github.com/mperham/connection_pool
gem 'connection_pool'

# Gem to help make HTTP calls easier: https://github.com/jnunemaker/httparty
gem 'httparty'

# This library is intended to provide Ruby with an interface for validating JSON objects against a JSON schema
# conforming to JSON Schema Draft 6: https://github.com/voxpupuli/json-schema
gem 'json-schema'

group :aws do
  # Support for interaction with AWS resources
  gem 'aws-sdk-secretsmanager'

  # DynamoDB adapter
  gem 'aws-sdk-dynamodb'

  # S3 Bcuket adapter
  gem 'aws-sdk-s3'

  # SSM parameter store adapter
  gem 'aws-sdk-ssm'
end

group :test do
  # Gems required only when running tests

end

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
