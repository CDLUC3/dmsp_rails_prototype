# frozen_string_literal: true

require "test_helper"

module Nosql
  class DynamodbAdapterTest < ActiveSupport::TestCase

    test 'We were unable to initialize a local database for dev/test' do
      instance = DynamodbAdapter.new
      # When the client_pool has not been initialized
      instance.client_pool.nil?
      assert_not instance.send(:initialize_database)
    end

    test 'We are able to initialize a local database for dev/test' do
      instance = DynamodbAdapter.new
      assert instance.send(:initialize_database)
    end
  end
end
