# frozen_string_literal: true

# A user (human) of the system. Using Rails 7.1+ AuthN helpers
class User < ApplicationRecord
  has_secure_password

  # Use short-lived tokens for account verification and password reets
  generates_token_for :email_verification, expires_in: 2.days do
    email
  end
  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end

  # Users have sessions and AuthN log events
  has_many :sessions, dependent: :destroy
  has_many :events, dependent: :destroy

  # Validate the emails and passwords
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, allow_nil: true, length: { minimum: 12 }

  # Always set the email to lowercase before saving
  normalizes :email, with: -> { _1.strip.downcase }

  # Force email confirmation when the user changes the email address
  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  # Invalidate all active sessions when the password changes
  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  # Log important AuthN events
  after_update if: :email_previously_changed? do
    events.create! action: "email_verification_requested"
  end

  after_update if: :password_digest_previously_changed? do
    events.create! action: "password_changed"
  end

  after_update if: [:verified_previously_changed?, :verified?] do
    events.create! action: "email_verified"
  end
end
