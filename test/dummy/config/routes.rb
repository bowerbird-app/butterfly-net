Rails.application.routes.draw do
  mount ButterflyNet::Engine => "/butterfly_net"

  # Redirect root to the error dashboard
  root to: redirect("/butterfly_net")

  # Test routes for exercising error capture in the dummy app.
  if Rails.env.development? || Rails.env.test?
    get "/test" => "test_errors#index"
    get "/test/name_error" => "test_errors#name_error"
    get "/test/no_method_error" => "test_errors#no_method_error"
    get "/test/argument_error" => "test_errors#argument_error"
    get "/test/type_error" => "test_errors#type_error"
    get "/test/runtime_error" => "test_errors#runtime_error"
    get "/test/handled_runtime_error" => "test_errors#handled_runtime_error"
    get "/test/unhandled_runtime_error" => "test_errors#unhandled_runtime_error"
    get "/test/success" => "test_errors#success"
  end
end
