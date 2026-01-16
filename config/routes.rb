Rails.application.routes.draw do
  root "welcome#index"

  # Unscoped Devise routes:
  # /sign_in, /sign_out, /sign_up, /password/*, /confirmation/*, etc.
  devise_for :users, path: "", path_names: {
    sign_in: "sign_in",
    sign_out: "sign_out",
    sign_up: "sign_up"
  }

  resources :entities,  param: :slug
  resources :documents
  resources :metrics
  resources :observations, only: [:index, :show]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
