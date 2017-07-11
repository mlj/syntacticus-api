class AlignedChunksController < ApplicationController
  def show
    chunk = AlignedChunk.find(params[:id])

    render json: JSON.parse(chunk.data)
  end
end
