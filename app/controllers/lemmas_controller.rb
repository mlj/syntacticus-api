class LemmasController < ApplicationController
  def index
    lemmas = find_lemmas
    lemmas = lemmas.where('lemma LIKE ?', params[:lemma].gsub('.', '_').gsub('*', '%')) if params[:lemma]
    lemmas = lemmas.where(part_of_speech: params[:part_of_speech]) if params[:part_of_speech]

    render json: paginator(lemmas, lambda { |lemma|
      l, v = lemma.lemma.split('#')
      {
        lemma: l,
        variant: v,
        part_of_speech: lemma.part_of_speech,
        glosses: JSON.parse(lemma.glosses),
      }
    })
  end

  def show
    # FIXME: index variant numbers separately to avoid this
    l, p, v = params[:id].split(':')
    l = [l, v].compact.join('#')
    lemma = find_lemmas.find_by_lemma_and_part_of_speech!(l, p)

    render json: JSON.parse(lemma.data)
  end

  private

  def find_dictionary
    Dictionary.find_by_gid!(params[:dictionary_id])
  end

  def find_lemmas
    find_dictionary.lemmas
  end
end
