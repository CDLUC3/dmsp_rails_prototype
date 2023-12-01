# frozen_string_literal: true

require 'aws-sdk-ssm'

module Aws
  # AWS SSM Parameter Store helper
  class Ssm
    # Call SSM to get the value for the specified key
    def fetch_value(key:)
      resp = Aws::SSM::Client.new.get_parameter(name: key, with_decryption: true)
      Rails.logger.debug("Searching for SSM Key: #{key}, Found: '#{resp&.parameter&.value}'")
      resp.nil? || resp.parameter.nil? ? nil : resp.parameter.value
    end
  end
end
