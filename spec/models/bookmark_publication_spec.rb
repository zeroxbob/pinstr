require 'rails_helper'

RSpec.describe Bookmark, type: :model do
  let(:user) { User.create!(username: "testuser", public_key: "testpubkey") }
  let(:bookmark) { Bookmark.create!(user: user, url: "https://example.com", title: "Test", event_id: "test123") }
  let(:relay) { Relay.create!(url: "wss://test.relay") }
  
  describe "publication methods" do
    describe "#record_publication" do
      it "creates a publication record" do
        expect {
          bookmark.record_publication(relay, true)
        }.to change(Publication, :count).by(1)
        
        publication = Publication.last
        expect(publication.bookmark).to eq(bookmark)
        expect(publication.relay).to eq(relay)
        expect(publication.success).to be true
      end
    end
    
    describe "#published_to_relay?" do
      it "returns true if the bookmark was successfully published to the relay" do
        Publication.create!(bookmark: bookmark, relay: relay, published_at: Time.current, success: true)
        expect(bookmark.published_to_relay?(relay)).to be true
      end
      
      it "returns false if the bookmark was not published to the relay" do
        expect(bookmark.published_to_relay?(relay)).to be false
      end
      
      it "returns false if the publication failed" do
        Publication.create!(bookmark: bookmark, relay: relay, published_at: Time.current, success: false)
        expect(bookmark.published_to_relay?(relay)).to be false
      end
    end
    
    describe "#successful_publications" do
      it "returns only successful publications" do
        successful = Publication.create!(bookmark: bookmark, relay: relay, published_at: Time.current, success: true)
        failed = Publication.create!(
          bookmark: bookmark, 
          relay: Relay.create!(url: "wss://failed.relay"), 
          published_at: Time.current, 
          success: false
        )
        
        expect(bookmark.successful_publications).to include(successful)
        expect(bookmark.successful_publications).not_to include(failed)
      end
    end
    
    describe "#failed_publications" do
      it "returns only failed publications" do
        successful = Publication.create!(bookmark: bookmark, relay: relay, published_at: Time.current, success: true)
        failed = Publication.create!(
          bookmark: bookmark, 
          relay: Relay.create!(url: "wss://failed.relay"), 
          published_at: Time.current, 
          success: false
        )
        
        expect(bookmark.failed_publications).to include(failed)
        expect(bookmark.failed_publications).not_to include(successful)
      end
    end
  end
  
  describe "callbacks" do
    let(:valid_signed_event) do
      {
        id: 'test456',
        pubkey: user.public_key,
        content: 'Test Bookmark',
        created_at: Time.now.to_i,
        kind: 30001,
        tags: []
      }.to_json
    end
    
    it "schedules event publication after create" do
      new_bookmark = Bookmark.new(
        user: user,
        url: 'https://example.org',
        title: 'Test',
        event_id: 'test456',
        signed_event_content: valid_signed_event
      )
      
      expect {
        new_bookmark.save!
      }.to have_enqueued_job(PublishNostrEventJob)
    end
    
    it "does not schedule event publication if signed_event_content is blank" do
      new_bookmark = Bookmark.new(
        user: user,
        url: 'https://example.org',
        title: 'Test',
        event_id: 'test789'
      )
      
      expect {
        new_bookmark.save!
      }.not_to have_enqueued_job(PublishNostrEventJob)
    end
  end
end
