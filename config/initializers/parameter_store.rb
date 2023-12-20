# frozen_string_literal: true

if Rails.env.docker?
  # We are running in the local Docker dev env, so there is nothing to do here, the parameters
  # are loaded from the .env file.
  Rails.logger.info 'Running in the docker environment, fetching config parameters from .env'
else
  # We are running in the AWS Cloud, so fetch our parameters from SSM
  Rails.logger.info "Running in the #{Rails.env} environment, fetching config parameters from SSM"
end
