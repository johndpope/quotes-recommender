Rails.application.routes.draw do
  resources :ratings, only: [:update]
  resources :categories
  resources :quotes
  resources :viewed_quotes, only: [:index] do
    get 'filter/:name' => 'viewed_quotes#filter', on: :collection
  end
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  resources :users, only: [:index, :show, :update]

  get 'home/about'
  get 'home/index'
  get 'home/welcome'
  root 'home#welcome'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
