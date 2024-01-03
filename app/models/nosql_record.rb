# frozen_string_literal: true

# An interface for a NoSQL database record
class NosqlRecord
  attr_reader :key, :versions, :errors
  attr_accessor :metadata

  def initialize(**args)
    @versions = []
    @errors = []
    @metadata = {}
  end
end
