describe 'Sources API' do
  fixtures :sources

  it 'sends a paginated list of sources' do
    get '/sources'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(3)
    expect(json['data'].length).to eq(3)
  end

  it 'sends a source when requested by GID' do
    get '/sources/proiel:20180408:pal-agr'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['id']).to eq('proiel:20180408:pal-agr')
    expect(json['title']).to eq('Opus agriculturae')
    expect(json['language']).to eq('lat')
    expect(json['chunks']).to eq([2037, 2038, 2039, 2040, 2041, 2042, 2043, 2044, 2045, 2046, 2047, 2048, 2049, 2050, 2051, 2052, 2053, 2054, 2055])
  end
end
