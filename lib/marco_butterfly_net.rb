require "marco_butterfly_net/version"
require "marco_butterfly_net/engine"
require "marco_butterfly_net/middleware/exception_catcher"

module MarcoButterflyNet
  class << self
    # Captures an exception with its environment context.
    # This is called by the middleware when an exception is caught.
    # @param exception [Exception] The exception that was raised
    # @param env [Hash] The Rack environment hash
    def capture_exception(exception, env)
      # Store exception data for the error tracking dashboard
      # This is a hook point for future implementation
      captured_exceptions << {
        exception: exception,
        env: env,
        captured_at: Time.now
      }
    end

    # Returns the list of captured exceptions (for dashboard display)
    # @return [Array<Hash>] Array of captured exception data
    def captured_exceptions
      @captured_exceptions ||= []
    end

    # Clears all captured exceptions
    def clear_captured_exceptions
      @captured_exceptions = []
    end
  end
end
