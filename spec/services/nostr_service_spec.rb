require 'rails_helper'

RSpec.describe NostrService do
  let(:service) { NostrService.new(['wss://test.relay']) }
  let(:mock_client) { instance_double(Nostr::Client) }
  let(:mock_response) { double('Response', success: true, message: 'OK') }
  let(:bookmark) { instance_double(Bookmark) }
  let(:relay) { instance_double(Relay, url: 'wss://test.relay') }
  
  before do
    allow(Relay).to receive(:find_or_create_by).and_return(relay)
    allow(bookmark).to receive(:record_publication)
    allow(relay).to receive(:mark_as_connected)
  end
  
  describe '#connect_to_relay' do
    before do
      allow(Nostr::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:on)
      allow(mock_client).to receive(:connect)
    end
    
    it 'connects to a relay and stores the connection' do
      expect(Nostr::Client).to receive(:new).with(relay: 'wss://test.relay')
      expect(mock_client).to receive(:on).with(:connect).once
      expect(mock_client).to receive(:on).with(:error).once
      expect(mock_client).to receive(:on).with(:close).once
      expect(mock_client).to receive(:connect)
      
      connection = service.connect_to_relay('wss://test.relay')
      expect(connection).to eq(mock_client)
      expect(service.connections['wss://test.relay']).to eq(mock_client)
    end
    
    it 'returns existing connection if already connected' do
      # First connection
      service.connect_to_relay('wss://test.relay')
      
      # Should reuse existing connection
      expect(Nostr::Client).not_to receive(:new)
      service.connect_to_relay('wss://test.relay')
    end
    
    it 'handles connection errors gracefully' do
      allow(Nostr::Client).to receive(:new).and_raise(StandardError.new('Connection error'))
      
      expect { service.connect_to_relay('wss://test.relay') }.not_to raise_error
      expect(service.connections['wss://test.relay']).to be_nil
    end
  end
  
  describe '#publish_event' do
    let(:event_data) { { 'id' => 'test123', 'content' => 'test', 'kind' => 1, 'pubkey' => 'testpubkey', 'created_at' => Time.now.to_i } }
    
    before do
      allow(service).to receive(:connect_to_relay).and_return(mock_client)
      allow(mock_client).to receive(:publish_and_wait).and_return(mock_response)
    end
    
    it 'publishes event to relays and records the publication' do
      expect(mock_client).to receive(:publish_and_wait)
      expect(bookmark).to receive(:record_publication).with(relay, true, nil)
      
      results = service.publish_event(event_data, bookmark)
      expect(results['wss://test.relay'][:success]).to be true
    end
    
    it 'handles connection failures and records the failure' do
      allow(service).to receive(:connect_to_relay).and_return(nil)
      expect(bookmark).to receive(:record_publication).with(relay, false, "Could not connect to relay")
      
      results = service.publish_event(event_data, bookmark)
      expect(results['wss://test.relay'][:success]).to be false
      expect(results['wss://test.relay'][:error]).to eq('Could not connect to relay')
    end
    
    it 'handles publishing errors and records the failure' do
      error = StandardError.new('Publish error')
      allow(mock_client).to receive(:publish_and_wait).and_raise(error)
      expect(bookmark).to receive(:record_publication).with(relay, false, 'Publish error')
      
      results = service.publish_event(event_data, bookmark)
      expect(results['wss://test.relay'][:success]).to be false
      expect(results['wss://test.relay'][:error]).to eq('Publish error')
    end
  end
  
  describe '#close_all_connections' do
    before do
      allow(service).to receive(:connect_to_relay).and_return(mock_client)
      allow(mock_client).to receive(:close)
      # Add the connection to the service
      service.instance_variable_set(:@connections, {'wss://test.relay' => mock_client})
    end
    
    it 'closes all open connections' do
      expect(mock_client).to receive(:close)
      service.close_all_connections
      expect(service.connections).to be_empty
    end
  end
end
