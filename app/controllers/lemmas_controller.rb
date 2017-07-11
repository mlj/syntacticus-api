class LemmasController < ApplicationController
  def index
    dictionary = Dictionary.find_by_gid(params[:dictionary_id])
    
    lemmas = dictionary.lemmas
    lemmas = lemmas.where('lemma LIKE ?', params[:lemma].gsub('.', '_').gsub('*', '%')) if params[:lemma]
    lemmas = lemmas.where(part_of_speech: params[:part_of_speech]) if params[:part_of_speech]

    render json: paginator(lemmas, lambda { |lemma| {
      lemma: lemma.lemma,
      part_of_speech: lemma.part_of_speech,
      glosses: JSON.parse(lemma.glosses),
    }})
  end

  def show
    dictionary = Dictionary.find_by_gid(params[:dictionary_id])
    lemma = dictionary.lemmas.find_by_lemma_and_part_of_speech(*params[:id].split(':'))

    render json: {}.merge(JSON.parse(lemma.data))
  end
end
