Rails.application.routes.draw do
  resources :sentences, only: [:show]
  resources :graphs, only: [:show]
  resources :aligned_graphs, only: [:show]
  resources :sources, only: %i[index show]
  resources :tokens, only: [:index]
  resources :dictionaries, only: [:index] do
    resources :lemmas, only: %i[index show]
  end
  resources :chunks, only: [:show]
  resources :aligned_chunks, only: [:show]
  get '/robots.txt' => 'robots_txts#show'
end
