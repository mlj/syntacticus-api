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
      # FIXME
      tokens: JSON.parse(sentence.tokens).map do |t|
        l = t['lemma']

        if l
          l = l.split('#')
          t.merge({
                    'lemma' => l[0],
                    'variant' => l[1],
                  })
        else
          t
        end
      end,
      previous_gid: sentence.previous_gid,
      next_gid: sentence.next_gid,
      source: {
        id: sentence.source.gid,
        aligned_gid: JSON.parse(sentence.source.alignment)[:gid],
        title: sentence.source.title,
        author: sentence.source.author,
        license: sentence.source.license,
      },
    }
  end
end
