require 'test_helper'

class ChunksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chunk = chunks(:one)
  end

  test "should show chunk" do
    get chunk_url(@chunk), as: :json
    assert_response :success
  end
end
