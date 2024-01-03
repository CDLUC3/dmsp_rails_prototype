# frozen_string_literal: true

module NosqlAdapter
  class NoSqlAdapterError < StandardError; end

  # Singleton! Client adapter for the DynamoDB NoSQL table
  class Adapter
    MSG_MISSING_TABLE = 'No Dynamo Table defined! :table should be defined in the initializer!'.freeze
    MSG_NOSQL_ERROR = 'NoSQL Error - %{msg}'.freeze
    MSG_UNABLE_TO_CONNECT = 'Unable to establish a connection to the NoSQL table %{table}'.freeze

    attr_accessor :client_pool, :table, :debug

    def initialize(**args)
      raise NoSqlAdapterError, _handle_error(msg: MSG_MISSING_TABLE) if args[:table].nil?
      @debug = Rails.logger.level == :debug
      @table = args[:table]
    end

    # Create a new record
    #
    # @return [NosqlAdapter::Item]
    def new_item
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Check to see if the Partion+Sort key exists. This should attempt to just return
    # the key instead of the entire record for speed and cost savings
    #
    # @param key [NosqlAdapter::Key] The key we want to check for
    # @return [boolean] Whether or not the key exists in the NoSQL database
    def exists?(key:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Fetch a specific record
    #
    # @param key [NosqlAdapter::Key] The key we want to check for
    # @param args [Hash] Arguments that will be passed on to the connection/client
    # @return [NosqlAdapter::Item] The item (or nil)
    def get(key:, args:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Search for records.
    #
    # @param args [Hash] Arguments that will be passed on to the connection/client
    # @return [Array] an array of [NosqlAdapter::Item] (or an empty array)
    def query(args:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Create/Update a record
    #
    # @param key [NosqlAdapter::Key] The key we want to check for
    # @param item [NosqlAdapter::Item] The item you want to create/update
    # @return [boolean] Whether or not the action was successful
    def put(key:, hash:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Delete a record
    #
    # @param key [NosqlAdapter::Key] The key we want to check for
    # @return [boolean] Whether or not the action was successful
    def delete(key:)
      raise NotImplementedError, "Subclasses must implement this method"
    end

    private

    # Creates the DynamoDB table. This is invoked via the `rails nosql:prepare` task
    # which is run from within the `bin/docker-entrypoint` script. It is not meant to
    # be run anywhere else (hence placing it her in the `private` methods)
    def initialize_database
      raise NotImplementedError, "Subclasses must implement this method"
    end
  end
end
