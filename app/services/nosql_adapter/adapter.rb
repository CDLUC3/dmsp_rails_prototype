# frozen_string_literal: true

module NosqlAdapter
  class NoSqlAdapterError < StandardError; end

  # Singleton! Client adapter for the DynamoDB NoSQL table
  class Adapter
    MSG_MISSING_TABLE = 'No Dynamo Table defined! :table should be defined in the initializer!'.freeze
    MSG_NOSQL_ERROR = 'NoSQL Error - %{msg}'.freeze
    MSG_UNABLE_TO_CONNECT = 'Unable to establish a connection to the NoSQL table %{table}'.freeze

    attr_accessor :client_pool, :table, :debug

    # Initialize the DynamoDB Client
    #
    # @param [Hash] args The arguments you want to use to initialize the adapter
    # @option args [String] :table The table name
    # @raise [NoSqlAdapterError] When a fatal error occurs
    def initialize(**args)
      raise NoSqlAdapterError, _handle_error(msg: MSG_MISSING_TABLE) if args[:table].nil?
      @debug = Rails.logger.level == :debug
      @table = args[:table]
    end

    # Check to see if the Partion+Sort key exists. This should attempt to just return
    # the key instead of the entire record for speed and cost savings
    #
    # @param [Hash] key The key we want to check for (format varies by NoSQL database engine)
    # @return [boolean] Whether or not the key exists in the NoSQL database
    # @raise [NoSqlAdapterError] When a fatal error occurs
    def exists?(key:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Fetch a specific record
    #
    # @param [Hash] key The key we want to check for (format varies by NoSQL database engine)
    # @param [Hash] args Arguments that will be passed on to the connection/client
    # @return [NosqlAdapter::Item] The item (or nil)
    # @raise [NoSqlAdapterError] When a fatal error occurs
    def get(key:, args:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Search for records.
    #
    # @param args [Hash] Arguments that will be passed on to the connection/client
    # @return [Array] an array of [NosqlAdapter::Item] (or an empty array)
    # @raise [NoSqlAdapterError] When a fatal error occurs
    def query(args:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Create/Update a record
    #
    # @param [NosqlAdapter::Item] item The item you want to create/update
    # @return [boolean] Whether or not the action was successful
    # @raise [NoSqlAdapterError] When a fatal error occurs
    def put(item:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Delete a record
    #
    # @param [Hash] key The key we want to check for (format varies by NoSQL database engine)
    # @return [boolean] Whether or not the action was successful
    # @raise [NoSqlAdapterError] When a fatal error occurs
    def delete(key:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    private

    # ---------------------------------------------------------------------------------
    # Functions applicable to the local Docker dev environment only!
    # ---------------------------------------------------------------------------------
    # Creates the NoSQL database/table. This is invoked via the `rails nosql:prepare_local`
    # task which is run from within the `bin/docker-entrypoint` script. It is not meant to
    # be run anywhere else (hence placing it her in the `private` methods)
    #
    # @return [boolean] Whether or not the action was successful
    # @raise [NoSqlItemError] When not in the local Docker development environment
    def initialize_database
      raise NoSqlItemError, MSG_NO_TABLE_CREATE unless Rails.env.docker?
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Placing this in the private section because scans can be expensive in some NoSQL
    # environments and not encouraged, but necessary in certain scenarios. This is
    # invoked via the `rails nosql:purge_local` task.
    #
    # @raise [NoSqlItemError] When not in the local Docker development environment
    def purge_database
      raise NoSqlItemError, MSG_NO_TABLE_PURGE unless Rails.env.docker?
      raise NotImplementedError, "Subclasses must implement this method"
  end
end
