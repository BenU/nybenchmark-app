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
  
  resources :observations do
    member do
      get :verify
    end
  end  

  # Content pages
  get "methodology" => "pages#methodology"
  get "non-filers" => "pages#non_filers"

  # Comparison tools
  get "school-districts/compare" => "school_district_comparisons#show", as: :school_districts_compare
  get "counties/compare" => "county_comparisons#show", as: :counties_compare

  get "up" => "rails/health#show", as: :rails_health_check
  get "for-llms" => "welcome#for_llms"

  # Redirect sitemap to DO Spaces so GSC can discover it under app.nybenchmark.org
  get "sitemaps/sitemap.xml.gz", to: redirect("https://nybenchmark-production.nyc3.digitaloceanspaces.com/sitemaps/sitemap.xml.gz", status: 301)
end
