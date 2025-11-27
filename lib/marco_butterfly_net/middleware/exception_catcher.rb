# frozen_string_literal: true

module MarcoButterflyNet
  module Middleware
    # Rack middleware to intercept exceptions from the entire Rails stack.
    # This catches errors before they propagate up, allowing the error tracking
    # dashboard to capture and record all application errors.
    class ExceptionCatcher
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue Exception => exception # rubocop:disable Lint/RescueException
        handle_exception(exception, env)
        raise
      end

      private

      def handle_exception(exception, env)
        MarcoButterflyNet.capture_exception(exception, env)
      end
    end
  end
end
