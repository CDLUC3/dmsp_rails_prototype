# frozen_string_literal: true

require 'json-schema'
require 'securerandom'

# A Data Management and Sharing Plan
#
# Note that NOSQL_ADAPTER and NOSQL_ITEM_CLASS are defined and preloaded during
# Rails initialization!
class Dmp < NOSQL_ITEM_CLASS
  MSG_NO_JSON_SCHEMA = 'No JSON Schema found in the ./lib/ directory!'

  def initialize(**args)
    super(**args)
  end

  class << self
    def all()
      # TODO: Remove this once OpenSearch is in place
      NOSQL_ADAPTER.query
    end

    # Fetch the item by it's DMP ID and version
    #
    # @param dmp_id [String] The DMP ID
    # @param version [String] The version identifier (default: nil)
    # @return item [NosqlAdapter::Item] An instance of this class
    def find_by_dmp_id(dmp_id:, version: nil)
      # Find the record
      key = NOSQL_ITEM_CLASS.from_dmp_id(dmp_id:, version:)
      item = NOSQL_ADAPTER.get(key:)
      return nil unless item.is_a?(NOSQL_ITEM_CLASS)

      # Make sure it matches the record that was asked for!
      return nil unless key == item.key

      item
    end
  end

  # Create or Update a DMP ID. This runs a validation check first
  #
  # return [boolean] Whether or not the save was successful
  def save
    # Do a validation check!
    # return false unless valid?

    Rails.logger.debug("Pre-Save: #{inspect}")
    NOSQL_ADAPTER.put(key: @key, item: self)
  end

  # Delete (or Tombstone if registered) a DMP ID
  #
  # return [boolean] Whether or not the save was successful
  def delete
    return false if registered?

    @versions.each do |ver|
      NOSQL_ADAPTER.delete(key: @key)
    end
    true
  end

  # Validate DMP ID (JSON schema)
  #
  # return [boolean] Whether or not the DMP ID is valid
  def valid?
    schema = _load_schema
    errors << MSG_NO_JSON_SCHEMA if schema.nil?
    return false if schema.nil?

    # Validate the JSON
    errs = JSON::Validator.fully_validate(schema, to_nosql_hash)
    return true if errs.nil? || errs.empty?

    # Process the errros to contextualize them
    errs = errs.map { |err| err.gsub('The property \'#/\' ', '') }
    errs = errs.flatten.compact.uniq unless errs.empty?
    errs = errs.map { |err| err.gsub(/in schema [a-z0-9-]+/, '').strip }
    errors << errs
    return false
  end

  # Determine if the item has already been registered with a DOI registrar
  #
  # return [boolean]
  def registered?
    !@metadata['registered'].empty?
  end

  # Tombstone the registered DMP ID
  #
  # return [boolean] Whether or not the update was successful
  def tombstone
    return false unless registered?

    @key[:sort_key] = DMP_TOMBSTONE_VERSION

    @metadata['title'] = "OBSOLETE: #{@metadata['title']}"
    now = Time.now.utc.iso8601
    @metadata['modified'] = now
    @metadata['tombstoned'] = now

    NOSQL_ADAPTER.put(key: @key, json: to_nosql_hash)
  end

  private

  # Whether or not we should version the DMP ID before updating
  #
  # return [boolean] Whether or not this Item should be versioned
  def _should_version?

  end

  # Generate a new version
  #
  # return [NosqlAdapter::Item] A new version of this Item
  def _new_version

  end

  # Load the JSON schema from the Rails cache or the ./lib directory
  #
  # return [String] The JSON Schema as a String
  def _load_schema
    version = ENV.fetch('DMP_ID_SCHEMA_VERSION', 'v1')
    # Fetch the schema from the cache
    cached = Rails.cache.read('dmp_id_schema')
    return cached[:schema] unless cached.nil? || cached[:version] != version

    schema = File.read(Rails.root.join('lib', 'dmp_id_schema_${version}.json'))
    # Stash the schema into the cache
    Rails.cache.write('dmp_id_schema', { varsion:, schema: }, expires_in: 1.day)
    schema
  rescue NameError => e
    raise DmpError, 'Cache error when attempting to fetch JSON schema: #{e.message}'
  end
end
