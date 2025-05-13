require 'rails_helper'

RSpec.describe PublishNostrEventJob, type: :job do
  include ActiveJob::TestHelper
  
  # Set up ActiveJob test adapter
  before do
    ActiveJob::Base.queue_adapter = :test
  end
  
  let(:event_data) { { 'id' => 'test123', 'content' => 'Test content' } }
  let(:mock_service) { instance_double(NostrService) }
  
  before do
    allow(NostrService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:close_all_connections)
  end
  
  describe '#perform' do
    it 'publishes the event to relays' do
      expect(mock_service).to receive(:publish_event).with(event_data).and_return(
        { 'wss://test.relay' => { success: true } }
      )
      
      PublishNostrEventJob.new.perform(event_data)
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
    
    it 'uses specific relays if provided' do
      specific_relays = ['wss://specific.relay']
      
      expect(NostrService).to receive(:new).with(specific_relays).and_return(mock_service)
      expect(mock_service).to receive(:publish_event).and_return(
        { 'wss://specific.relay' => { success: true } }
      )
      
      PublishNostrEventJob.new.perform(event_data, relays: specific_relays)
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
