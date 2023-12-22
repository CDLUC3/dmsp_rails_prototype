# frozen_string_literal: true

require 'aws-sdk-dynamodb'

module Aws
  class DynamoError < StandardError; end

  # Singleton! Client adapter for the DynamoDB NoSQL table
  class Dynamo
    MSG_INVALID_ARGS = 'Invalid DynamoDB args. Expecting Hash!'
    MSG_INVALID_JSON = 'Invalid JSON payload. Expecting Hash!'
    MSG_INVALID_KEY = 'Invalid key specified. Expecting Hash containing `PK` and `SK`'
    MSG_MISSING_TABLE = 'No Dynamo Table defined! Looking for `ENV[\'NOSQL_TABLE\']`'
    MSG_DYNAMO_ERROR = 'DynamoDB Table Error - %{msg}'
    MSG_UNABLE_TO_CONNECT = 'Unable to establish a connection to DynamoDB table %{table}'

    attr_accessor :client, :table, :debug

    # Initialize the DynamoDB Client
    def initialize(**args)
      @table = args.fetch(:table, ENV.fetch('NOSQL_TABLE', nil))
      raise DynamoError, _handle_error(msg: MSG_MISSING_TABLE) if @table.nil?

      @client = Aws::DynamoDB::Client.new(_connection_configuration(**args))
      raise DynamoError, _handle_error(msg: MSG_UNABLE_TO_CONNECT % { table: @table }) if @client.nil?

      Rails.logger.info("Connection established to DynamoDB table: #{@table}")
      Rails.logger.debug(@client.inspect)

      @debug = Rails.logger.level == :debug
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Check to see if the Partion+Sort key exists
    def exists?(key:)
      return false unless key.is_a?(Hash) && !key.keys.empty?

      resp = get(key:, projection_expression: 'PK')
      resp.item.is_a?(Hash)
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Fetch a record
    def get(key:, **args)
      raise DynamoError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      opts = {
        table_name: @table,
        key:,
        consistent_read: false,
        return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
      }
      opts[:projection_expression] = args[:projection_expression] unless args[:projection_expression].nil?

      Rails.logger.info("Fetching DynamoDB record with: `#{opts}`")
      resp = @client.get_item(opts)
      Rails.logger.debug(resp)
      resp[:item].is_a?(Array) ? resp[:item].first : resp[:item]
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Search for records
    def query(**args)
      raise DynamoError, MSG_INVALID_ARGS unless args.is_a?(Hash) &&
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

      Rails.logger.info("Query DynamoDB for: #{hash}")
      resp = @client.query(hash)
      return [] unless resp.items.any?
      return resp.items if resp.items.first.is_a?(Hash)

      Rails.logger.debug(resp.items)
      resp.items.first.respond_to?(:item) ? resp.items.map(&:item) : resp.items
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Scan the table for records
    def scan(**args)
      raise DynamoError, MSG_INVALID_ARGS unless args.is_a?(Hash) && !args.keys.empty?

      hash = {
        table_name: @table,
        consistent_read: false,
        return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
      }
      # Look for and add any other filtering or projection args
      %i[filter_expression expression_attribute_values projection_expression expression_attribute_names].each do |key|
        next if args[key.to_sym].nil?

        hash[key.to_sym] = args[key.to_sym]
      end

      Rails.logger.info("Scan DynamoDB for: #{hash}")
      resp = @client.scan(hash)
      return [] unless resp.items.any?
      return resp.items if resp.items.first.is_a?(Hash)

      Rails.logger.debug(resp.items)
      resp.items.first.respond_to?(:item) ? resp.items.map(&:item) : resp.items
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Create/Update a record
    def put(key:, json:)
      raise DynamoError, MSG_INVALID_JSON unless json.is_a?(Hash) && !json.keys.empty?
      raise DynamoError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      Rails.logger.info("DynamoDB Put item: #{json.merge(key)}")
      @client.put_item(
        {
          table_name: @table,
          item: json.merge(key),
          return_consumed_capacity: @debug ? 'TOTAL' : 'NONE'
        }
      )
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    # Delete a record
    def delete(key:)
      raise DynamoError, MSG_INVALID_KEY unless key.is_a?(Hash) && !key.keys.empty?

      Rails.logger.info("DynamoDB Delete item: #{key}")
      @client.delete_item({ table_name: @table, key: })
    rescue Aws::Errors::ServiceError => e
      raise DynamoError, _handle_error(msg: e.message, details: e.backtrace)
    end

    private

    def _connection_configuration(**args)
      region = args.fetch(:region, ENV.fetch('AWS_REGION', 'us-west-2'))
      return { region: region } unless Rails.env.docker?

      # We need to pass in the local NoSQL Workbench credentials when in the local Docker env
      {
        credentials: Aws::Credentials.new({
          access_key_id: ENV['DYNAMO_ACCESS_KEY'],
          secret_access_key: ENV['DYNAMO_ACCESS_SECRET']
        })
      }
    end

    # Log the error info and then return the formatted error message
    def _handle_error(msg:, details: nil)
      out = "Aws::Dynamo ERROR -- #{MSG_DYNAMO_ERROR % { msg: msg }}"
      Rails.logger.error(out)
      Rails.logger.error(details) unless details.nil?
      out
    end
  end
end
