require 'aws-sdk-secretsmanager'

# Skip this if the environment is our local Docker dev container
unless Rails.env.docker?
  # Determine the env and then fetch the RDS secret
  env = Rails.env.production? ? 'prd' : (Rails.env.staging? ? 'stg' : 'dev')
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

pp secret_hash

      ENV['DATABASE_HOST'] = secret_hash['host']
      ENV['DATABASE_PORT'] = secret_hash['port']
      ENV['DATABASE_USERNAME'] = secret_hash['username']
      ENV['DATABASE_PASSWORD'] = secret_hash['password']
      ENV['DATABASE_NAME'] = secret_hash['dbname']
      ENV['AUTHN_CLIENT_ID'] = secret_hash['']
      ENV['AUTHN_CLIENT_SECRET'] = secret_hash['']
    end
  end
end
