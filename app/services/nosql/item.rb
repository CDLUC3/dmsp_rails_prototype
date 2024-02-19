# frozen_string_literal: true

module Nosql
  class ItemError < StandardError; end

  # A NoSQL item/record
  class Item
    MSG_NO_RAILS_HOST = 'no ENV[\'RAILS_HOST\'] defined!'.freeze

    attr_reader :adapter, :key, :errors

    # Generic initializer. The initializer of the classes that inherit from this class
    # should call `super(**args)` first and then parse the :args to define the contents
    #
    # The :args may contain a :dmp_id entry that conforms to the RDA Common Standard JSON
    # (e.g. `{ "type": "doi", "identifier": "foo" }`) which should be used to set the @key
    # and @dmp_id.
    #
    # If no :PK or :dmp_id are provided in the :args, then the subclass should generate
    # a new @key and @dmp_id.
    #
    # It is also possible for the :args to contain the :key information if this is called
    # from a function that queries the NoSQL database. If that is the case, it should be
    # used to set the @key and @dmp_id
    #
    # The subclass is also responsible for mapping the :args entries to the @versions Array
    # which should contain a sorted (descending) list of timestamps (typically based on the
    # record's modification date).
    #
    # All other entries in the :args Hash should be mapped onto the @metadata Hash
    def initialize(**args)
      raise ItemError, MSG_NO_RAILS_HOST if ENV['RAILS_HOST'].nil?

      @adapter = args[:adapter]
      raise Nosql::ItemError, 'An adapter must be defined' unless @adapter.is_a?(Nosql::Adapter)

      @errors = []
      @key = { partition_key: '', sort_key: '' }

      # Parse the incoming args and map them to the appropriate attributes
      _from_hash(hash: args)
    end

    # Convert the NoSQL item into a JSON record for the NoSQL database
    #
    # @return [Hash] The item represented as JSON Hash (with all the NoSQL stuff)
    def to_nosql_hash
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Convert this object to the RDA Common Standard JSON format for use in the UI or API
    #
    # @return [Hash] This Item represented as JSON Hash (without all of the NoSQL specific stuff)
    def to_json
      raise NotImplementedError, "Subclasses must implement this method"
    end

    private

    # Convert the raw NoSQL record into the attributes for this Item
    #
    # @param [Hash] The NoSQL record as a Hash
    def _from_hash(hash:)
      raise NotImplementedError, "Subclasses must implement this method"
    end
  end
end
