# frozen_string_literal: true

require 'aws-sdk-ssm'

module ParamaterStorage
  # Create a thread safe pool of connections for SSM. The available initialization args are:
  #   - region: region_name,
  #   - credentials: Aws::Credentials
  #
  class AwsSsm < Storage
    attr_accessor :client

    def initialize(**args)
      @client = Aws::SSM::Client.new(**args)
    end

    # Fetch the value for the given key from SSM
    def get(key)
      resp = @client.get_parameter(name: key, with_decryption: true)
      Rails.logger.debug("Searching for SSM Key: #{key}, Found: '#{resp&.parameter&.value}'")
      resp.nil? || resp.parameter.nil? ? nil : resp.parameter.value
    end
  end
end
