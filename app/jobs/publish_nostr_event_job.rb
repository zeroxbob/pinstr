class PublishNostrEventJob < ApplicationJob
  queue_as :nostr

  retry_on StandardError, attempts: 3, wait: :exponentially_longer

  def perform(event_data, options = {})
    Rails.logger.info("Publishing Nostr event: #{event_data['id'] || event_data[:id]}")

    # Create the service instance
    service = NostrService.new(options[:relays])

    # Connect and publish
    begin
      results = service.publish_event(event_data)

      # Log results
      success_count = results.count { |_, result| result[:success] }
      Rails.logger.info("Published event to #{success_count}/#{results.size} relays")

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
