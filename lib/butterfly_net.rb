require "butterfly_net/version"
require "butterfly_net/engine"
require "butterfly_net/configuration"
require "butterfly_net/middleware/exception_catcher"
require "butterfly_net/services/git_blame"
require "butterfly_net/services/github_issue_creator"
require "butterfly_net/services/analytics"
require "pagy"

module ButterflyNet
  class << self
    # Captures an exception with its environment context.
    # This is called by the middleware when an exception is caught.
    # @param exception [Exception] The exception that was raised
    # @param env [Hash] The Rack environment hash
    def capture_exception(exception, env)
      # Store exception data for the error tracking dashboard
      # This is a hook point for future implementation
      mutex.synchronize do
        captured_exceptions << {
          exception: exception,
          env: env,
          captured_at: Time.current
        }
      end
    end

    # Returns the list of captured exceptions (for dashboard display)
    # @return [Array<Hash>] Array of captured exception data
    def captured_exceptions
      @captured_exceptions ||= []
    end

    # Clears all captured exceptions
    def clear_captured_exceptions
      mutex.synchronize do
        @captured_exceptions = []
      end
    end

    private

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
