# frozen_string_literal: true

# Concern that provides hooks to an external parameter store
module ExternalParameters
  extend ActiveSupport::Concern

  included do
    def fetch(key:)
      return nil unless key.is_a?(String) && !key.empty?

      Aws::Ssm.fetch_value(key:)
    end
  end
end
