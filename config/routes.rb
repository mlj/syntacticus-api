Rails.application.routes.draw do
  resources :sentences, only: [:show]
  resources :sources, only: [:index, :show]
  resources :tokens, only: [:index]
  resources :dictionaries, only: [:index] do
    resources :lemmas, only: [:index, :show]
  end
  resources :chunks, only: [:show]
  resources :aligned_chunks, only: [:show]
end
