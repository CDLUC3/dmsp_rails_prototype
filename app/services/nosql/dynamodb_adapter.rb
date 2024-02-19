# frozen_string_literal: true

require 'aws-sdk-dynamodb'

module Nosql
  # Singleton! Client adapter for the DynamoDB NoSQL table
  class DynamodbAdapter < Adapter
    MSG_INVALID_ARGS = 'Invalid DynamoDB args. Expecting Hash!'.freeze
    MSG_INVALID_ITEM = 'Invalid item. Expecting a NosqlItem!'.freeze
    MSG_INVALID_JSON = 'Invalid JSON payload. Expecting Hash!'.freeze
    MSG_INVALID_KEY = 'Invalid key specified. Expecting Hash containing `PK` and `SK`'.freeze
    MSG_NO_TABLE_CREATE = 'Cannot create a DynamoDB Table outside the local Docker dev env!'.freeze
    MSG_NO_TABLE_PURGE = 'Cannot purge a DynamoDB Table outside the local Docker dev env!'.freeze
    MSG_NO_RESPONSE_ITEMS = 'DynamodbAdapter `_response_to_items` but no items were found'.freeze

    attr_accessor :region, :host, :port, :access_key, :access_secret

    # Initialize the DynamoDB Client
    #
    # @param [Hash] args The arguments you want to use to initialize the adapter
    # @option args [String] :table The table name
    # @raise [NosqlError] When an Aws::Errors::ServiceError occurs
    def initialize(**args)
      super(**args)
    end

    # Check to see if the Partion+Sort key exists. This should attempt to just return
    # the key instead of the entire record for speed and cost savings
    #
    # @param [Hash] key The key we want to check for
    # @option key [String] :PK The partition key (e.g. 'DMP#doi.org/11.22222/AB12CD34')
    # @option key [String] :SK The sort key (e.g. 'VERSION#latest')
    # @return [boolean] Whether or not the key exists in the NoSQL database
    # @raise [NosqlError] When an Aws::Errors::ServiceError occurs
    def exists?(key:)
      return false unless key.is_a?(Hash) && !key.keys.empty?

      resp = get(key:, projection_expression: 'PK')
      resp.is_a?(Nosql::DynamodbDmpItem)
    rescue Aws::Errors::ServiceError => e
      raise NosqlError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Fetch a specific record
    #
    # @param [Hash] key The key we want to check for
    # @option key [String] :PK The partition key (e.g. 'DMP#doi.org/11.22222/AB12CD34')
    # @option key [String] :SK The sort key (e.g. 'VERSION#latest')
    # @param [Hash] args Arguments that will be passed on to the connection/client
    # @return [Hash] The item (or nil)
    # @raise [NosqlError] When an Aws::Errors::ServiceError occurs
    def get(key:, **args)
      raise NosqlError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      opts = {
        table_name: @table,
        key:,
        consistent_read: false,
        return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
      }
      opts[:projection_expression] = args[:projection_expression] unless args[:projection_expression].nil?

      NOSQL_CONNECTION_POOL.with do |client|
        Rails.logger.info("Fetching DynamoDB record with: `#{opts}`")
        resp = client.get_item(opts)
        Rails.logger.debug(resp)
        _response_to_items(resp:)&.first
      end
    rescue Aws::Errors::ServiceError => e
      raise NosqlError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Search for records.
    #
    # @param [Hash] args Arguments that will be passed on to the connection/client
    # @return [Array] an array of [Nosql::Item] (or an empty array)
    # @raise [NosqlError] When an Aws::Errors::ServiceError occurs
    def query(**args)

      # TODO: Swap this out, this is just for testing. We want to use OpenSearch anyway
      NOSQL_CONNECTION_POOL.with do |client|
        resp = client.scan({ table_name: @table })
        return _response_to_items(resp:)
      end

      raise NosqlError, MSG_INVALID_ARGS unless args.is_a?(Hash) &&
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

      NOSQL_CONNECTION_POOL.with do |client|
        Rails.logger.info("Query DynamoDB for: #{hash}")
        resp = client.query(hash)
        return [] unless resp.items.any?
        return resp.items if resp.items.first.is_a?(Hash)

        Rails.logger.debug(resp.items)
        _response_to_items(resp:)
      end
    rescue Aws::Errors::ServiceError => e
      raise NosqlError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Create/Update a record
    #
    # @param [Nosql::Item] item The item you want to create/update
    # @return [boolean] Whether or not the action was successful
    # @raise [NosqlError] When an Aws::Errors::ServiceError occurs
    def put(item:)
      raise NosqlError, MSG_INVALID_ITEM unless item.is_a?(Nosql::DynamodbDmpItem)

      NOSQL_CONNECTION_POOL.with do |client|
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
      raise NosqlError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Delete a record
    #
    # @param [Hash] key The key we want to check for
    # @option key [String] :PK The partition key (e.g. 'DMP#doi.org/11.22222/AB12CD34')
    # @option key [String] :SK The sort key (e.g. 'VERSION#latest')
    # @return [boolean] Whether or not the action was successful
    # @raise [NosqlError] When an Aws::Errors::ServiceError occurs
    def delete(key:)
      raise NosqlError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      NOSQL_CONNECTION_POOL.with do |client|
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
    #
    # @param [Seahorse::Client::Response] resp The response from the Aws::DyanmoDB::Client
    # @return [Array<Nosql::Item>] An array of NoSQL items (e.g. Dmps)
    def _response_to_items(resp:)
      out = []

      if resp.respond_to?(:item) && !resp[:item].nil?
        item = resp[:item].is_a?(Array) ? resp[:item].first : resp[:item]
        out = [DynamodbDmpItem.new(**item.merge({ adapter: self }))]

      elsif resp.respond_to?(:items)
        items = resp.items.first.respond_to?(:item) ? resp.items.map(&:item) : resp.items
        out = items.map { |item| DynamodbDmpItem.new(**item.merge({ adapter: self })) }

      else
        Rails.logger.warn(MSG_NO_RESPONSE_ITEMS)
      end
      out
    end

    # Log the error info and then return the formatted error message
    #
    # @param [String] msg The error message
    # @param [Object] details Anything, but typically a Hash or Array (e.g. `e.backtrace`)
    # @return [String] A formatted version of the error message
    def _handle_error(msg:, details: nil)
      out = "DynamodbDmpAdapter ERROR -- #{MSG_NOSQL_ERROR % { msg: msg }}"
      Rails.logger.error(out)
      Rails.logger.error(details) unless details.nil?
      out
    end

    # Build the DynamoDB database adapter arguments
    def _connection_args(access_key:, access_secret:)
      if Rails.env.development? || Rails.env.test?
        {
          region: @region,
          endpoint: "http://#{[@host, @port].join(':')}",
          credentials: Aws::Credentials.new(access_key, access_secret)
        }
      else
        { region: @region }
      end
    end

    # Placing this in the private section because scans can be expensive in some NoSQL
    # environments and not encouraged, but necessary in certain scenarios. This is
    # invoked via the `rails nosql:purge_local` task.
    #
    # @raise [NosqlItemError] When not in the local Docker development environment
    def purge_database
      raise NosqlItemError, MSG_NO_TABLE_PURGE unless Rails.env.development? || Rails.env.test?

      Rails.logger.info 'Gathering records from the local DyanmoDB'
      NOSQL_CONNECTION_POOL.with do |client|
        resp = client.scan({ table_name: @table })
        recs = resp.items.first.respond_to?(:item) ? resp.items.map(&:item) : resp.items
        recs.each do |rec|
          Rails.logger.debug "    Purging: PK: #{rec['PK']}, SK: #{rec['SK']}"
          delete(key: { 'PK': rec['PK'], 'SK': rec['SK'] })
        end
        true
      end
    end
  end
end
