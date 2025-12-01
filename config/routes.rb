MarcoButterflyNet::Engine.routes.draw do
  resources :dashboard, only: [ :index, :show ] do
    member do
      post :fetch_blame
      post :create_issue
    end
  end
  root to: "dashboard#index"
end
