module MarcoButterflyNet
  class Engine < ::Rails::Engine
    isolate_namespace MarcoButterflyNet

    # Insert the exception catching middleware early in the stack
    # so it can intercept all exceptions from the entire Rails stack
    initializer "marco_butterfly_net.middleware" do |app|
      app.middleware.insert_before(0, MarcoButterflyNet::Middleware::ExceptionCatcher)
    end
  end
end
