# frozen_string_literal: true

require 'json-schema'
require 'securerandom'

class Dmp < NosqlRecord
  MSG_NO_DOI_SHOULDER_DEFINED = 'No ENV[\'DOI_SHOULDER\'] defined!'
  MSG_NO_JSON_SCHEMA = 'No JSON Schema found in the ./lib/ directory!'
  MSG_UNABLE_TO_ACQUIRE_NEW_ID = 'Unable to acquire a new DMP ID after 10 attempts!'

  PK_DMP_PREFIX = 'DMP#'
  PK_DMP_REGEX = %r{DMP#[a-zA-Z0-9\-_.]+/[a-zA-Z0-9]{2}\.[a-zA-Z0-9./:]+}

  SK_DMP_PREFIX = 'VERSION#'
  SK_DMP_REGEX = /VERSION#\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}/

  DMP_LATEST_VERSION = "#{SK_DMP_PREFIX}latest".freeze
  DMP_TOMBSTONE_VERSION = "#{SK_DMP_PREFIX}tombstone".freeze

  # DMP ID and Version are assigned within this class and immutable outside
  attr_reader :versions, :errors
  attr_accessor :metadata

  # Initialize a DMP ID record. Note the following three scenarios:
  #   - `Dmp.new(dmp_id: '11.22222/aaa333')` Will load the latest version of the DMP ID
  #   - `Dmp.new(dmp_id: '11.22222/aaa333', version: '2023-12-20')` Will load the specific version
  #   - Excluding the :dmp_id will initialize a new DMP ID
  def initialize(**args)
    @versions = []
    @errors = []
    super(**args)

    # If a DMP ID was included then load the record from Dynamo
    load_args = { dmp_id: args[:dmp_id], version: args.fetch(:version, DMP_LATEST_VERSION) }
    args[:dmp_id].nil? ? @metadata = args : _find_by_dmp_id(load_args)
  end

  # Create or Update a DMP ID
  def save
    # If this is a new record, allocate a unique DMP ID
    _generate_dmp_id if @partion_key.nil?

    # Do a validation check!

    Rails.logger.info("PreSave ENV: #{ENV.keys.length}")

    @client.put(key: { 'PK': @partion_key, 'SK': @version }, json: _to_dynamo_json)
  end

  # Delete (or Tombstone if registered) a DMP ID
  def delete
    return _tombstone if registered?

    @versions.each do |ver|
      @client.delete(key: { 'PK': @partion_key, 'SK': _append_sort_key_prefix(key: ver) })
    end
  end

  # Validate DMP ID (JSON schema)
  def valid?
    schema = _load_schema
    errors << MSG_NO_JSON_SCHEMA if schema.nil?
    return false if schema.nil?

    # Validate the JSON
    errs = JSON::Validator.fully_validate(schema, _to_dynamo_json)
    return true if errs.nil? || errs.empty?

    # Process the errros to contextualize them
    errs = errs.map { |err| err.gsub('The property \'#/\' ', '') }
    errs = errs.flatten.compact.uniq unless errs.empty?
    errs = errs.map { |err| err.gsub(/in schema [a-z0-9-]+/, '').strip }
    errors << errs
    return false
  end

  def dmp_id
    return nil if @partion_key.nil?

    # Remove the Dyanmo partition key prefix and the DOI base URL
    _remove_partition_key_prefixing(key: @partion_key)
  end

  def version
    @partion_key.nil? ? nil : @sort_key.nil? ? DMP_LATEST_VERSION : @sort_key
  end

  def registered?
    !@metadata['registered'].empty?
  end

  private

  # Fetch the DMP ID record by it's DMP ID
  def _find_by_dmp_id(dmp_id:, version: DMP_LATEST_VERSION)
    # Convert the DMP ID into a PK
    p_key = _append_partition_key_prefixing(key: id)
    s_key = version == DMP_LATEST_VERSION ? DMP_LATEST_VERSION : _append_sort_key_prefix(key: version)
    # Find the record
    resp = @client.get(key: { 'PK': p_key, 'SK': s_key })
    return nil unless resp.is_a?(Hash)

    # Make sure it matches the record that was asked for!
    item = resp['dmp'].nil? ? resp : resp['dmp']
    return nil unless item['PK'] == p_key && item['SK'] == version

    # Set the partion and sort key
    @partion_key = item['PK']
    @sort_key = item['SK']

    # Record all the versions in an array for faster access
    @versions = item.fetch('dmphub_versions', []).map { |ver| ver['timestamp'] }
    @versions << item['modified'] unless @versions.include?(item['modified'])

    @metadata = item
  end

  # Convert this object into a DynamoDB DMP ID JSON record
  def _to_dynamo_json
    @metadata['PK'] = @partion_key if @metadata['PK'].nil?
    @metadata['SK'] = @sort_key

    @metadata['dmphub_provenance'] = 'dmsp-prototype' if @metadata['dmphub_provenance'].nil?
    @metadata['dmp_id'] = { type: 'doi', identifier: "#{_dmp_id_base_url}#{dmp_id}" }
    JSON.parse(@metadata.to_json)
  end

  # Whether or not we should version the DMP ID before updating
  def _should_version?

  end

  # Generate a new version
  def _new_version

  end

  # Tombstone the registered DMP ID
  def _tombstone
    @metadata['title'] = "OBSOLETE: #{@metadata['title']}"
    @sort_key = DMP_TOMBSTONE_VERSION
    now = Time.now.utc.iso8601
    @metadata['modified'] = now
    @metadata['tombstoned'] = now

    @client.put(key: { 'PK': @partion_key, 'SK': @sort_key }, json: _to_dynamo_json)
  end

  # Generate new DMP ID unless it already has one
  def _generate_dmp_id
    return @partion_key unless @partion_key.nil?
    raise DmpError, MSG_NO_DOI_SHOULDER_DEFINED if ENV['DOI_SHOULDER'].nil?

    id = ''
    counter = 0
    while id == '' && counter <= 10
      doi = "#{ENV['DOI_SHOULDER']}#{SecureRandom.hex(2).upcase}#{SecureRandom.hex(2)}"
      key = { 'PK': _append_partition_key_prefixing(key: doi), 'SK': DMP_LATEST_VERSION }
      id = prefix unless @client.exists?(key:)
      counter += 1
    end
    raise DmpError, MSG_UNABLE_TO_ACQUIRE_NEW_ID if id.empty?

    @partion_key = key['PK']
    @sort_key = DMP_LATEST_VERSION
  end

  def _remove_partition_key_prefixing(key:)
    # Remove the Dynamo partition key prefix, any web protocol and the base DOI URL
    id = key.gsub(PK_DMP_PREFIX, '')
            .gsub(%r{https?://}, '')
            .gsub(_dmp_id_base_url, '')
    # Remove beginning and trailing slashes
    id = id.start_with?('/') ? id[1..id.length] : id
    id.end_with?('/') ? id[0..id.length - 2] : id
  end

  def _append_partition_key_prefixing(key:)
    # First remove anything that is already there
    key = _remove_partition_key_prefixing(key:)
    "#{PK_DMP_PREFIX}#{_dmp_id_base_url}#{key}"
  end

  def _remove_sort_key_prefixing(key:)
    key.gsub(SK_DMP_PREFIX, '')
  end

  def _append_sort_key_prefix(key:)
    # Firts remove anything that is already there
    key = _remove_sort_key_prefixing(key:)
    "#{SK_DMP_PREFIX}#{key}"
  end

  # Return the base URL for a DMP ID
  def _dmp_id_base_url(include_protocol: false)
    url = ENV.fetch('DOI_BASE_URL', 'http://localhost:3001')
    url = url.gsub(%r{https?://}, '') unless include_protocol
    url&.end_with?('/') ? url : "#{url}/"
  end

  # Load the JSON schema from the Rails cache or the ./lib directory
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
