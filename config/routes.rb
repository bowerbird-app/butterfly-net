ButterflyNet::Engine.routes.draw do
  resources :dashboard, only: [ :index, :show ] do
    collection do
      get :grouped
    end

    member do
      post :fetch_blame
      post :create_issue
    end
  end

  # Analytics routes
  namespace :analytics do
    get "summary"
    get "top_errors"
    get "time_series"
    get "top_affected_users"
  end

  # Analytics dashboard view
  get "analytics", to: "dashboard#analytics"

  root to: "dashboard#index"
end
