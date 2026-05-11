# frozen_string_literal: true

module ButterflyNet
  module Middleware
    # Rack middleware to intercept exceptions from the entire Rails stack.
    # This catches errors before they propagate up, allowing the error tracking
    # dashboard to capture and record all application errors.
    #
    # Exceptions are captured through two mechanisms:
    # 1. As Rack middleware - catches exceptions that propagate up the stack
    # 2. As DebugExceptions interceptor - catches exceptions that are rendered
    #    as error pages without being re-raised (e.g., in development mode)
    class ExceptionCatcher
      # Default sensitive parameter keys to filter
      FILTERED_PARAMS = %w[
        password password_confirmation
        secret token api_key
        access_token refresh_token
        credit_card card_number cvv
        ssn social_security
      ].freeze

      FILTER_VALUE = "[FILTERED]"

      class << self
        # Handles exceptions intercepted by ActionDispatch::DebugExceptions.
        # This is called for exceptions that are rendered as error pages
        # without being re-raised to the middleware stack.
        # @param exception [Exception] The exception that was raised
        # @param env [Hash] The Rack environment hash
        def handle_intercepted_exception(exception, env)
          handler = new(nil)
          handler.capture_and_persist(exception, env)
        end
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue Exception => exception # rubocop:disable Lint/RescueException
        # Only handle if not already handled by interceptor
        unless env["butterfly_net.exception_handled"]
          capture_and_persist(exception, env)
        end
        raise
      end

      # Captures and persists an exception with its environment context.
      # This is a public method to allow the class method to call it without
      # breaking encapsulation via send.
      # @param exception [Exception] The exception that was raised
      # @param env [Hash] The Rack environment hash
      def capture_and_persist(exception, env)
        # Mark as handled to prevent duplicate logging
        env["butterfly_net.exception_handled"] = true
        ButterflyNet.report_error(
          exception,
          env: env,
          metadata: { request_params: extract_request_params(env) }
        )
      end

      private

      def persist_exception(exception, env)
        ButterflyNet.persist_error(exception, env, extract_request_params(env))
      end

      def extract_request_params(env)
        request = Rack::Request.new(env)
        {
          path: request.path,
          method: request.request_method,
          query_string: filter_query_string(request.query_string),
          params: filter_params(safe_params(request))
        }
      end

      def safe_params(request)
        request.params
      rescue StandardError
        {}
      end

      def filter_params(params, depth = 0)
        return params if depth > 10 # Prevent infinite recursion
        return params unless params.is_a?(Hash)

        params.each_with_object({}) do |(key, value), filtered|
          key_str = key.to_s.downcase
          if sensitive_key?(key_str)
            filtered[key] = FILTER_VALUE
          elsif value.is_a?(Hash)
            filtered[key] = filter_params(value, depth + 1)
          else
            filtered[key] = value
          end
        end
      end

      def filter_query_string(query_string)
        return query_string if query_string.blank?

        pairs = query_string.split("&").map do |pair|
          key, value = pair.split("=", 2)
          if key && sensitive_key?(key.downcase)
            "#{key}=#{FILTER_VALUE}"
          else
            pair
          end
        end
        pairs.join("&")
      end

      def sensitive_key?(key)
        FILTERED_PARAMS.any? { |sensitive| key.include?(sensitive) }
      end
    end
  end
end
