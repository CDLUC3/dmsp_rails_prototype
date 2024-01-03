# frozen_string_literal: true

require 'securerandom'

module NosqlAdapter
  # A NoSQL item/record
  class AwsDynamodbItem < Item
    PARTITION_KEY_DMP_PREFIX = 'DMP#'.freeze
    PARTITION_KEY_DMP_REGEX = %r{DMP#[a-zA-Z0-9\-_.]+/[a-zA-Z0-9]{2}\.[a-zA-Z0-9./:]+}.freeze

    SORT_KEY_DMP_PREFIX = 'VERSION#'.freeze
    SORT_KEY_DMP_REGEX = /VERSION#\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}/.freeze

    SORT_KEY_DMP_LATEST_VERSION = "#{SORT_KEY_DMP_PREFIX}latest".freeze
    SORT_KEY_DMP_TOMBSTONE_VERSION = "#{SORT_KEY_DMP_PREFIX}tombstone".freeze

    attr_reader :landing_page_url, :extras

    def initialize(**args)
      super(**args)

      @extras = {}
      # Set the default landing page URL
      host = Rails.configuration.action_mailer.default_url_options[:host]
      @landing_page_url = Rails.application.routes.url_helpers.dmps_url(@dmp_id, host:)

      # Parse the incoming JSON Hash
      _from_nosql_hash(hash: args)
    end

    # Convert the NoSQL item into a JSON record for the NoSQL database
    #
    # @return [Hash] The item represented as a Hash that is ready for the NoSQL database
    def to_nosql_hash
      hash = @metadata

      hash['PK'] = @key[:partion_key]
      hash['SK'] = @key[:sort_key]
      hash['dmphub_provenance'] = 'dmsp-prototype' if hash['dmphub_provenance'].nil?
      hash['dmp_id'] = { type: 'doi', identifier: @dmp_id }

      hash['versions'] = _versions_for_nosql

      hash
    end

    # Convert this object to the RDA Common Standard JSON format for use in the UI or API
    def to_json
      hash = @metadata
      hash['dmp_id'] = { type: 'doi', identifier: "#{@doi_base_url}#{@dmp_id}" }
      hash
    end

    private

    # Convert the raw NoSQL record into this item
    #
    # @param hash [Hash] The NoSQL record as a Hash
    # @return item [NosqlAdapter::AwsDynamodbItem] An instance of this class
    def _from_nosql_hash(hash:)
      args = { key: {}, metadata: {}, versions: [], modifications: [], extras: [] }

      # Parse out the incoming Hash into DMP parts
      hash.each do |key, val|
        next if %w[PK SK dmp_id].include?(key)

        @metadata[key] = val unless key.start_with?('dmphub_')
        next unless key.start_with?('dmphub_')

        case key
        when 'dmphub_versions'
          @versions = val.is_a?(Array) ? val.map { |v| v['timestamp'] } : []
          @versions << hash['modified'] unless @versions.include?(hash['modified'])
        when 'dmphub_modifications'
          @modifications = val
        else
          @extras[:"#{key}"] = val
        end
      end

      # Sort the versions descending
      @versions = @versions.sort { |a, b| b <=> a }

      # Extract the @key and @dmp_id
      _identifiers_from_hash(**args)
      # If no @key was found and there are no know versions, generate a new @key and @dmp_id
      _generate_key if @key.nil? || (@key.fetch(:partion_key, '').empty? && @versions.empty?)
    end

    # Generate a new NoSQL key from the value set in @dmp_id
    #
    # @return [NosqlAdapter::Key] The
    def _generate_key
      return @key if @key.is_a?(Hash) && !@key[:partion_key].empty?

      id = ''
      counter = 0
      while id == '' && counter <= 10
        doi = "#{@doi_shoulder}#{SecureRandom.hex(2).upcase}#{SecureRandom.hex(2)}"
        key = self._append_partition_key_prefixing(key: doi)
        id = doi unless NOSQL_ADAPTER.exists?(key:)
        counter += 1
      end
      raise NoSqlItemError, MSG_UNABLE_TO_ACQUIRE_NEW_ID if id.empty?

      @key = { partion_key: key, sort_key: SORT_KEY_DMP_LATEST_VERSION }
      @dmp_id = _key_to_dmp_id
    end

    # Extract the @key and @dmp_id from the incoming Hash
    def _identifiers_from_hash(**args)
      return false unless args.is_a?(Hash) && (!args['PK'].nil? || !args['dmp_id'].nil?)
      return true if @key.is_a?(Hash) && !@key[:partion_key].empty?

      @key[:partion_key] = args["PK"] unless args.fetch('PK', '').empty?
      @key[:sort_key] = args["SK"] unless args.fetch('SK', '').empty?

      @dmp_id = _key_to_dmp_id unless @key.fetch(:partion_key, '').empty?
      return true unless @dmp_id. nil?

      @dmp_id = args.fetch('dmp_id', {})['identifier']&.gsub(%r{https?://}, '') if @dmp_id.nil?
      version = _detect_version(modified: args['modified'])
      @key = _dmp_id_and_version_to_key(dmp_id: @dmp_id, version: version)
      true
    end

    # Generate a new DMP ID and NoSQL key and set the instance attributes
    #
    # @return [String] The new DMP ID
    def _key_to_dmp_id
      return nil unless @key.is_a?(Hash) && !@key[:partion_key].empty?

      id = self._remove_partition_key_prefixing(key: @key[:partion_key])
      return nil if id.nil?

      id = id.gsub('doi:', '')
      id = id[1..id.length] if id.start_with?('/')
      id
    end

    # Convert the DMP ID into a partion key and the Version into a sort key
    #
    # @param dmp_id [String] The DMP ID
    # @param version [String] The version identifier (default: nil)
    # @return key [Hash] The partition and sort key
    def _dmp_id_and_version_to_key(dmp_id:, version: nil)
      p_key = self._append_partition_key_prefixing(key: dmp_id)
      s_key = version.nil? SORT_KEY_DMP_LATEST_VERSION
      s_key = self._append_sort_key_prefix(key: version) if s_key.nil?
      { partion_key: p_key, sort_key: s_key }
    end

    # Convert the verions array back to the format needed for the NoSQL record
    def _versions_for_nosql
      @versions.map do |version|
        {
          timestamp: version,
          url: "#{@landing_page_url}?version=#{version}"
        }
      end
    end

    # Extract the DMP ID from the partition key
    #
    # @param key [String] A partition key
    # @return [String] A DMP ID
    def _remove_partition_key_prefixing(key:)
      return nil unless key.is_a?(String)

      # Remove the Dynamo partition key prefix, any web protocol and the base DOI URL
      id = key.gsub(PARTITION_KEY_DMP_PREFIX, '')
              .gsub(%r{https?://}, '')
              .gsub(_dmp_id_base_url, '')
      # Remove beginning and trailing slashes
      id = id.start_with?('/') ? id[1..id.length] : id
      id.end_with?('/') ? id[0..id.length - 2] : id
    end

    # Append the partition key prefix to the DMP ID
    #
    # @param key [String] A DMP ID
    # @return [String] A partition key
    def _append_partition_key_prefixing(key:)
      return nil unless key.is_a?(String)

      # First remove anything that is already there
      key = _remove_partition_key_prefixing(key:)
      "#{PARTITION_KEY_DMP_PREFIX}#{_dmp_id_base_url}#{key}"
    end

    # Remove the version from the sort key
    #
    # @param key [String] A sort key
    # @return [String] The version
    def _remove_sort_key_prefixing(key:)
      return SORT_KEY_DMP_LATEST_VERSION if key.nil? || key == SORT_KEY_DMP_LATEST_VERSION

      key.gsub(SORT_KEY_DMP_PREFIX, '')
    end

    # Add the sort key prefix to the version
    #
    # @param key [String] The version
    # @return [String] The sort key
    def _append_sort_key_prefix(key:)
      # Firts remove anything that is already there
      key = _remove_sort_key_prefixing(key:)
      "#{SORT_KEY_DMP_PREFIX}#{key}"
    end
  end
end