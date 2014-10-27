describe "CrowdWorks Engineer Blog", sauce: true do
  before :all do
    @pid = spawn('bundle exec middleman')
    sleep 10
  end

  after :all do
    Process.kill('HUP', @pid)
  end

  it "should list articles" do
    visit 'http://localhost:4567'
    #expect(page).to have_content "Middleman"
  end
end
