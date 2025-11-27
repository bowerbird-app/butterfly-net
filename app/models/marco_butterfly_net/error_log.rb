# frozen_string_literal: true

module MarcoButterflyNet
  # Model for storing captured exception data from the error tracking middleware.
  # Each record represents a single exception that was caught during a request.
  class ErrorLog < ApplicationRecord
    validates :exception_class, presence: true

    # Returns backtrace as array (handles text storage)
    def backtrace_lines
      return [] if backtrace.blank?

      backtrace.split("\n")
    end

    # Returns request_params as hash (with safety for nil values)
    def params_hash
      request_params || {}
    end

    # Scope for recent errors
    scope :recent, -> { order(created_at: :desc) }

    # Scope for filtering by exception class
    scope :by_exception_class, ->(klass) { where(exception_class: klass) }
  end
end
