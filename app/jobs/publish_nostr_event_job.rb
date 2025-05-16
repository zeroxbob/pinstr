class PublishNostrEventJob < ApplicationJob
  queue_as :nostr
  
  retry_on StandardError, attempts: 3, wait: :exponentially_longer
  
  def perform(event_data, options = {})
    # Ensure we have event data as a hash
    event_data = JSON.parse(event_data) if event_data.is_a?(String)
    event_id = event_data["id"] || event_data[:id]
    
    Rails.logger.info("Publishing Nostr event: #{event_id}")
    
    # Find the bookmark for this event
    bookmark = Bookmark.find_by(event_id: event_id)
    
    unless bookmark
      Rails.logger.error("Could not find bookmark with event_id: #{event_id}")
      return
    end
    
    # Verify this is a NIP-B0 web bookmark event (kind 39701)
    unless event_data["kind"] == 39701 || event_data[:kind] == 39701
      Rails.logger.error("Event is not a NIP-B0 web bookmark (kind 39701)")
      return
    end
    
    # Create the service instance
    service = NostrService.new(options[:relays])
    
    # Connect and publish
    begin
      results = service.publish_event(event_data, bookmark)
      
      # Log results
      success_count = results.count { |_, result| result[:success] }
      Rails.logger.info("Published event #{event_id} to #{success_count}/#{results.size} relays")
      
      # If we didn't publish to any relays successfully, raise an error to trigger retry
      if success_count == 0 && results.size > 0
        raise "Failed to publish to any relays"
      end
    ensure
      # Always clean up connections
      service.close_all_connections
    end
  end
end