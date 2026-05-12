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
    def error(error_or_message, context = nil, **metadata)
      report_error(error_or_message, context: context, metadata: metadata)
    end

    def current_request_env
      Thread.current[:butterfly_net_current_request_env]
    end

    def with_current_request_env(env)
      previous_env = current_request_env
      Thread.current[:butterfly_net_current_request_env] = env
      yield
    ensure
      Thread.current[:butterfly_net_current_request_env] = previous_env
    end

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

    def report_error(error_or_message, env: {}, context: nil, metadata: {})
      payload = build_error_payload(error_or_message, context: context, metadata: metadata)
      exception = payload[:exception]

      capture_exception(exception, env)
      persist_error(exception, env, payload[:request_params])
      exception
    end

    def persist_error(exception, env, request_params = nil)
      ButterflyNet::ErrorLog.find_or_create_with_occurrence(
        exception_class: exception.class.name,
        message: exception.message,
        backtrace: exception.backtrace&.join("\n"),
        user_id: env["error_tracking.user_id"],
        user_email: env["error_tracking.user_email"],
        request_params: request_params,
        user_agent: env["HTTP_USER_AGENT"]
      )
    rescue StandardError => e
      # Don't let persistence failures crash the app
      Rails.logger.error "[ButterflyNet] Failed to persist error: #{e.message}"
    end

    private

    def build_error_payload(error_or_message, context:, metadata:)
      explicit_request_params = metadata[:request_params]
      exception = extract_exception(error_or_message, metadata)
      message = build_message(error_or_message, exception, metadata)

      exception = build_exception(exception, message)

      {
        exception: exception,
        request_params: build_request_params(context, metadata, explicit_request_params)
      }
    end

    def extract_exception(error_or_message, metadata)
      return error_or_message if error_or_message.is_a?(Exception)

      metadata[:error] if metadata[:error].is_a?(Exception)
    end

    def build_message(error_or_message, exception, metadata)
      return error_or_message if error_or_message.is_a?(String)
      return exception.message if exception

      metadata[:message] || error_or_message.to_s
    end

    def build_exception(source_exception, message)
      return source_exception if source_exception.is_a?(Exception) && source_exception.message == message

      exception_class = source_exception&.class || StandardError
      exception = exception_class.new(message)
      exception.set_backtrace(source_exception&.backtrace) if source_exception&.backtrace
      exception
    end

    def build_request_params(context, metadata, explicit_request_params)
      payload = default_request_params
      payload = merge_request_params(payload, explicit_request_params.deep_dup) if explicit_request_params.is_a?(Hash)
      payload[:context] = context unless context.nil?

      structured_metadata = metadata.except(:error, :message, :request_params)
      payload[:metadata] = structured_metadata if structured_metadata.present?

      payload.presence
    end

    def default_request_params
      env = current_request_env
      return {} unless env.is_a?(Hash)

      ButterflyNet::Middleware::ExceptionCatcher.extract_request_params(env)
    rescue StandardError
      {}
    end

    def merge_request_params(base_payload, explicit_payload)
      base_payload.deep_merge(explicit_payload)
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
