ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Configure the test NoSQL tables
    # --------------------------------
    ENV['NOSQL_DMPS_TABLE'] = 'dmpsTest'
    ENV['NOSQL_TYPEAHEADS_TABLE'] = 'typeaheadsTest'
  end
end
