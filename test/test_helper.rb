ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Require everything in the app/services directory
Dir[Rails.root.join('app/services/**/*.rb')].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Configure the test NoSQL test tables and ensure that they have been initialized
    # -----------------------------------------------------------------------------------
    ENV['NOSQL_DMPS_TABLE'] = 'dmspTest'
    ENV['NOSQL_TYPEAHEADS_TABLE'] = 'typeaheadsTest'
  end
end
