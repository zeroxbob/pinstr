Rails.application.config.after_initialize do
  # Skip in test environment
  unless Rails.env.test?
    # Create relay records for the configured relays
    if defined?(Rails.configuration.nostr.relays)
      Rails.configuration.nostr.relays.each do |relay_url|
        Relay.find_or_create_by(url: relay_url)
      end
    end
  end
end
