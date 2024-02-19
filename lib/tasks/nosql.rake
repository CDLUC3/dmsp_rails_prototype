# frozen_string_literal: true

# NoSQL Database tasks

def dev_nosql_dmps_table_config
  {
    pool_size: ENV['NOSQL_DMPS_POOL_SIZE'], timeout: ENV['NOSQL_DMPS_TIMEOUT'],
    host: ENV['NOSQL_HOST'], port: ENV['NOSQL_PORT'], table: ENV['NOSQL_DMPS_TABLE'],
    access_key: ENV['NOSQL_ACCESS_KEY'], access_secret: ENV['NOSQL_ACCESS_SECRET']
  }
end

def dev_nosql_typeaheads_table_config
  {
    pool_size: ENV['NOSQL_TYPEAHEADS_POOL_SIZE'], timeout: ENV['NOSQL_TYPEAHEADS_TIMEOUT'],
    host: ENV['NOSQL_HOST'], port: ENV['NOSQL_PORT'], table: ENV['NOSQL_TYPEAHEADS_TABLE'],
    access_key: ENV['NOSQL_ACCESS_KEY'], access_secret: ENV['NOSQL_ACCESS_SECRET']
  }
end

namespace :nosql do
  desc 'Purge all content from the NoSQL database'
  task purge_local: :environment do
    # Only allow this in the local Docker dev environment! Cloud based environments
    # should construct the NoSQL database via Infrastructure as Code
    if Rails.env.development?
      begin
        ENV['NOSQL_DMPS_TABLE'] = ENV.fetch('NOSQL_DMPS_TABLE', 'dmsp-local')
        adapter= Nosql::DynamodbAdapter.new(**dev_nosql_dmps_table_config)
        puts "Purging local DMP-IDs NoSQL records ..."
        adapter.send(:purge_database)

        ENV['NOSQL_TYPEAHEADS_TABLE'] = ENV.fetch('NOSQL_TYPEAHEADS_TABLE', 'typeaheads-local')
        adapter= Nosql::DynamodbAdapter.new(**dev_nosql_typeaheads_table_config)
        puts "Checking if Typeaheads NoSQL database needs to be initialized ..."
        adapter.send(:purge_database)
        puts "DONE"
      end
    else
      puts "This task can only be run in the local Docker development environment!"
    end
  end
end
