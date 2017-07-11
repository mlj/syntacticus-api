require 'test_helper'

class SourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @source = sources(:one)
  end

  test "should get index" do
    get sources_url, as: :json
    assert_response :success
  end

  #test "should show source" do
  #  get source_url(@source), as: :json
  #  assert_response :success
  #end
end
