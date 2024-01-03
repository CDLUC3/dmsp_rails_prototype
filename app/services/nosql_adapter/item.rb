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
    # should call `super(**args` first and then parse the `args` to define the contents
    # of:
    #  @key      [Hash] - specific to the key requirements of the NoSQL database
    #  @dmp_id   [Hash] - e.g. `{ type: 'doi', identifier: '11.22222/AB12CD34' }`
    #  @versions [Array of UTC timestamps as Strings] - e.g. '2023-12-28T09:13:42+00:00'
    #  @metadata [Hash] - e.g. `{ title: 'My DMP' }`
    #
    # There are 3 scenarios in which the initializer is called:
    #   1: A request to create a new Item (no @key or @dmp_id defined)
    #   2: A fetch by @key from the NoSQL database
    #   3: A fetch by @dmp_id from the NoSQL database
    def initialize(**args)
      raise NoSqlItemError, MSG_NO_DMP_ID_FOR_NEW unless args[:dmp_id].nil?

      @doi_base_url = ENV['DOI_BASE_URL']
      @doi_shoulder = ENV['DOI_SHOULDER']
      raise NoSqlItemError, MSG_NO_DOI_BASE_URL if @doi_base_url.empty?
      raise NoSqlItemError, MSG_NO_DOI_SHOULDER if @doi_shoulder.empty?

      @versions = []
      @metadata = {}
      @errors = []
    end

    class << self
      # Convert the DMP ID and version into a NoSQL key
      #
      # @param dmp_id [String] The DMP ID
      # @param version [String] The version identifier (default: nil)
      # @return [NosqlAdapter::Key] The NoSQL key
      def key_from_dmp_id(dmp_id:, version: nil)
        raise NotImplementedError, "Subclasses must implement this method"
      end

      # Convert the NoSQL key into the DMP ID
      #
      # @param key [NosqlAdapter::Key]
      # @returns [Hash] A hash containing the :dmp_id and :version
      def key_to_dmp_id_and_version(key:)
        raise NotImplementedError, "Subclasses must implement this method"
      end
    end

    # Convert the NoSQL item into a JSON record for the NoSQL database
    #
    # @return [Hash] The item represented as a Hash that is ready for the NoSQL database
    def to_nosql_hash
      raise NotImplementedError, "Subclasses must implement this method"
    end

    private

    class << self
      # Convert the raw NoSQL record into this item
      #
      # @param hash [Hash] The NoSQL record as a Hash
      # @return item [NosqlAdapter::Item] An instance of this class
      def _from_nosql_hash(hash:)
        raise NotImplementedError, "Subclasses must implement this method"
      end
    end

    # Generate a new NoSQL key
    #
    # @return [NosqlAdapter::Key] The
    def _generate_key
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Generate a new DMP ID
    #
    # @return [String] The new DMP ID
    def _generate_dmp_id
      raise NotImplementedError, "Subclasses must implement this method"
    end

    # Return the base URL for a DMP ID
    #
    # @param include_protocol [boolean] Whether or not to include the HTTP protocol (default: false)
    # @return [String]
    def _dmp_id_base_url(include_protocol: false)
      url = ENV.fetch('DOI_BASE_URL', 'http://localhost:3001')
      url = url.gsub(%r{https?://}, '') unless include_protocol
      url&.end_with?('/') ? url : "#{url}/"
    end

  end
end
