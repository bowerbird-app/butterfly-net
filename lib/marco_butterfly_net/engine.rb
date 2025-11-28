module MarcoButterflyNet
  class Engine < ::Rails::Engine
    isolate_namespace MarcoButterflyNet

    # Insert the exception catching middleware early in the stack
    # so it can intercept all exceptions from the entire Rails stack
    initializer "marco_butterfly_net.middleware" do |app|
      app.middleware.insert_before(0, MarcoButterflyNet::Middleware::ExceptionCatcher)
    end

    # Register as an interceptor with ActionDispatch::DebugExceptions
    # to catch exceptions that are rendered as error pages without being re-raised.
    # This ensures we capture all Rails errors including NameError, NoMethodError, etc.
    initializer "marco_butterfly_net.debug_exceptions_interceptor", after: :load_config_initializers do
      ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
        MarcoButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(exception, request.env)
      end
    end
  end
end
