class ApplicationController < ActionController::API
  protected

  def paginator(data, mapper, max_limit = 100)
    total = data.count

    offset = params[:offset].to_i
    limit = params[:limit].to_i

    offset = 0 unless offset.positive? and offset < total
    limit = max_limit unless limit.positive? and limit < max_limit

    {
      offset: offset,
      limit: limit,
      total: data.count,
      data: data.offset(offset).limit(limit).map { |token| mapper.call(token) },
    }
  end
end
