require 'nostr_ruby'

class NostrService
  attr_reader :relay_urls, :connections, :logger
  
  def initialize(relay_urls = nil)
    @relay_urls = relay_urls || Rails.configuration.nostr.relays
    @connections = {}
    @logger = Rails.logger
  end
  
  def connect_to_relays
    @relay_urls.each do |relay_url|
      connect_to_relay(relay_url)
    end
  end
  
  def connect_to_relay(relay_url)
    return @connections[relay_url] if @connections[relay_url]
    
    begin
      # Find or create the Relay record
      relay = Relay.find_or_create_by(url: relay_url)
      
      client = Nostr::Client.new(relay: relay_url)
      
      # Set up event handlers
      client.on :connect do
        logger.info("Connected to Nostr relay: #{relay_url}")
        relay.mark_as_connected
      end
      
      client.on :error do |error|
        logger.error("Error with Nostr relay #{relay_url}: #{error}")
      end
      
      client.on :close do
        logger.info("Closed connection to Nostr relay: #{relay_url}")
        @connections.delete(relay_url)
      end
      
      # Connect to the relay
      client.connect
      
      @connections[relay_url] = client
      client
    rescue => e
      handle_error(e, "Failed to connect to relay #{relay_url}")
      nil
    end
  end
  
  # This method now requires a bookmark parameter to record publications
  def publish_event(event_data, bookmark, specific_relays = nil)
    relays_to_use = specific_relays || @relay_urls
    results = {}
    
    relays_to_use.each do |relay_url|
      results[relay_url] = publish_to_relay(relay_url, event_data, bookmark)
    end
    
    results
  end
  
  def publish_to_relay(relay_url, event_data, bookmark)
    client = @connections[relay_url] || connect_to_relay(relay_url)
    
    # Find or create the Relay record
    relay = Relay.find_or_create_by(url: relay_url)
    
    if !client
      # Record the publication failure
      bookmark.record_publication(relay, false, "Could not connect to relay")
      return { success: false, error: "Could not connect to relay" }
    end
    
    begin
      # Convert the event data hash to a proper Nostr::Event if needed
      event = if event_data.is_a?(Nostr::Event)
        event_data
      else
        # Create event from the data
        if event_data.is_a?(String)
          # If it's a JSON string, parse it
          data = JSON.parse(event_data, symbolize_names: true)
        else
          # Ensure all keys are symbols
          data = event_data.transform_keys(&:to_sym) if event_data.is_a?(Hash)
        end
        
        # Create the event
        Nostr::Event.new(
          kind: data[:kind],
          pubkey: data[:pubkey],
          created_at: data[:created_at],
          tags: data[:tags] || [],
          content: data[:content],
          id: data[:id],
          sig: data[:sig]
        )
      end
      
      # Send the event synchronously
      response = client.publish_and_wait(event)
      
      # Record the publication result
      bookmark.record_publication(relay, response.success, response.success ? nil : response.message)
      
      # Return the result
      { success: response.success, message: response.message }
    rescue => e
      error_message = e.message
      handle_error(e, "Failed to publish event to relay #{relay_url}")
      
      # Record the publication failure
      bookmark.record_publication(relay, false, error_message)
      
      { success: false, error: error_message }
    end
  end
  
  def handle_error(error, context = nil)
    logger.error("#{context}: #{error.message}") if context
    logger.error(error.backtrace.join("\n")) if error.backtrace
  end
  
  def close_all_connections
    @connections.each do |url, client|
      begin
        client.close if client.respond_to?(:close)
      rescue => e
        logger.error("Error disconnecting from #{url}: #{e.message}")
      end
    end
    @connections = {}
  end
end
