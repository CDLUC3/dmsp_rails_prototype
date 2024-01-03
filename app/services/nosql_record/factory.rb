# frozen_string_literal: true

module NosqlRecord
  # Factory to create the NoSQL database adapter
  class Factory
    def self.create_record(provider)
      case provider
      when :aws
        NosqlRecord::AwsDynamoDbRecord.new
      else
        raise ArgumentError, "Unsupported NoSQL database provider"
      end
    end
  end
end
