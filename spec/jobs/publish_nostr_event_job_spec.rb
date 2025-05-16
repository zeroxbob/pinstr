require 'rails_helper'

RSpec.describe PublishNostrEventJob, type: :job do
  include ActiveJob::TestHelper
  
  # Set up ActiveJob test adapter
  before do
    ActiveJob::Base.queue_adapter = :test
  end
  
  let(:user) { User.create!(username: "testuser", public_key: "testpubkey") }
  let(:bookmark) { Bookmark.create!(user: user, url: "https://example.com", title: "Test", event_id: "test123") }
  # Update event data to include kind 39701 for NIP-B0
  let(:event_data) { { 'id' => 'test123', 'content' => 'Test content', 'kind' => 39701 } }
  let(:mock_service) { instance_double(NostrService) }
  
  before do
    allow(NostrService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:close_all_connections)
    allow(Bookmark).to receive(:find_by).with(event_id: "test123").and_return(bookmark)
  end
  
  describe '#perform' do
    it 'looks up the bookmark and publishes the event to relays' do
      expect(Bookmark).to receive(:find_by).with(event_id: "test123").and_return(bookmark)
      expect(mock_service).to receive(:publish_event).with(event_data, bookmark).and_return(
        { 'wss://test.relay' => { success: true } }
      )
      
      PublishNostrEventJob.new.perform(event_data)
    end
    
    it 'logs an error and returns if the bookmark is not found' do
      allow(Bookmark).to receive(:find_by).with(event_id: "test123").and_return(nil)
      expect(Rails.logger).to receive(:error).with("Could not find bookmark with event_id: test123")
      expect(mock_service).not_to receive(:publish_event)
      
      PublishNostrEventJob.new.perform(event_data)
    end
    
    it 'logs an error and returns if the event is not a NIP-B0 event' do
      # Create a non-NIP-B0 event
      invalid_event = { 'id' => 'test123', 'content' => 'Test content', 'kind' => 30001 }
      
      expect(Rails.logger).to receive(:error).with("Event is not a NIP-B0 web bookmark (kind 39701)")
      expect(mock_service).not_to receive(:publish_event)
      
      PublishNostrEventJob.new.perform(invalid_event)
    end
    
    it 'closes connections even if there is an error' do
      allow(mock_service).to receive(:publish_event).and_raise('Test error')
      
      expect(mock_service).to receive(:close_all_connections)
      
      expect {
        PublishNostrEventJob.new.perform(event_data)
      }.to raise_error('Test error')
    end
    
    it 'raises an error if no relays succeeded' do
      allow(mock_service).to receive(:publish_event).and_return(
        { 'wss://test.relay' => { success: false, error: 'Connection failed' } }
      )
      
      expect {
        PublishNostrEventJob.new.perform(event_data)
      }.to raise_error('Failed to publish to any relays')
    end
  end
  
  describe 'job scheduling' do
    it 'enqueues the job' do
      expect {
        PublishNostrEventJob.perform_later(event_data)
      }.to have_enqueued_job(PublishNostrEventJob).with(event_data)
    end
    
    it 'uses the nostr queue' do
      expect {
        PublishNostrEventJob.perform_later(event_data)
      }.to have_enqueued_job.on_queue('nostr')
    end
  end
end