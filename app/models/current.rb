# frozen_string_literal: true

# Represents a user's session (equivalent of Devise's `current_user`)
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_agent, :ip_address

  # Allows public facing User methods to be called via the Session (e.g. :email, but not :password)
  delegate :user, to: :session, allow_nil: true
end
