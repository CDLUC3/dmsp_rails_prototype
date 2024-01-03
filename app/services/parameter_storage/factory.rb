# frozen_string_literal: true

module ParameterStorage
  # Factory to create the appropriate ParamaterStore instance
  class Factory
    def self.create_store(provider)
      case provider
      when :aws
        ParamaterStorage::AwsSsm.new
      when :standard
        ParamaterStorage::Standard.new
      else
        raise ArgumentError, "Unsupported storage provider"
      end
    end
  end
end
