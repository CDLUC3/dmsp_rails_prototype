# frozen_string_literal: true

module ParamaterStorage
  # A generic ParameterStorage class
  class Storage
    def get(key)
      raise NotImplementedError, "Subclasses must implement this method"
    end
  end
end