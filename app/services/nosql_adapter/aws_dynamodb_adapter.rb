# frozen_string_literal: true

require 'aws-sdk-dynamodb'

module NosqlAdapter
  # Singleton! Client adapter for the DynamoDB NoSQL table
  class AwsDynamodbAdapter < Adapter
    MSG_INVALID_ARGS = 'Invalid DynamoDB args. Expecting Hash!'.freeze
    MSG_INVALID_ITEM = 'Invalid item. Expecting a NosqlItem!'.freeze
    MSG_INVALID_JSON = 'Invalid JSON payload. Expecting Hash!'.freeze
    MSG_INVALID_KEY = 'Invalid key specified. Expecting Hash containing `PK` and `SK`'.freeze
    MSG_NO_TABLE_CREATE = 'Cannot create a DynamoDB Table outside the local Docker dev env!'.freeze
    MSG_NO_TABLE_PURGE = 'Cannot purge a DynamoDB Table outside the local Docker dev env!'.freeze
    MSG_NO_RESPONSE_ITEMS = 'AwsDynamodbAdapter `_response_to_items` but no items were found'.freeze

    # Initialize the DynamoDB Client
    def initialize(**args)
      super(**args)

      size = args.fetch(:size, 5)
      timeout = args.fetch(timeout, 5)
      conn_args = args.fetch(:connection, {})
      @client_pool = ConnectionPool.new(size:, timeout:) do
        Aws::DynamoDB::Client.new(conn_args)
      end
      Rails.logger.info("Connections established to DynamoDB table: #{@table}")
    rescue Aws::Errors::ServiceError => e
      raise NoSqlAdapterError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Check to see if the Partion+Sort key exists. This should attempt to just return
    # the key instead of the entire record for speed and cost savings
    #
    # @param key [Hash] The key we want to check for
    # @return [boolean] Whether or not the key exists in the NoSQL database
    def exists?(key:)
      return false unless key.is_a?(Hash) && !key.keys.empty?

      resp = get(key:, projection_expression: 'PK')
      resp.item.is_a?(Hash)
    rescue Aws::Errors::ServiceError => e
      raise NoSqlAdapterError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Fetch a specific record
    #
    # @param key [Hash] The key we want to check for
    # @param args [Hash] Arguments that will be passed on to the connection/client
    # @return [Hash] The item (or nil)
    def get(key:, **args)
      raise NoSqlAdapterError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      opts = {
        table_name: @table,
        key:,
        consistent_read: false,
        return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
      }
      opts[:projection_expression] = args[:projection_expression] unless args[:projection_expression].nil?

      @client_pool.with do |client|
        Rails.logger.info("Fetching DynamoDB record with: `#{opts}`")
        resp = client.get_item(opts)
        Rails.logger.debug(resp)
        _response_to_item(resp:)&.first
      end
    rescue Aws::Errors::ServiceError => e
      raise NoSqlAdapterError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Search for records.
    #
    # @param args [Hash] Arguments that will be passed on to the connection/client
    # @return [Array] an array of [NosqlAdapter::Item] (or an empty array)
    def query(**args)

      # TODO: Swap this out, this is just for testing
      @client_pool.with do |client|
        resp = client.scan({ table_name: @table })
        return _response_to_items(resp:)
      end

      raise NoSqlAdapterError, MSG_INVALID_ARGS unless args.is_a?(Hash) &&
                                                args.fetch(:key_conditions, {}).any?

      hash = {
        table_name: @table,
        key_conditions: args[:key_conditions],
        consistent_read: false,
        return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
      }
      # Look for and add any other filtering or projection args
      %i[index_name filter_expression expression_attribute_values projection_expression
          scan_index_forward].each do |key|
        next if args[key.to_sym].nil?

        hash[key.to_sym] = args[key.to_sym]
      end

      @client_pool.with do |client|
        Rails.logger.info("Query DynamoDB for: #{hash}")
        resp = client.query(hash)
        return [] unless resp.items.any?
        return resp.items if resp.items.first.is_a?(Hash)

        Rails.logger.debug(resp.items)
        _response_to_items(resp:)
      end
    rescue Aws::Errors::ServiceError => e
      raise NoSqlAdapterError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Create/Update a record
    #
    # @param key [Hash] The key we want to check for
    # @param item [NosqlAdapter::Item] The item you want to create/update
    # @return [boolean] Whether or not the action was successful
    def put(key:, item:)
      raise NoSqlAdapterError, MSG_INVALID_ITEM unless item.is_a?(NosqlAdapter::AwsDynamodbItem)

      @client_pool.with do |client|
        Rails.logger.info("DynamoDB Put item: #{item.key}")
        client.put_item(
          {
            table_name: @table,
            item: item.to_nosql_hash,
            return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
          }
        )
      end
      # TODO: How do we test for success?
      true
    rescue Aws::Errors::ServiceError => e
      raise NoSqlAdapterError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Delete a record
    #
    # @param key [Hash] The key we want to check for
    # @return [boolean] Whether or not the action was successful
    def delete(key:)
      raise NoSqlAdapterError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      @client_pool.with do |client|
        Rails.logger.info("DynamoDB Delete item: #{key}")
        client.delete_item({ table_name: @table, key: })
      end
      # TODO: How do we test for success?
      true
    rescue Aws::Errors::ServiceError => e
      raise data, _handle_error(msg: e.message, details: e.backtrace)
    end

    private

    # Convert the DynamoDB items into NosqlItems
    def _response_to_items(resp:)
      out = []
      if resp.respond_to?(:item)
        item = resp[:item].is_a?(Array) ? resp[:item].first : resp[:item]
        out = [AwsDynamodbItem.new(**item)]

      elsif resp.respond_to?(:items)
        items = resp.items.first.respond_to?(:item) ? resp.items.map(&:item) : resp.items
        out = items.map { |item| AwsDynamodbItem.new(**item) }

      else
        Rails.logger.warn(MSG_NO_RESPONSE_ITEMS)
      end
      out
    end

    # Log the error info and then return the formatted error message
    def _handle_error(msg:, details: nil)
      out = "AwsDynamodbAdapter ERROR -- #{MSG_NOSQL_ERROR % { msg: msg }}"
      Rails.logger.error(out)
      Rails.logger.error(details) unless details.nil?
      out
    end

    # ---------------------------------------------------------------------------------
    # Functions applicable to the local Docker dev environment only!
    # ---------------------------------------------------------------------------------
    # Creates the DynamoDB table. This is invoked via the `rails nosql:prepare` task
    # which is run from within the `bin/docker-entrypoint` script. It is not meant to
    # be run anywhere else (hence placing it her in the `private` methods)
    def initialize_database
      raise NoSqlItemError, MSG_NO_TABLE_CREATE unless Rails.env.docker?

      resp = @client_pool.with do |client|
        puts "Checking to see if the NoSQL table #{@table} exists ..."
        resp = client.describe_table({ table_name: @table })

        # Only create the table if it does not already exist!
        if resp&.table&.creation_date_time.nil?
          puts 'Table does not exist. Creating table ...'
          client.create_table({
            attribute_definitions: [
              { attribute_name: 'PK', attribute_type: 'S' },
              { attribute_name: 'SK', attribute_type: 'S' }
            ],
            key_schema: [
              { attribute_name: 'PK', key_type: 'HASH' },
              { attribute_name: 'SK', key_type: 'RANGE' }
            ],
            provisioned_throughput: {
              read_capacity_units: 5,
              write_capacity_units: 5
            },
            table_name: @table
          })
        else
          puts 'Table already exists.'
        end
      end
    end

    # Placing this in the private section because scans are expensive and not encouraged
    # but necessary in certain scenarios.
    def purge_database
      raise NoSqlItemError, MSG_NO_TABLE_PURGE unless Rails.env.docker?

      puts 'Gathering DMP ID records from the local DyanmoDB'
      @client_pool.with do |client|
        resp = client.scan({ table_name: @table })
        dmps = resp.items.first.respond_to?(:item) ? resp.items.map(&:item) : resp.items
        dmps.each do |dmp|
          puts "    Purging DMP ID: #{dmp['PK']}"
          delete(key: { 'PK': dmp['PK'], 'SK': dmp['SK'] })
        end
      end
    end
  end
end
