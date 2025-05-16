require "rails_helper"

RSpec.describe Bookmark, type: :model do
  before(:all) do
    User.create!(id: 1, email: "test@example.com", public_key: "some_key") unless User.exists?(1)
  end
  
  before(:each) do
    # Clean up any test bookmarks before each test
    Bookmark.where(url: "https://example.com").destroy_all
  end

  subject(:bookmark) { described_class.new(user_id: 1, url: "https://example.com", title: "Example Title", event_id: "unique_event_id") }

  it "is valid with valid attributes" do
    expect(bookmark).to be_valid
  end

  it "requires url" do
    bookmark.url = nil
    expect(bookmark).not_to be_valid
  end

  it "requires title" do
    bookmark.title = nil
    expect(bookmark).not_to be_valid
  end

  it "requires event_id" do
    bookmark.event_id = nil
    expect(bookmark).not_to be_valid
  end

  it "requires event_id to be unique" do
    described_class.create!(user_id: 1, url: "https://example.org", title: "DupeTitle", event_id: "dupe_event")
    bookmark.event_id = "dupe_event"
    expect(bookmark).not_to be_valid
  end
end

# Tests for the event publication callback
describe 'callbacks' do
  let(:user) { User.create!(username: "testuser", public_key: "testpubkey") }
  let(:valid_signed_event) do
    {
      id: 'test123',
      pubkey: user.public_key,
      content: 'Test Bookmark',
      created_at: Time.now.to_i,
      kind: 30001,
      tags: []
    }.to_json
  end

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'schedules event publication after create' do
    bookmark = Bookmark.new(
      user: user,
      url: 'https://example.com/testurl',
      title: 'Test',
      event_id: 'test123',
      signed_event_content: valid_signed_event
    )

    expect {
      bookmark.save!
    }.to have_enqueued_job(PublishNostrEventJob)
  end

  it 'does not schedule event publication if signed_event_content is blank' do
    bookmark = Bookmark.new(
      user: user,
      url: 'https://example.com/testurl2',
      title: 'Test',
      event_id: 'test456'
    )

    expect {
      bookmark.save!
    }.not_to have_enqueued_job(PublishNostrEventJob)
  end

  it 'handles JSON parsing errors gracefully' do
    allow(Rails.logger).to receive(:error)

    bookmark = Bookmark.new(
      user: user,
      url: 'https://example.com/testurl3',
      title: 'Test',
      event_id: 'test789',
      signed_event_content: 'invalid json'
    )

    expect {
      bookmark.save!
    }.not_to raise_error

    expect(Rails.logger).to have_received(:error).with(/Failed to parse signed event content/)
  end
end