MarcoButterflyNet::Engine.routes.draw do
  resources :dashboard, only: [ :index, :show ]
  root to: "dashboard#index"
end
