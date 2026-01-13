Rails.application.routes.draw do
  root "welcome#index"

  devise_for :users

  resources :entities, only: [:index, :show], param: :slug
  resources :documents, only: [:index, :new, :create, :show]
  resources :metrics, only: [:index, :show]
  resources :observations, only: [:index, :show]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
