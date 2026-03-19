module ButterflyNet
  class Engine < ::Rails::Engine
    isolate_namespace ButterflyNet

    # Insert the exception catching middleware early in the stack
    # so it can intercept all exceptions from the entire Rails stack
    initializer "butterfly_net.middleware" do |app|
      app.middleware.insert_before(0, ButterflyNet::Middleware::ExceptionCatcher)
    end

    # Register as an interceptor with ActionDispatch::DebugExceptions
    # to catch exceptions that are rendered as error pages without being re-raised.
    # This ensures we capture all Rails errors including NameError, NoMethodError, etc.
    initializer "butterfly_net.debug_exceptions_interceptor", after: :load_config_initializers do
      ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
        ButterflyNet::Middleware::ExceptionCatcher.handle_intercepted_exception(exception, request.env)
      end
    end

    # Register the engine's importmap pins with the host application so that
    # Stimulus and the engine's JS controllers are available via importmap.
    initializer "butterfly_net.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << root.join("app/assets/javascripts")
      end
    end

    # Ensure importmap helpers are available in isolated engine views.
    initializer "butterfly_net.importmap_helper", after: "importmap.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper ::Importmap::ImportmapTagsHelper if defined?(::Importmap::ImportmapTagsHelper)
      end
    end
  end
end
