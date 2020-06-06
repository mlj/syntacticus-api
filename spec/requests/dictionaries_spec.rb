describe 'Dictionaries API' do
  fixtures :dictionaries
  fixtures :lemmas

  it 'sends a paginated list of dictionaries' do
    get '/dictionaries'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(3)
    expect(json['data'].length).to eq(3)
  end

  it 'sends a paginated list of lemmas' do
    get '/dictionaries/syntacticus:20180920:lat/lemmas'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(2)
    expect(json['data'].length).to eq(2)

    expect(json['data'][0]['lemma']).to eq('(h)arena')
    expect(json['data'][0]['part_of_speech']).to eq('Nb')
    expect(json['data'][0]['glosses']).to eq({})

    expect(json['data'][1]['lemma']).to eq('Aaron')
    expect(json['data'][1]['part_of_speech']).to eq('Ne')
    expect(json['data'][1]['glosses']).to eq({})
  end

  it 'sends a paginated list of lemmas filtered by part of speech' do
    get '/dictionaries/syntacticus:20180920:lat/lemmas?part_of_speech=Ne'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(1)
    expect(json['data'].length).to eq(1)

    expect(json['data'][0]['lemma']).to eq('Aaron')
    expect(json['data'][0]['part_of_speech']).to eq('Ne')
    expect(json['data'][0]['glosses']).to eq({})
  end

  it 'sends a paginated list of lemmas filtered by lemma' do
    get '/dictionaries/syntacticus:20180920:lat/lemmas?lemma=.*rena'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(1)
    expect(json['data'].length).to eq(1)

    expect(json['data'][0]['lemma']).to eq('(h)arena')
    expect(json['data'][0]['part_of_speech']).to eq('Nb')
    expect(json['data'][0]['glosses']).to eq({})
  end

  it 'sends a paginated list of lemmas filtered by lemma and part of speech' do
    get '/dictionaries/syntacticus:20180920:lat/lemmas?lemma=.*r.*&part_of_speech=Ne'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['offset']).to eq(0)
    expect(json['limit']).to eq(100)
    expect(json['total']).to eq(1)
    expect(json['data'].length).to eq(1)

    expect(json['data'][0]['lemma']).to eq('Aaron')
    expect(json['data'][0]['part_of_speech']).to eq('Ne')
    expect(json['data'][0]['glosses']).to eq({})
  end

  it 'sends a lemma when requested by GID' do
    get '/dictionaries/syntacticus:20180920:lat/lemmas/Aaron:Ne'
    expect(response).to be_successful
    json = JSON.parse(response.body)

    expect(json['lemma']).to eq('Aaron')
    expect(json['language']).to eq('lat')
    expect(json['part_of_speech']).to eq('Ne')
  end
end
