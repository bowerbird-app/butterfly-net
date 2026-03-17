# frozen_string_literal: true

module ButterflyNet
  # Model for tracking individual occurrences of an error.
  # Each occurrence captures when and for which user an error happened.
  class ErrorOccurrence < ApplicationRecord
    belongs_to :error_log

    # Scope for recent occurrences
    scope :recent, -> { order(created_at: :desc) }

    # Scope for filtering by user_id
    scope :for_user, ->(user_id) { where(user_id: user_id) }

    # Scope for filtering by user_email
    scope :for_user_email, ->(email) { where(user_email: email) }

    # Returns request_params as hash (with safety for nil values)
    def params_hash
      request_params || {}
    end
  end
end
