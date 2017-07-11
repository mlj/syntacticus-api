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
    }
  end
end
