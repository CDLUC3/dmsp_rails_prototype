# frozen_string_literal: true

# NOTE: This runs after Rails has finished initializing and after the other initializers have run!
#
# Environment specific configuration
Rails.application.config.after_initialize do

  # We are using AWS DynamoDB. If you want to use a different Cloud provider, you
  # will need to:
  #   1. Create the corresponding Item and Adapter classes in the app/services/nosql_adapter dir
  #   2. Add your new adapter to the app/services/nosql_adapter/factory.rb
  #   3. Update this file to use your new classes.
  #
  NOSQL_ITEM_CLASS = NosqlAdapter::AwsDynamodbItem

  # If we are running in the local Docker development environment
  if Rails.env.docker?
    nosql_args = {
      table: ENV.fetch('NOSQL_TABLE', 'dmsp-local'),
      size: ENV.fetch('NOSQL_POOL_SIZE', 3),
      timeout: ENV.fetch('NOSQL_TIMEOUT', 5),
      connection: {
        region: ENV.fetch('AWS_REGION', 'us-west-2'),
        endpoint: "http://#{[ENV['NOSQL_HOST'], ENV['NOSQL_PORT']].join(':')}",
        credentials: Aws::Credentials.new(ENV['NOSQL_ACCESS_KEY'], ENV['NOSQL_ACCESS_SECRET'])
      }
    }

puts nosql_args

    # Use AWS as the Cloud Provider here so that it uses the local AWS NoSQL Workbench
    NOSQL_ADAPTER = NosqlAdapter::Factory.create_adapter(:aws, nosql_args)
  else
    # Fetch the Cloud Provider
    cloud_provider = ENV['CLOUD_PROVIDER']&.downcase&.to_sym

    if cloud_provider.nil?
      # Need to define a NOSQL_ADAPTER for a non-cloud hosted environment (probably MongoDB)
    else
      # If a CloudProvider was defined then generate connections/clients for the cloud resources
      region = ENV.fetch('AWS_REGION', 'us-west-2')

      PARAMETER_STORE = ParameterStorage::Factory.create_parameter_store(cloud_provider, region:)

      nosql_args = {
        table: ENV.fetch('NOSQL_TABLE', 'dmsp-local'),
        size: ENV.fetch('NOSQL_POOL_SIZE', 3),
        timeout: ENV.fetch('NOSQL_TIMEOUT', 5),
        connection: { region: }
      }
      NOSQL_ADAPTER = NosqlAdapter::Factory.create_adapter(cloud_provider, nosql_args)
    end
  end
end
