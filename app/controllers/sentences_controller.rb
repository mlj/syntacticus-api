class SentencesController < ApplicationController
  def show
    sentence = Sentence.find_by_gid(params[:id])
    render json: shared(sentence)
  end

  private

  def shared(sentence)
    {
      id: sentence.gid,
      text: sentence.text,
      language: sentence.language,
      citation: sentence.citation,
      tokens: JSON.parse(sentence.tokens),
      previous_gid: sentence.previous_gid,
      next_gid: sentence.next_gid,
      source: {
        id: sentence.source.gid,
        aligned_gid: sentence.source.aligned_gid,
        title: sentence.source.title,
        author: sentence.source.author,
        license: sentence.source.license,
      }
    }
  end
end
