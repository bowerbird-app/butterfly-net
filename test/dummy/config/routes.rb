Rails.application.routes.draw do
  mount ButterflyNet::Engine => "/butterfly_net"

  # Redirect root to the error dashboard
  root to: redirect("/butterfly_net")

  # Test routes for integration testing (only in test environment)
  if Rails.env.test?
    get "/test/name_error" => "test_errors#name_error"
    get "/test/no_method_error" => "test_errors#no_method_error"
    get "/test/argument_error" => "test_errors#argument_error"
    get "/test/type_error" => "test_errors#type_error"
    get "/test/runtime_error" => "test_errors#runtime_error"
    get "/test/success" => "test_errors#success"
  end
end
