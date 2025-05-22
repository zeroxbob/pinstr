FactoryBot.define do
  factory :bookmark do
    association :user
    sequence(:title) { |n| "Bookmark Title #{n}" }
    sequence(:url) { |n| "https://example.com/page-#{n}" }
    description { "A sample bookmark description" }
    sequence(:event_id) { |n| "event_id_#{n}" }

    trait :with_nostr_signature do
      signed_event_content do
        {
          id: event_id,
          kind: 39701,
          pubkey: user.public_key,
          created_at: Time.current.to_i,
          tags: [
            ["d", url.gsub(/^https?:\/\//, '')],
            ["title", title],
            ["published_at", Time.current.to_i.to_s]
          ],
          content: description,
          sig: "signature_#{SecureRandom.hex(32)}"
        }.to_json
      end
      signed_event_sig { "signature_#{SecureRandom.hex(32)}" }
    end

    trait :manual do
      event_id { "manual-#{SecureRandom.hex(16)}" }
      signed_event_content { nil }
      signed_event_sig { nil }
    end

    trait :with_hashtags do
      description { "A bookmark about #ruby #rails #programming" }
    end
  end
end
