FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    sequence(:public_key) { |n| "pubkey_#{SecureRandom.hex(16)}_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }

    trait :with_bookmarks do
      after(:create) do |user|
        create_list(:bookmark, 3, user: user)
      end
    end

    trait :nostr_user do
      public_key { "npub1#{SecureRandom.hex(28)}" }
    end
  end
end
