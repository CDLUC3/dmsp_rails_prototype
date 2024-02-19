# frozen_string_literal: true

require "test_helper"

require "minitest/mock"
require 'ostruct'

module Nosql
  class DynamodbAdapterTest < ActiveSupport::TestCase

    setup do
      ENV['RAILS_HOST'] = 'http://localhost:3001'
      ENV['DOI_BASE_DOMAIN'] = 'localhost:3001'
      ENV['DOI_SHOULDER'] = '99.88888/7Z.'

      # The table name and nosql_init_args are defined in the `test/test_helper.rb`
      @table = ENV['NOSQL_DMPS_TABLE']
      @instance = DynamodbAdapter.new(**{ table: @table })

      @pk_prefix = "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}/"
      @sk_prefix = DynamodbDmpItem::SORT_KEY_DMP_PREFIX
    end

    teardown do
      # Clear the database
      @instance.send(:purge_database)
    end

    # Add a test record to the NoSQL db
    def add_test_record(item:)
      NOSQL_CONNECTION_POOL.with do |client|
        client.put_item({ table_name: @table, item:, return_consumed_capacity: 'NONE' })
      end
    end

    # Tests for `initialize(**args)`
    # -----------------------------------------------------------------------------------------
    test 'initialization raises an error when a :table is not provided' do
      assert_raises( Nosql::NosqlError) { DynamodbAdapter.new }
    end

    test 'initialization is successful' do
      adapter = DynamodbAdapter.new(**{ table: @table })
      assert_equal @table, adapter.table
      assert_equal false, adapter.debug
    end

    # Tests for the `exists?(key:)`
    # -----------------------------------------------------------------------------------------
    test ':exists? returns false if Dynamo did not find an item matching the :key' do
      assert_not @instance.exists?(key: { PK: "#{@pk_prefix}DynamodbAdapter", SK: 'exists?' })
    end

    test ':exists? returns true if Dynamo found the item matching the :key' do
      item = JSON.parse({ PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}exists?", metadata: 'Testing' }.to_json)
      add_test_record(item:)
      assert @instance.exists?(key: { PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}exists?" })
    end

    # Tests for the `get(key:, **args)`
    # -----------------------------------------------------------------------------------------
    test ':get raises an error if :key is not a Hash' do
      assert_raises( Nosql::NosqlError) { @instance.get(key: 123) }
    end

    test ':get returns the record' do
      item = JSON.parse({ PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}get", test_data: { 'Testing': 'Retrieval' } }.to_json)
      add_test_record(item:)
      resp = @instance.get(key: { PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}get" })

      assert_equal({ partition_key: "#{@pk_prefix}DynamodbAdapter", sort_key: "#{@sk_prefix}get" }, resp.key)
      assert_equal(JSON.parse({ test_data: { 'Testing': 'Retrieval' } }.to_json), resp.metadata)
    end

    test ':get returns only the parts we specify in :projection_expression' do
      item = JSON.parse({ PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}get", metadata: { 'Testing': 'Retrieval' } }.to_json)
      add_test_record(item:)
      resp = @instance.get(key: { PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}get" }, **{ projection_expression: 'PK' })

      expected = { partition_key: "#{@pk_prefix}DynamodbAdapter", sort_key: DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION }
      assert_equal(expected, resp.key)
      assert_equal({}, resp.metadata)
    end

    # Tests for the `put(item:)`
    # -----------------------------------------------------------------------------------------
    test ':put raises an error if :key is not a DynamodbDmpItem' do
      assert_raises( Nosql::NosqlError) { @instance.put(item: { PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}put" }) }
    end

    test ':put creates a new record' do
      json = JSON.parse({ PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}put", test_data: { 'Testing': 'Creation' } }.to_json)
      item = DynamodbDmpItem.new(**json.merge({ adapter: @instance }))
      assert @instance.put(item:)
      resp = @instance.get(key: { PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}put" })

      assert_equal({ partition_key: "#{@pk_prefix}DynamodbAdapter", sort_key: "#{@sk_prefix}put" }, resp.key)
      assert_equal(JSON.parse({ 'Testing': 'Creation' }.to_json), resp.metadata['test_data'])
      assert_equal([], resp.versions)
      assert_not_nil resp.metadata['created']
      assert_not_nil resp.metadata['modified']
    end

    test ':put updates an existing record' do
      json = JSON.parse({ PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}put", test_data: { 'Testing': 'Creation' } }.to_json)
      add_test_record(item: json)
      json['test_data'] = { 'Testing': 'Update' }
      json['foo'] = 'bar'
      item = DynamodbDmpItem.new(**json.merge({ adapter: @instance }))
      assert @instance.put(item:)
      resp = @instance.get(key: { PK: "#{@pk_prefix}DynamodbAdapter", SK: "#{@sk_prefix}put" })

      expected = { partition_key: "#{@pk_prefix}DynamodbAdapter", sort_key: "#{@sk_prefix}put" }
      assert_equal(expected, resp.key)
      assert_equal(JSON.parse({ 'Testing': 'Update' }.to_json), resp.metadata['test_data'])
      assert_equal('bar', resp.metadata['foo'])
      assert_equal([], resp.versions)
      assert_not_nil resp.metadata['created']
      assert_not_nil resp.metadata['modified']
    end

    # Tests for the `delete(key:)`
    # -----------------------------------------------------------------------------------------
    test ':delete raises an error if :key is not a Hash' do
      assert_raises( Nosql::NosqlError) { @instance.delete(key: 123) }
    end

    test ':delete destroys the item' do
      key = { PK: "#{@pk_prefix}DynamodbAdapter", SK: 'delete' }
      add_test_record(item: key)
      assert @instance.delete(key:)
      resp = @instance.get(key:)
      assert_nil resp
    end

    test ':delete only deletes a single item' do
      delete_key = { PK: "#{@pk_prefix}DynamodbAdapter", SK: 'delete' }
      dont_delete_key = { PK: "#{@pk_prefix}DynamodbAdapter", SK: 'nope' }
      add_test_record(item: delete_key)
      add_test_record(item: dont_delete_key)
      assert @instance.delete(key: delete_key)
      resp = @instance.get(key: delete_key)
      assert_nil resp
      resp = @instance.get(key: dont_delete_key)
      assert_not_nil resp
    end
  end
end
