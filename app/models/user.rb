class User < ApplicationRecord
  has_many :bookmarks, dependent: :destroy

  validates :public_key, presence: true, uniqueness: true, if: :public_key?

  def self.find_or_create_by_public_key(pubkey)
    user = find_by(public_key: pubkey)
    return user if user

    create(public_key: pubkey, email: "nostr-user-#{SecureRandom.hex(4)}@example.com")
  end
end
