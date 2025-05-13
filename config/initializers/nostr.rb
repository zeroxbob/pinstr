Rails.application.config.nostr = ActiveSupport::OrderedOptions.new
Rails.application.config.nostr.relays = [
  'wss://relay.damus.io',
  'wss://relay.snort.social',
  'wss://nostr.relayer.se'
]
