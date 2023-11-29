require 'aws-sdk-secretsmanager'

puts ENV['RAILS_ENV']

# Skip this if the environment is our local Docker dev container
unless ENV['RAILS_ENV'] == 'docker'
  # Determine the env and then fetch the RDS secret
  env = ENV['RAILS_ENV'] == 'production' ? 'prd' : (ENV['RAILS_ENV'] == 'stage' ? 'stg' : 'dev')
  secret_name = "dmp-hub-#{env}-rails-app"
  client = Aws::SecretsManager::Client.new(region: ENV.fetch('AWS_REGION', 'us-west-2'))

  begin
    get_secret_value_response = client.get_secret_value(secret_id: secret_name)
  rescue Aws::SecretsManager::Errors::DecryptionFailure => e
    raise
  rescue Aws::SecretsManager::Errors::InternalServiceError => e
    raise
  rescue Aws::SecretsManager::Errors::InvalidParameterException => e
    raise
  rescue Aws::SecretsManager::Errors::InvalidRequestException => e
    raise
  rescue Aws::SecretsManager::Errors::ResourceNotFoundException => e
    raise
  else
    if get_secret_value_response.secret_string
      secret_json = get_secret_value_response.secret_string
      secret_hash = JSON.parse(secret_json)

      ENV['DATABASE_HOST'] = secret_hash['host']
      ENV['DATABASE_PORT'] = secret_hash['port']
      ENV['DATABASE_USERNAME'] = secret_hash['username']
      ENV['DATABASE_PASSWORD'] = secret_hash['password']
      ENV['DATABASE_NAME'] = secret_hash['dbname']
    end
  end
end
