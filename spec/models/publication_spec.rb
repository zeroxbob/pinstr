require 'rails_helper'

RSpec.describe Publication, type: :model do
  let(:user) { User.create!(username: "testuser", public_key: "testpubkey") }
  let(:bookmark) { Bookmark.create!(user: user, url: "https://example.com", title: "Test", event_id: "test123") }
  let(:relay) { Relay.create!(url: "wss://test.relay") }
  
  describe "validations" do
    it "requires a bookmark" do
      publication = Publication.new(relay: relay, published_at: Time.current)
      expect(publication).not_to be_valid
      expect(publication.errors[:bookmark]).to include("must exist")
    end
    
    it "requires a relay" do
      publication = Publication.new(bookmark: bookmark, published_at: Time.current)
      expect(publication).not_to be_valid
      expect(publication.errors[:relay]).to include("must exist")
    end
    
    it "requires a published_at timestamp" do
      publication = Publication.new(bookmark: bookmark, relay: relay)
      expect(publication).not_to be_valid
      expect(publication.errors[:published_at]).to include("can't be blank")
    end
    
    it "requires a unique bookmark and relay combination" do
      Publication.create!(bookmark: bookmark, relay: relay, published_at: Time.current)
      publication = Publication.new(bookmark: bookmark, relay: relay, published_at: Time.current)
      expect(publication).not_to be_valid
      expect(publication.errors[:bookmark_id]).to include("has already been taken")
    end
  end
  
  describe ".record_publication" do
    it "creates a new publication record" do
      expect {
        Publication.record_publication(bookmark, relay, true)
      }.to change(Publication, :count).by(1)
      
      publication = Publication.last
      expect(publication.bookmark).to eq(bookmark)
      expect(publication.relay).to eq(relay)
      expect(publication.success).to be true
      expect(publication.published_at).to be_within(1.second).of(Time.current)
    end
    
    it "updates an existing publication record" do
      original = Publication.create!(bookmark: bookmark, relay: relay, published_at: 1.day.ago, success: true)
      
      expect {
        Publication.record_publication(bookmark, relay, false, "Error message")
      }.not_to change(Publication, :count)
      
      original.reload
      expect(original.success).to be false
      expect(original.error_message).to eq("Error message")
      expect(original.published_at).to be_within(1.second).of(Time.current)
    end
  end
  
  describe "scopes" do
    before do
      Publication.create!(bookmark: bookmark, relay: relay, published_at: Time.current, success: true)
      Publication.create!(
        bookmark: bookmark, 
        relay: Relay.create!(url: "wss://failed.relay"), 
        published_at: Time.current, 
        success: false,
        error_message: "Failed to connect"
      )
    end
    
    it "returns successful publications" do
      expect(Publication.successful.count).to eq(1)
      expect(Publication.successful.first.success).to be true
    end
    
    it "returns failed publications" do
      expect(Publication.failed.count).to eq(1)
      expect(Publication.failed.first.success).to be false
      expect(Publication.failed.first.error_message).to eq("Failed to connect")
    end
  end
end
