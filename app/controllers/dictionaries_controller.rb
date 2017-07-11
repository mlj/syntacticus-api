class DictionariesController < ApplicationController
  def index
    dictionaries = Dictionary

    render json: paginator(dictionaries, lambda { |dictionary| {
      id: dictionary.gid,
      language: dictionary.language,
      lemma_count: dictionary.lemma_count,
    }})
  end
end
