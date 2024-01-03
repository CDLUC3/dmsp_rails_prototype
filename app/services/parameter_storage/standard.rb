# frozen_string_literal: true

module ParamaterStorage
  # A generic ParameterStore class that fetches values from ENV
  class Standard < Storage
    # Just fetch the value from the environment variables
    def get(key)
      ENV[key.to_s]
    end
  end
end
