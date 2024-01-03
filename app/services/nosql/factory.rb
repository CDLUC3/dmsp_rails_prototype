# frozen_string_literal: true

module Nosql
  # Factory to create the NoSQL database adapter
  class Factory
    def self.create_adapter(provider, args)
      case provider
      when :aws
        Nosql::AwsDynamodbAdapter.new(**args)
      else
        raise ArgumentError, "Unsupported NoSQL database provider"
      end
    end
  end
end
