describe "Sources API" do
  fixtures :sources

  it 'sends a paginated list of sources' do
    get '/sources'
    expect(response).to be_success
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(3)
    expect(json['data'].length).to eq(3)
  end
end
