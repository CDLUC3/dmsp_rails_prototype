Rails.application.routes.draw do
  post "sign_in", to: "sessions#create"
  post "sign_up", to: "registrations#create"
  resources :sessions, only: [:index, :show, :destroy]
  resource  :password, only: [:edit, :update]
  namespace :identity do
    resource :email,              only: [:edit, :update]
    resource :email_verification, only: [:show, :create]
    resource :password_reset,     only: [:new, :edit, :create, :update]
  end
  namespace :authentications do
    resources :events, only: :index
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :tags

  resources :dmps

  # Cognito authentication tokens
  get "token", controller: :tokens_controller, action: :exchange_code_for_token

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Default to the Rails API Healthcheck
  root "rails/health#show"
end
