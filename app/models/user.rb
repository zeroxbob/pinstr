class User < ApplicationRecord
  has_many :bookmarks, dependent: :destroy

  validates :public_key, presence: true, uniqueness: true, if: :public_key?
  
  # Username can be nil in case it's not set
  validates :username, uniqueness: true, allow_nil: true
  
  before_validation :generate_username, on: :create, if: -> { username.blank? }

  def self.find_or_create_by_public_key(pubkey)
    return nil if pubkey.blank?
    
    # Make sure we're normalizing the pubkey format
    normalized_pubkey = normalize_pubkey(pubkey)
    
    # Try to find by the normalized pubkey
    user = find_by(public_key: normalized_pubkey)
    return user if user
    
    # Create a new user with the normalized pubkey
    create(
      public_key: normalized_pubkey,
      email: "nostr-user-9d7ef068@example.com"
    )
  end
  
  # Helper to normalize pubkey format
  # This handles both hex and npub formats
  def self.normalize_pubkey(pubkey)
    # For now, just ensure it's a string and trimmed
    pubkey.to_s.strip
  end
  
  private
  
  def generate_username
    self.username = "user_b5776ae2" if username.blank?
  end
end