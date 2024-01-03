# frozen_string_literal: true

module NosqlAdapter
  class NoSqlItemError < StandardError; end

  # A NoSQL item/record
  class Item
    MSG_NO_DOI_BASE_URL = 'No ENV[\'DOI_BASE_URL\'] defined!'.freeze
    MSG_NO_DOI_SHOULDER = 'No ENV[\'DOI_SHOULDER\'] defined!'.freeze
    MSG_NO_DMP_ID_FOR_NEW = 'No DMP IDs allowed when creating a new item!'.freeze
    MSG_UNABLE_TO_ACQUIRE_NEW_ID = 'Unable to acquire a new DMP ID after 10 attempts!'.freeze

    attr_reader :doi_shoulder, :doi_base_url, :key, :dmp_id, :versions, :errors
    attr_accessor :metadata

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
      raise NoSqlItemError, MSG_NO_DMP_ID_FOR_NEW unless args[:dmp_id].nil?

      @doi_base_url = ENV['DOI_BASE_URL']
      @doi_shoulder = ENV['DOI_SHOULDER']
      raise NoSqlItemError, MSG_NO_DOI_BASE_URL if @doi_base_url.empty?
      raise NoSqlItemError, MSG_NO_DOI_SHOULDER if @doi_shoulder.empty?

      @versions = []
      @metadata = {}
      @errors = []

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
