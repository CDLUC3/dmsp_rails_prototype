# frozen_string_literal: true

# AuthN Event
class Event < ApplicationRecord
  belongs_to :user

  # Include the user agent and IP in the log
  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
