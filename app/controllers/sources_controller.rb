class SourcesController < ApplicationController
  def index
    sources = Source.where("gid LIKE 'torot:20180919:%' OR gid like 'iswoc:%' OR gid LIKE 'proiel:20180408:%'")

    render json: paginator(sources, ->(source) { shared(source) })
  end

  def show
    source = Source.find_by_gid(params[:id])
    raise ActiveRecord::RecordNotFound if source.nil?

    render json: shared(source).merge({
                                        chunks: JSON.parse(source.chunks),
                                        alignment: JSON.parse(source.alignment),
                                      })
  end

  private

  def shared(source)
    {
      id: source.gid,
      title: source.title,
      author: source.author,
      language: source.language,
      license: source.license,
      citation: source.citation,
      sentence_count: source.sentence_count,
      token_count: source.token_count,
    }
  end
end
