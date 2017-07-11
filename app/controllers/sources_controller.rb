class SourcesController < ApplicationController
  def index
    sources = Source

    render json: paginator(sources, lambda { |source| shared(source) })
  end

  def show
    source = Source.find_by_gid(params[:id])
    raise ActiveRecord::RecordNotFound if source.nil?

    render json: shared(source).merge({
      chunks: JSON.parse(source.chunks),
      aligned_chunks: JSON.parse(source.aligned_chunks),
    })
  end

  private

  def shared(source)
    {
      id: source.gid,
      aligned_gid: source.aligned_gid,
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
