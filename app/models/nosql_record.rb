# frozen_string_literal: true

# Base class for a model whose backend is a NoSQL database
class NosqlRecord
  def initialize(**args)
    @client = Aws::Dynamo.new(**args)
  end

  protected

  attr_reader :client
  attr_accessor :partion_key, :sort_key
end
