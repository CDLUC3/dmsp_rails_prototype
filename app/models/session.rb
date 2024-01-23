# frozen_string_literal: true

# User session
class Session < ApplicationRecord
  belongs_to :user

  # Set the current user agent and IP for the session
  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end

  # Log sign in/out AuthN events
  after_create  { user.events.create! action: "signed_in" }
  after_destroy { user.events.create! action: "signed_out" }
end
