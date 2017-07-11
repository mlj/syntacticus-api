class ChunksController < ApplicationController
  def show
    chunk = Chunk.find(params[:id])

    render json: JSON.parse(chunk.data)
  end
end
