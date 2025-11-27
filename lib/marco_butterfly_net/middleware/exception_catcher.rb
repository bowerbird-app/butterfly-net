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
        persist_exception(exception, env)
      end

      def persist_exception(exception, env)
        MarcoButterflyNet::ErrorLog.create!(
          exception_class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.join("\n"),
          request_params: extract_request_params(env),
          user_agent: env["HTTP_USER_AGENT"]
        )
      rescue StandardError => e
        # Don't let persistence failures crash the app
        Rails.logger.error "[MarcoButterflyNet] Failed to persist error: #{e.message}"
      end

      def extract_request_params(env)
        request = Rack::Request.new(env)
        {
          path: request.path,
          method: request.request_method,
          query_string: request.query_string,
          params: safe_params(request)
        }
      end

      def safe_params(request)
        request.params
      rescue StandardError
        {}
      end
    end
  end
end
