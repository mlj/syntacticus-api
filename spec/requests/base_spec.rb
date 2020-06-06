describe 'Base API' do
  it 'responds with a robots.txt' do
    get '/robots.txt'
    expect(response).to be_success
    expect(response.body).to eq("User-agent: *\nDisallow: /\n")
  end
end
