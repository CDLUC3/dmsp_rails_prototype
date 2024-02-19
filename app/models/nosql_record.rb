# frozen_string_literal: true

# An interface for a NoSQL database record
#
# If you are using a cloud provider other than AWS, you will need to:
# - create a version of the `adapter.rb` and `item.rb` classes in the `app/services/nosql/` dir
# - update this class to inherit from your new `item.rb`
# - update the `initialize` function in this file to use your new `adapter.rb`
#
# Any models that inherit from this class should override the `initialize` method and initialize
# the NoSQL DB adapter. For example:
#
#   def initialize(**args)
#     @adapter = Nosql::DynamodbDmpAdapter.new(**{ table: ENV['NOSQL_DMPS_TABLE'] })
#
#     super(**args)
#   end
#
class NosqlRecordError < StandardError; end

class NosqlRecord < Nosql::DynamodbDmpItem
  attr_reader :adapter, :key, :errors
  attr_accessor :metadata

  MSG_NO_ADAPTER_DEFINED = 'No NoSQL adapter defined! Please define `@adapter` in your `initializer`!'

  def initialize(**args)
    raise NosqlRecordError, MSG_NO_ADAPTER_DEFINED if @adapter.nil?

    @errors = []
    @metadata = {}
  end
end
