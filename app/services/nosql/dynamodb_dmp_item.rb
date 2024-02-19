# frozen_string_literal: true

require 'securerandom'

module Nosql
  # A NoSQL item/record
  class DynamodbDmpItem < Item
    MSG_NO_DOI_BASE_DOMAIN = 'No ENV[\'DOI_BASE_DOMAIN\'] defined!'.freeze
    MSG_NO_DOI_SHOULDER = 'No ENV[\'DOI_SHOULDER\'] defined!'.freeze
    MSG_NO_DMP_ID_FOR_NEW = 'No DMP IDs allowed when creating a new item!'.freeze
    MSG_UNABLE_TO_ACQUIRE_NEW_ID = 'Unable to acquire a new DMP ID after 10 attempts!'.freeze

    PARTITION_KEY_DMP_PREFIX = 'DMP#'.freeze
    # PARTITION_KEY_DMP_REGEX = %r{DMP#[a-zA-Z0-9\-_.:]+/[a-zA-Z0-9]{2}\.[a-zA-Z0-9./:]+}.freeze

    PROVENANCE_KEY_PREFIX = 'PROVENANCE#'.freeze

    SORT_KEY_DMP_PREFIX = 'VERSION#'.freeze
    # SORT_KEY_DMP_REGEX = /VERSION#\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}/.freeze

    SORT_KEY_DMP_LATEST_VERSION = "#{SORT_KEY_DMP_PREFIX}latest".freeze
    SORT_KEY_DMP_TOMBSTONE_VERSION = "#{SORT_KEY_DMP_PREFIX}tombstone".freeze

    attr_reader :landing_page_url, :extras, :versions, :doi_base_domain, :doi_shoulder
    attr_accessor :metadata, :dmp_id, :modifications

    # Initialize a new NosqlItem with either an RDA Common Standard JSON Hash or a NoSQL
    # JSON Hash.
    #   - If no :PK or :dmp_id is provided, a @key and @dmp_id will be generated
    #   - If a :PK is provided, that :PK will be used as the @key and @dmp_id
    #   - If a :dmp_id is provided and no :PK is provided, it will be used as the @key and @dmp_id
    #
    # Additional entries in :args are handled as follows:
    #   - :dmphub_versions are parsed and their :timestamp used to populate the @versions Array
    #   - :dmphub_modifications are moved as is into the @modifications Array
    #   - Other :dmphub_ prefixed entries are placed into the @extras Hash
    #   - All other entries are placed into the @metadata Hash
    #
    # @param [Hash] args Initialization parameters
    # @option [String] :PK The partition key (otpional)
    # @option [String] :SK The sort key (optional)
    # @option [Hash] :dmp_id The DMP ID (optional) (e.g. `{ "type": "doi", "identifier": "foo" }`)
    def initialize(**args)
      # Metadata houses the RDA Common Standard information of the DMP-ID
      @metadata = {}
      # Extras contains any information that is specific to this application and NOT part of the RDA standard
      @extras = {}
      # This contains the timestamps of the available versions (the corresponding URLs are stored in @metadata)
      @versions = []
      # This contains any augmentations made programmatically by this application that need to be curated
      @modifications = []

      # The base domain for a DMP-ID (e.g. `doi.org`, `dmphub.uc3dev.cdlib.net` or `localhost:3001`)
      @doi_base_domain = ENV['DOI_BASE_DOMAIN']
      # The shoulder portion of the DMP-ID (e.g. `12.12345/1A`)
      @doi_shoulder = ENV['DOI_SHOULDER']
      raise ItemError, MSG_NO_DOI_BASE_DOMAIN if @doi_base_domain.nil? || @doi_base_domain.empty?
      raise ItemError, MSG_NO_DOI_SHOULDER if @doi_shoulder.nil? || @doi_shoulder.empty?

      super(**args)
    end

    # Whether or not this is current version of the DMP
    #
    # @return [Boolean]
    def current_version?
      @versions.nil? || @versions.empty? || @metadata['modified'] == @versions.first
    end

    # Whether or not this version of the DMP is editable
    #
    # @return [Boolean]
    def editable?
      current_version?
      # TODO: Add some logic to determine if the user has permission
    end

    # Convert the NoSQL item into a JSON record for the NoSQL database
    #
    # @return [Hash] The item represented as JSON Hash (with all the NoSQL stuff)
    def to_nosql_hash
      hash = @metadata

      # If this is a new item then generate the key
      @key = _generate_key unless @key.is_a?(Hash) && !@key[:partition_key]&.empty?
      hash['PK'] = @key[:partition_key]
      hash['SK'] = @key[:sort_key]
      hash['dmp_id'] = { type: 'doi', identifier: "https://#{@doi_base_domain}/#{@dmp_id}" }

      hash['dmphub_versions'] = _versions_for_nosql unless @versions.empty?
      hash = hash.merge(@extras)
      hash['dmphub_modifications'] = @modifications
      hash = JSON.parse(hash.to_json)

      tstamp = Time.now.utc.iso8601
      hash['created'] = tstamp if hash['created'].nil?
      hash['dmphub_created_at'] = hash.fetch('created', tstamp) if hash['dmphub_created_at'].nil?
      hash['modified'] = tstamp if hash['modified'].nil?
      hash['dmphub_modification_day'] = hash['modified'][0..9] if hash['dmphub_modification_day'].nil?
      hash['dmphub_updated_at'] = hash.fetch('modified', tstamp) if hash['dmphub_updated_at'].nil?
      hash['dmphub_provenance_id'] = _default_provenance if hash['dmphub_provenance_id'].nil?
      hash['dmphub_provenance_identifier'] = nil if hash['dmphub_provenance_id'].nil?
      JSON.parse(hash.to_json)
    end

    # Convert this object to the RDA Common Standard JSON format for use in the UI or API
    #
    # @return [Hash] This Item represented as JSON Hash (without all of the NoSQL specific stuff)
    def to_json
      hash = @metadata
      hash['dmp_id'] = { type: 'doi', identifier: "https://#{@doi_base_domain}/#{@dmp_id}" }
      JSON.parse(hash.to_json)
    end

    private

    # Returns the default provenance id for this system
    #
    # @return [String]
    def _default_provenance
      "#{PROVENANCE_KEY_PREFIX}#{Rails.configuration.x.application_name&.downcase&.strip}"
    end

    # Convert the raw NoSQL record into the attributes for this Item
    #
    # @param [Hash] The NoSQL record as a Hash
    def _from_hash(hash:)
      args = { metadata: {}, versions: [], modifications: [], extras: [] }

      # Parse out the incoming Hash into DMP parts
      hash.each do |key, val|
        next if %w[adapter PK SK dmp_id].include?(key.to_s)

        case key
        when 'dmphub_versions'
          @versions = val.is_a?(Array) ? val.map { |v| v['timestamp'] } : []
          @versions << hash['modified'] unless @versions.include?(hash['modified'])
        when 'dmphub_modifications'
          @modifications = val
        else
          @metadata[key] = val unless key.start_with?('dmphub_')
          @extras[:"#{key}"] = val if key.start_with?('dmphub_')
        end
      end

      # Sort the versions descending
      @versions = @versions.sort { |a, b| b <=> a }

      # Extract the @key and @dmp_id
      _identifiers_from_hash(**hash)

      # Handles scenario where the incoming Hash had no dmp_id but did have a PK and SK
      @dmp_id = _key_to_dmp_id if @dmp_id.nil?
    end

    # Generate a new NoSQL key from the value set in @dmp_id
    #
    # @raise [Nosql::ItemError] If a new unique key could not be generated
    # @return [Hash] The new key as `{ partition_key: 'foo', sort_key: 'bar' }`
    def _generate_key
      return @key if @key.is_a?(Hash) && !@key[:partition_key]&.empty?

      id = ''
      counter = 0
      while id == '' && counter <= 10
        doi = "#{@doi_shoulder}#{SecureRandom.hex(2).upcase}#{SecureRandom.hex(2)}"
        key = self._append_partition_key_prefixing(key: doi)
        id = doi unless @adapter.exists?(key:)
        counter += 1
      end
      raise ItemError, MSG_UNABLE_TO_ACQUIRE_NEW_ID if id.empty?

      @key = { partition_key: key, sort_key: SORT_KEY_DMP_LATEST_VERSION }
      @dmp_id = _key_to_dmp_id
      @key
    end

    # Extract the @key and @dmp_id from the incoming Hash
    #
    # @param [Hash] args The NoSQL record (either the PK or dmp_id is required)
    # @option args [String] :PK The partition key
    # @option args [String] :SK The sort key (optional)
    # @option args [Hash] :dmp_id The DMP ID (e.g. `{ "type": "doi", "identifier": "foo" }`)
    # @option args [String] :modified The last modification date/time
    # @return [boolean] Whether or not the call was successful
    def _identifiers_from_hash(**args)
      return true if @key.is_a?(Hash) && !@key[:partition_key]&.empty?
      return false unless args.is_a?(Hash) && (!args['PK'].nil? || !args['dmp_id'].nil?)

      # Scenario where the incoming Hash was received from an internal source (has a PK and SK)
      nil_pk = args.fetch('PK', '').empty?

      @key[:partition_key] = _append_partition_key_prefixing(key: args["PK"]) unless nil_pk
      @key[:sort_key] = _append_sort_key_prefix(key: args.fetch("SK", SORT_KEY_DMP_LATEST_VERSION)) unless nil_pk
      @dmp_id = _key_to_dmp_id unless @key.fetch(:partition_key, '').empty?
      return true unless @dmp_id.nil?

      # Scenario where the incoming Hash was received from an external source (has no PK and SK)
      @dmp_id = args.fetch('dmp_id', {})['identifier']&.gsub(%r{https?://}, '')&.gsub("#{@doi_base_domain}/", '')
      version = _detect_version(modified: args['modified'])
      @key = _dmp_id_and_version_to_key(dmp_id: @dmp_id, version: version)
      true
    end

    # Generate a new DMP ID and NoSQL key and set the instance attributes
    #
    # @return [String] The new DMP ID
    def _key_to_dmp_id
      return nil unless @key.is_a?(Hash) && !@key[:partition_key].empty?

      id = self._remove_partition_key_prefixing(key: @key[:partition_key])
      return nil if id.nil?

      id = id.gsub('doi:', '')
      id = id[1..id.length] if id.start_with?('/')
      id
    end

    # Convert the DMP ID into a partition key and the Version into a sort key
    #
    # @param [String] dmp_id The DMP ID
    # @param [String] version The version identifier (default: nil)
    # @return [Hash] The partition and sort key
    def _dmp_id_and_version_to_key(dmp_id:, version: nil)
      return nil if dmp_id.nil?

      p_key = self._append_partition_key_prefixing(key: dmp_id)
      s_key = SORT_KEY_DMP_LATEST_VERSION if version.nil?
      s_key = self._append_sort_key_prefix(key: version) if s_key.nil?
      { partition_key: p_key, sort_key: s_key }
    end

    # Convert the verions array back to the format needed for the NoSQL record
    #
    # @return [Array<Hash>] An array of available versions
    def _versions_for_nosql
      url_id = _remove_partition_key_prefixing(key: @key[:partition_key])
      url = Rails.application.routes.url_helpers.dmp_url(url_id, host: ENV['RAILS_HOST'])

      @versions.map do |version|
        {
          timestamp: version,
          url: "#{url}?version=#{version}"
        }
      end
    end

    # Determine if the specified date is a historical version or the latest version
    #
    # @param [String] modified The modification date as an ISO 8601 string
    # @return [String] The modified date if it is a historical version or nil if it is the latest version
    def _detect_version(modified:)
      return nil if @versions.empty? || modified.nil? || modified.empty?

      @versions.include?(modified) ? modified : nil
    end

    # Extract the DMP ID from the partition key
    #
    # @param [String] key A partition key
    # @return [String] A DMP ID
    def _remove_partition_key_prefixing(key:)
      return nil unless key.is_a?(String)
      return key unless key.start_with?(PARTITION_KEY_DMP_PREFIX)

      # Remove the Dynamo partition key prefix, any web protocol and the base DOI URL
      id = key.gsub(PARTITION_KEY_DMP_PREFIX, '')
              .gsub(%r{https?://}, '')
              .gsub(@doi_base_domain, '')
      # Remove beginning and trailing slashes
      id = id.start_with?('/') ? id[1..id.length] : id
      id.end_with?('/') ? id[0..id.length - 2] : id
    end

    # Append the partition key prefix to the DMP ID
    #
    # @param [String] key A DMP ID
    # @return [String] A partition key
    def _append_partition_key_prefixing(key:)
      return nil unless key.is_a?(String)

      # First remove anything that is already there
      key = _remove_partition_key_prefixing(key:)
      domain = @doi_base_domain.gsub(%r{https?://}, '')
      key = key.include?(domain) ? key : "#{domain}/#{key}"
      "#{PARTITION_KEY_DMP_PREFIX}#{key}"
    end

    # Remove the version from the sort key
    #
    # @param [String] key A sort key
    # @return [String] The version
    def _remove_sort_key_prefixing(key:)
      return SORT_KEY_DMP_LATEST_VERSION if key.nil? || key == SORT_KEY_DMP_LATEST_VERSION
      return key unless key.start_with?(SORT_KEY_DMP_PREFIX)

      key[SORT_KEY_DMP_PREFIX.length..key.length]
    end

    # Add the sort key prefix to the version
    #
    # @param [String] key The version
    # @return [String] The sort key
    def _append_sort_key_prefix(key:)
      return nil if key.nil?
      return key if key.start_with?(SORT_KEY_DMP_PREFIX)

      "#{SORT_KEY_DMP_PREFIX}#{key}"
    end
  end
end
