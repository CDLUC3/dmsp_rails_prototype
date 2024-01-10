# frozen_string_literal: true

# An interface for a NoSQL database record
#
# If you are using a cloud provider other than AWS, you will need to:
# - create a version of the `adapter.rb` and `item.rb` classes in the `app/services/nosql/` dir
# - update this class to inherit from your new `item.rb`
# - update the `_adapter_args` function in this file
# - update the `initialize` function in this file to use your new `adapter.rb`
class NosqlRecord < Nosql::AwsDynamodbItem
  attr_reader :adapter, :key, :versions, :errors
  attr_accessor :metadata

  def initialize(**args)
    @versions = []
    @errors = []
    @metadata = {}
    @adapter = Nosql::AwsDynamodbAdapter.new(**_adapter_args)
  end

end
