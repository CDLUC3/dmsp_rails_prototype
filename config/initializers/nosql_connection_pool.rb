# frozen_string_literal: true

require 'connection_pool'
require 'aws-sdk-dynamodb'

options = { region: ENV.fetch('AWS_REGION', 'us-west-2') }

# If this is a local Docker env then we need to supply more connection args
if Rails.env.development? || Rails.env.test?
  options = options.merge({
    endpoint: "http://#{[ENV['NOSQL_HOST'], ENV['NOSQL_PORT']].join(':')}",
    credentials: Aws::Credentials.new(ENV['NOSQL_ACCESS_KEY'], ENV['NOSQL_ACCESS_SECRET'])
  })
end

pool_size = ENV.fetch('NOSQL_POOL_SIZE', 5)
pool_timeout = ENV.fetch('NOSQL_DMPS_TIMEOUT', 5)&.to_f

# Establish the connection pool
dynamodb_pool = ConnectionPool.new(size: pool_size, timeout: pool_timeout) do
  Aws::DynamoDB::Client.new(options)
end

# Make the connection pool available for the rest of the application
NOSQL_CONNECTION_POOL = dynamodb_pool

# If this is a local Docker env, then ensure that the DynamoDB table exists
if Rails.env.development? || Rails.env.test?
  tables = [ENV['NOSQL_DMPS_TABLE'], ENV['NOSQL_TYPEAHEADS_TABLE']]
  tables = tables.map { |tbl| "#{tbl}Test" } if Rails.env.test?

  tables.each do |table|
    NOSQL_CONNECTION_POOL.with do |client|
      begin
        Rails.logger.info "Checking to see if the NoSQL table '#{table}' exists ..."
        resp = client.describe_table({ table_name: table })
      rescue
        Rails.logger.info "No table found."
      end

      # Only create the table if it does not already exist!
      if resp&.table&.creation_date_time.nil?
        Rails.logger.info 'Creating table ...'
        client.create_table({
          attribute_definitions: [
            { attribute_name: 'PK', attribute_type: 'S' },
            { attribute_name: 'SK', attribute_type: 'S' }
          ],
          key_schema: [
            { attribute_name: 'PK', key_type: 'HASH' },
            { attribute_name: 'SK', key_type: 'RANGE' }
          ],
          provisioned_throughput: {
            read_capacity_units: 5,
            write_capacity_units: 5
          },
          table_name: table
        })
        true
      else
        Rails.logger.info 'Table already exists.'
        false
      end
    end
  end
end
