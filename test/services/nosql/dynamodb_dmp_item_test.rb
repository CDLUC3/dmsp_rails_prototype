# frozen_string_literal: true

require "test_helper"

require "minitest/mock"
require 'ostruct'

module Nosql
  class DynamodbDmpItemTest < ActiveSupport::TestCase

    setup do
      ENV['RAILS_HOST'] = 'http://localhost:3001'
      ENV['DOI_BASE_DOMAIN'] = 'localhost:3001'
      ENV['DOI_SHOULDER'] = '99.88888/7Z.'

      # The table name and nosql_init_args are defined in the `test/test_helper.rb`
      @table = ENV['NOSQL_DMPS_TABLE']
      @adapter = DynamodbAdapter.new(**{ table: @table })

      # Note that Rails.root resolves to `/rails` in our Docker container
      @full_item = JSON.parse(File.read(Rails.root.join('/rails/test/fixtures/files/full_dmp.json')))

      @init_args = { adapter: @adapter }
      @instance = DynamodbDmpItem.new(**@init_args)
    end

    teardown do
      # Clear the database
      @adapter.send(:purge_database)
    end

    # Add a test record to the NoSQL db
    def add_test_record(item:)
      NOSQL_CONNECTION_POOL.with do |client|
        client.put_item({ table_name: @table, item:, return_consumed_capacity: 'NONE' })
      end
    end

    # Tests for `initialize(**args)`
    # -----------------------------------------------------------------------------------------
    test 'initialization raises an error when ENV[\'RAILS_HOST\'] is not defined' do
      ENV.delete('RAILS_HOST')
      assert_raises( Nosql::ItemError) { DynamodbDmpItem.new(**@init_args) }
    end

    test 'initialization raises an error when ENV[\'DOI_BASE_DOMAIN\'] is not defined' do
      ENV.delete('DOI_BASE_DOMAIN')
      assert_raises( Nosql::ItemError) { DynamodbDmpItem.new(**@init_args) }
    end

    test 'initialization raises an error when ENV[\'DOI_SHOULDER\'] is not defined' do
      ENV.delete('DOI_SHOULDER')
      assert_raises( Nosql::ItemError) { DynamodbDmpItem.new(**@init_args) }
    end

    test 'initialization raises an error when a :adapter is not provided' do
      args = @init_args
      args.delete(:adapter)
      assert_raises( Nosql::ItemError) { DynamodbDmpItem.new(**args) }
    end

    test 'initialization is successful for a new record' do
      item = DynamodbDmpItem.new(**@init_args)
      assert_equal([], item.errors)
      assert_equal([], item.versions)
      assert_equal({}, item.metadata)
      assert_equal(@init_args[:adapter], item.adapter)

      assert_equal(ENV['DOI_BASE_DOMAIN'], item.doi_base_domain)
      assert_equal(ENV['DOI_SHOULDER'], item.doi_shoulder)

      assert_equal('', item.key[:partition_key])
      assert_equal('', item.key[:sort_key])
      assert_nil(item.dmp_id)

      host = Rails.configuration.action_mailer.default_url_options[:host]
      dmp_id = item.send(:_remove_partition_key_prefixing, key: item.key[:partition_key])
    end

    test 'initialization is successful when loading a full DMP-ID record via the Dynamo Table (PK+SK)' do
      item = DynamodbDmpItem.new(**@init_args.merge(@full_item))
      assert_equal([], item.errors)
      versions = @full_item['dmphub_versions'].map { |ver| ver['timestamp'] }.sort { |a, b| b<=>a }
      assert_equal(versions, item.versions)

      metadata = @full_item.dup
      %w[PK SK dmphub_created_at dmphub_updated_at dmphub_registered_at dmphub_modification_day
         dmphub_provenance_id dmphub_provenance_identifier dmp_id dmphub_versions
         dmphub_modifications].each { |key| metadata.delete(key) }
      assert_equal(metadata, item.metadata)

      assert_equal(item.send(:_key_to_dmp_id), item.dmp_id)

      assert_equal({ partition_key: @full_item['PK'], sort_key: @full_item['SK'] }, item.key)
      assert_equal(@init_args[:adapter], item.adapter)

      assert_equal(ENV['DOI_BASE_DOMAIN'], item.doi_base_domain)
      assert_equal(ENV['DOI_SHOULDER'], item.doi_shoulder)

      host = Rails.configuration.action_mailer.default_url_options[:host]
      dmp_id = item.send(:_remove_partition_key_prefixing, key: item.key[:partition_key])
    end

    test 'initialization is successful when loading a full DMP-ID record via the API (DMP-ID but no PK+SK)' do
      json = @full_item.dup
      %w[PK SK dmphub_created_at dmphub_updated_at dmphub_registered_at dmphub_modification_day
         dmphub_provenance_id dmphub_provenance_identifier dmphub_versions
         dmphub_modifications].each { |key| json.delete(key) }
      item = DynamodbDmpItem.new(**@init_args.merge(json))
      json.delete('dmp_id')
      assert_equal(json, item.metadata)

      assert_equal([], item.errors)
      assert_equal([], item.versions)

      assert_equal(item.send(:_key_to_dmp_id), item.dmp_id)

      assert_equal({ partition_key: @full_item['PK'], sort_key: @full_item['SK'] }, item.key)
      assert_equal(@init_args[:adapter], item.adapter)

      assert_equal(ENV['DOI_BASE_DOMAIN'], item.doi_base_domain)
      assert_equal(ENV['DOI_SHOULDER'], item.doi_shoulder)

      host = Rails.configuration.action_mailer.default_url_options[:host]
      dmp_id = item.send(:_remove_partition_key_prefixing, key: item.key[:partition_key])
    end

    # Tests for `current_version?`
    # -----------------------------------------------------------------------------------------
    test 'current_version? returns true if the :versions Array is empty' do
      assert @instance.current_version?
    end

    test 'current_version? returns true if the :modified tstamp matches the most recent item in :versions Array' do
      json = JSON.parse({
        dmphub_versions: [
          { timestamp: '2024-01-01T00:00:00+00:00', url: "#{ENV['RAILS_HOST']}/dmp12?version=2024-01-01T00:00:00+00:00" },
          { timestamp: '2024-02-02T01:01:01+00:00', url: "#{ENV['RAILS_HOST']}/dmp12?version=2024-02-02T01:01:01+00:00" }
        ],
        created: '2024-01-01T00:00:00+00:00',
        modified: '2024-02-02T01:01:01+00:00'
      }.to_json)
      item = DynamodbDmpItem.new(**@init_args.merge(json))
      assert item.current_version?
    end

    test 'current_version? returns false if the :modified tstamp does NOT match the most recent item in :versions Array' do
      json = JSON.parse({
        dmphub_versions: [
          { timestamp: '2024-01-01T00:00:00+00:00', url: "#{ENV['RAILS_HOST']}/dmp12?version=2024-01-01T00:00:00+00:00" },
          { timestamp: '2024-02-02T01:01:01+00:00', url: "#{ENV['RAILS_HOST']}/dmp12?version=2024-02-02T01:01:01+00:00" }
        ],
        created: '2024-01-01T00:00:00+00:00',
        modified: '2024-01-01T00:00:00+00:00'
      }.to_json)
      item = DynamodbDmpItem.new(**@init_args.merge(json))
      assert_not item.current_version?
    end

    # Tests for `to_nosql_hash`
    # -----------------------------------------------------------------------------------------
    test 'to_nosql_hash return the expected JSON content for a new item' do
      json = JSON.parse({ title: 'Testing new item' }.to_json)
      item = DynamodbDmpItem.new(**@init_args.merge(json))
      out = item.to_nosql_hash

      assert_equal item.key[:partition_key], out['PK']
      assert_equal item.key[:sort_key], out['SK']
      id = JSON.parse({ type: 'doi', identifier: "https://#{item.doi_base_domain}/#{item.dmp_id}" }.to_json)
      assert_equal id, out['dmp_id']
      assert_equal json['title'], out['title']
      assert_not_nil out['created']
      assert_not_nil out['modified']

      assert_not_nil out['dmphub_created_at']
      assert_not_nil out['dmphub_updated_at']
      assert_nil out['dmphub_registered_at']
      assert_equal out['dmphub_created_at'][0..9], out['dmphub_modification_day']
      prov = "#{DynamodbDmpItem::PROVENANCE_KEY_PREFIX}#{Rails.configuration.x.application_name&.downcase}"
      assert_equal out['dmphub_provenance_id'], prov
      assert_nil out['dmphub_provenance_identifier']
      assert_nil out['dmphub_versions']
      assert_equal [], out['dmphub_modifications']
    end

    test 'to_nosql_hash return the expected JSON content for a known item' do
      item = DynamodbDmpItem.new(**@init_args.merge(@full_item))
      out = item.to_nosql_hash
      @full_item.each_key do |key|
        assert_equal(@full_item[key], out[key], "#{key} mismatch")
      end
    end

    # Tests for `to_json`
    # -----------------------------------------------------------------------------------------
    test 'to_json returns the expected JSON content' do
      item = DynamodbDmpItem.new(**@init_args.merge(@full_item))
      expected = item.metadata.merge(JSON.parse({ dmp_id: @full_item['dmp_id'] }.to_json))
      assert_equal expected, item.to_json
    end

    # Tests for `_append_partition_key_prefixing(key:)`
    # -----------------------------------------------------------------------------------------
    test '_append_partition_key_prefixing returns nil when :key is nil' do
      assert_nil(@instance.send(:_append_partition_key_prefixing, key: nil))
    end

    test '_append_partition_key_prefixing return the :key as-is if it already starts with the prefix' do
      key = "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}/teSTing"
      assert_equal(key, @instance.send(:_append_partition_key_prefixing, key:))
    end

    test '_append_partition_key_prefixing appends the prefix to the :key' do
      key = 'teSTing'
      expected = "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}/#{key}"
      assert_equal(expected, @instance.send(:_append_partition_key_prefixing, key:))
    end

    # Tests for `_remove_partition_key_prefixing(key:)`
    # -----------------------------------------------------------------------------------------
    test '_remove_partition_key_prefixing returns the default SK when :key is nil' do
      assert_nil @instance.send(:_remove_partition_key_prefixing, key: nil)
    end

    test '_remove_partition_key_prefixing return the :key as-is if it does not start with the prefix' do
      key = "teSTing/#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}"
      assert_equal(key, @instance.send(:_remove_partition_key_prefixing, key:))
    end

    test '_remove_partition_key_prefixing removes the prefix to the :key' do
      key = "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}/teSTing"
      assert_equal("teSTing", @instance.send(:_remove_partition_key_prefixing, key:))
    end

    # Tests for `_append_sort_key_prefix(key:)`
    # -----------------------------------------------------------------------------------------
    test '_append_sort_key_prefix returns nil when :key is nil' do
      assert_nil(@instance.send(:_append_sort_key_prefix, key: nil))
    end

    test '_append_sort_key_prefix return the :key as-is if it already starts with the prefix' do
      key = "#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}teSTing"
      assert_equal(key, @instance.send(:_append_sort_key_prefix, key:))
    end

    test '_append_sort_key_prefix appends the prefix to the :key' do
      key = 'teSTing'
      assert_equal("#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}#{key}", @instance.send(:_append_sort_key_prefix, key:))
    end

    # Tests for `_remove_sort_key_prefixing(key:)`
    # -----------------------------------------------------------------------------------------
    test '_remove_sort_key_prefixing returns the default SK when :key is nil' do
      assert_equal(DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION, @instance.send(:_remove_sort_key_prefixing, key: nil))
    end

    test '_remove_sort_key_prefixing return the :key as-is if it does not start with the prefix' do
      key = "teSTing#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}"
      assert_equal(key, @instance.send(:_remove_sort_key_prefixing, key:))
    end

    test '_remove_sort_key_prefixing removes the prefix to the :key' do
      key = "#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}teSTing#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}"
      assert_equal("teSTing#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}", @instance.send(:_remove_sort_key_prefixing, key:))
    end

    # Tests for `_detect_version(modified:)`
    # -----------------------------------------------------------------------------------------
    test '_detect_version returns nil if :modified is nil' do
      assert_nil(@instance.send(:_detect_version, modified: nil))
    end

    test '_detect_version returns nil if :modified is NOT in the versions array' do
      mod = @instance.versions.first
      assert_nil(@instance.send(:_detect_version, modified: 'TesTing'))
    end

    test '_detect_version returns :modified if :modified is in the versions Array' do
      mod = @instance.versions.last
      assert_nil(mod, @instance.send(:_detect_version, modified: mod))
    end

    # Tests for `_versions_for_nosql`
    # -----------------------------------------------------------------------------------------
    test '_versions_for_nosql returns the versions ready for NoSQL' do
      item = DynamodbDmpItem.new(**@init_args.merge(@full_item))
      assert item.versions.any?
      url = "#{ENV['RAILS_HOST']}/dmps/#{item.dmp_id.gsub('/', '%2F')}"
      expected = item.versions.map { |i| { timestamp: i, url: "#{url}?version=#{i}"} }
      assert_equal(expected, item.send(:_versions_for_nosql))
    end

    # Tests for `_dmp_id_and_version_to_key(dmp_id:, version: nil)`
    # -----------------------------------------------------------------------------------------
    test '_dmp_id_and_version_to_key returns nil if :dmp_id is nil' do
      assert_nil(@instance.send(:_dmp_id_and_version_to_key, dmp_id: nil))
    end

    test '_dmp_id_and_version_to_key uses the default :sort_key if :version is nil' do
      expected = {
        partition_key: "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}/TesTing",
        sort_key: DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION
      }
      assert_equal(expected, @instance.send(:_dmp_id_and_version_to_key, dmp_id: 'TesTing'))
    end

    test '_dmp_id_and_version_to_key returns the expected key' do
      tstamp = '1950-01-02T03:04:05+00:00'
      expected = {
        partition_key: "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{ENV['DOI_BASE_DOMAIN']}/TesTing",
        sort_key: "#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}#{tstamp}"
      }
      assert_equal(expected, @instance.send(:_dmp_id_and_version_to_key, dmp_id: 'TesTing', version: tstamp))
    end

    # Tests for `_key_to_dmp_id`
    # -----------------------------------------------------------------------------------------
    test '_key_to_dmp_id returns nil if :key is not defined' do
      assert_nil(@instance.send(:_key_to_dmp_id))
    end

    test '_key_to_dmp_id returns nil if :key does not contain :partition_key' do
      assert_nil(@instance.send(:_key_to_dmp_id))
    end

    # Tests for `_identifiers_from_hash(**args)`
    # -----------------------------------------------------------------------------------------
    test '_identifiers_from_hash returns false if :args is not a Hash' do
      assert_not @instance.send(:_identifiers_from_hash)
    end

    test '_identifiers_from_hash returns false if :args does not contain a :PK or a :dmp_id' do
      assert_not @instance.send(:_identifiers_from_hash, test: 'TesT')
    end

    test '_identifiers_from_hash returns true if the :key already has a :partition_key' do
      item = DynamodbDmpItem.new(**@init_args.merge(JSON.parse({ 'PK': 'Test' }.to_json)))
      assert item.send(:_identifiers_from_hash)
    end

    test '_identifiers_from_hash sets the :key and :dmp_id when :args contains a :PK and :SK' do
      assert @instance.send(:_identifiers_from_hash, **@init_args.merge(JSON.parse({ PK: 'TesT', SK: 'SorT' }.to_json)))
      expected = {
        partition_key: "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{@instance.doi_base_domain}/TesT",
        sort_key: "#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}SorT"
      }
      assert_equal expected, @instance.key
      assert_equal 'TesT', @instance.dmp_id
    end

    test '_identifiers_from_hash sets the :key :sort_key to the default if :args contains a :PK but no :SK' do
      assert @instance.send(:_identifiers_from_hash, **@init_args.merge(JSON.parse({ PK: 'TesT' }.to_json)))
      expected = {
        partition_key: "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{@instance.doi_base_domain}/TesT",
        sort_key: DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION
      }
      assert_equal expected, @instance.key
    end

    test '_identifiers_from_hash sets the :key and :dmp_id when :args contains a :dmp_id but no :PK' do
      json = JSON.parse({
        dmp_id: { type: 'doi', identifier: "#{ENV['RAILS_HOST']}/TesT"}
      }.to_json)
      assert @instance.send(:_identifiers_from_hash, **@init_args.merge(json))
      expected = {
        partition_key: "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{@instance.doi_base_domain}/TesT",
        sort_key: DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION
      }
      assert_equal expected, @instance.key
      assert_equal 'TesT', @instance.dmp_id
    end

    # Tests for `_generate_key`
    # -----------------------------------------------------------------------------------------
    test '_generate_key returns the :key as-is if it already has a :partition_key' do
      item = DynamodbDmpItem.new(**@init_args.merge(JSON.parse({ 'PK': 'TesT' }.to_json)))
      expected = {
        partition_key: "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{item.doi_base_domain}/TesT",
        sort_key: DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION
      }
      assert_equal expected, item.send(:_generate_key)
    end

    test '_generate_key returns a newly generated :key and sets the :dmp_id' do
      item = DynamodbDmpItem.new(**@init_args.merge(JSON.parse({ 'PK': 'TesT' }.to_json)))
      item.send(:_generate_key)
      assert_equal DynamodbDmpItem::SORT_KEY_DMP_LATEST_VERSION, item.key[:sort_key]
      assert_not_nil item.dmp_id
      expected = "#{DynamodbDmpItem::PARTITION_KEY_DMP_PREFIX}#{item.doi_base_domain}/#{item.dmp_id}"
      assert_equal expected, item.key[:partition_key]
    end

    # Tests for `_from_hash(hash:)`
    # -----------------------------------------------------------------------------------------
    test '_from_hash does NOT set the key when no :PK or :dmp_id are in the :hash' do
      @instance.send(:_from_hash, hash: {})
      assert_equal({ partition_key: '', sort_key: '' }, @instance.key)
    end

    test '_from_hash sets the key when no :PK and :SK but a :dmp_id is in the :hash' do
      json = @full_item.dup
      json.delete('PK')
      json.delete('SK')
      @instance.send(:_from_hash, hash: json)
      expected = {
        partition_key: @full_item['PK'],
        sort_key: "#{DynamodbDmpItem::SORT_KEY_DMP_PREFIX}#{@full_item['modified']}"
      }
      assert_equal(expected, @instance.key)
      assert_equal(@instance.send(:_key_to_dmp_id), @instance.dmp_id)
    end

    test '_from_hash sets the key when a :PK is defined in the :hash' do
      json = @full_item.dup
      json.delete('dmp_id')
      @instance.send(:_from_hash, hash: json)
      expected = { partition_key: @full_item['PK'], sort_key: @full_item['SK'] }
      assert_equal(expected, @instance.key)
      assert_equal(@instance.send(:_key_to_dmp_id), @instance.dmp_id)
    end

    test '_from_hash sets the :versions to the :dmphub_versions defined in the :hash' do
      expected = @full_item['dmphub_versions'].map { |ver| ver['timestamp'] }.sort { |a, b| b <=> a }
      @instance.send(:_from_hash, hash: @full_item)
      assert_equal(expected, @instance.versions)
    end

    test '_from_hash sets the :metadata to all the RDA common standard items in the :hash' do
      expected = @full_item.dup
      %w[PK SK dmp_id dmphub_created_at dmphub_modification_day dmphub_provenance_id dmphub_provenance_identifier
         dmphub_registered_at dmphub_updated_at dmphub_modifications dmphub_versions].each do |key|
        expected.delete(key)
      end
      @instance.send(:_from_hash, hash: @full_item)
      assert_equal(expected, @instance.metadata)
    end

    test '_from_hash sets the :modifications to the :dmphub_modifications defined in the :hash' do
      expected = @full_item['dmphub_modifications']
      @instance.send(:_from_hash, hash: @full_item)
      assert_equal(expected, @instance.modifications)
    end

    test '_from_hash sets the :extras to all the other `dmphub_` prefixed items in :hash' do
      expected = {
        dmphub_created_at: @full_item['dmphub_created_at'],
        dmphub_modification_day: @full_item['dmphub_modification_day'],
        dmphub_provenance_id: @full_item['dmphub_provenance_id'],
        dmphub_provenance_identifier: @full_item['dmphub_provenance_identifier'],
        dmphub_registered_at: @full_item['dmphub_registered_at'],
        dmphub_updated_at: @full_item['dmphub_updated_at']
      }
      @instance.send(:_from_hash, hash: @full_item)
      assert_equal(expected, @instance.extras)
    end
  end
end
