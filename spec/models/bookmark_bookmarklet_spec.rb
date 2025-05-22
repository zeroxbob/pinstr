require 'rails_helper'

RSpec.describe Bookmark, type: :model do
  let(:user) { User.create!(username: "testuser", public_key: "test_public_key", email: "test@example.com") }

  describe "bookmarklet-related functionality" do
    context "when created via bookmarklet with Nostr signing" do
      let(:signed_event_content) do
        {
          id: "event_id_123",
          kind: 39701,
          pubkey: user.public_key,
          created_at: Time.current.to_i,
          tags: [
            ["d", "example.com/test-article"],
            ["title", "Test Article"],
            ["published_at", Time.current.to_i.to_s]
          ],
          content: "Test bookmark content",
          sig: "signature_123"
        }.to_json
      end

      let(:bookmark) do
        Bookmark.create!(
          user: user,
          url: "https://example.com/test-article",
          title: "Test Article",
          description: "Test bookmark content",
          event_id: "event_id_123",
          signed_event_content: signed_event_content,
          signed_event_sig: "signature_123"
        )
      end

      it "stores the signed event content" do
        expect(bookmark.signed_event_content).to be_present
        expect(bookmark.signed_event_sig).to eq("signature_123")
        
        parsed_event = JSON.parse(bookmark.signed_event_content)
        expect(parsed_event['kind']).to eq(39701)
        expect(parsed_event['id']).to eq("event_id_123")
      end

      it "can be identified as a Nostr-signed bookmark" do
        expect(bookmark.signed_event_content).to be_present
        expect(bookmark.signed_event_sig).to be_present
        expect(bookmark.event_id).not_to start_with("manual-")
      end
    end

    context "when created via bookmarklet without Nostr signing" do
      let(:bookmark) do
        Bookmark.create!(
          user: user,
          url: "https://example.com/test-article",
          title: "Test Article",
          description: "Test bookmark content",
          event_id: "manual-abc123"
        )
      end

      it "has a manual event ID" do
        expect(bookmark.event_id).to start_with("manual-")
        expect(bookmark.signed_event_content).to be_nil
        expect(bookmark.signed_event_sig).to be_nil
      end

      it "can be identified as a non-Nostr bookmark" do
        expect(bookmark.signed_event_content).to be_nil
        expect(bookmark.signed_event_sig).to be_nil
        expect(bookmark.event_id).to start_with("manual-")
      end
    end

    describe "URL processing for bookmarklet" do
      it "handles URLs from bookmarklet with various formats" do
        test_urls = [
          "https://example.com/article",
          "http://example.com/article",
          "example.com/article", # Missing protocol
          "https://example.com/article?param=value",
          "https://example.com/article#section"
        ]

        test_urls.each do |url|
          bookmark = Bookmark.new(
            user: user,
            url: url,
            title: "Test",
            event_id: "test-#{SecureRandom.hex(4)}"
          )
          
          expect(bookmark).to be_valid
          expect(bookmark.url).to start_with("https://")
        end
      end
    end

    describe "d_tag extraction for NIP-B0" do
      let(:bookmark) do
        Bookmark.create!(
          user: user,
          url: "https://example.com/articles/test-article?utm_source=bookmarklet#section1",
          title: "Test Article",
          event_id: "test123"
        )
      end

      it "extracts d_tag correctly from URL" do
        d_tag = bookmark.d_tag
        
        expect(d_tag).to eq("example.com/articles/test-article")
        expect(d_tag).not_to include("https://")
        expect(d_tag).not_to include("?utm_source=bookmarklet")
        expect(d_tag).not_to include("#section1")
      end

      it "handles URLs without query parameters or fragments" do
        simple_bookmark = Bookmark.create!(
          user: user,
          url: "https://example.com/simple-path",
          title: "Simple",
          event_id: "simple123"
        )

        expect(simple_bookmark.d_tag).to eq("example.com/simple-path")
      end

      it "handles root domain URLs" do
        root_bookmark = Bookmark.create!(
          user: user,
          url: "https://example.com",
          title: "Root",
          event_id: "root123"
        )

        expect(root_bookmark.d_tag).to eq("example.com")
      end
    end

    describe "hashtag extraction from bookmarklet descriptions" do
      let(:bookmark) do
        Bookmark.create!(
          user: user,
          url: "https://example.com/test",
          title: "Test",
          description: "This is a #test bookmark with #multiple #hashtags and some regular text #ruby",
          event_id: "hashtag123"
        )
      end

      it "extracts hashtags from description" do
        hashtags = bookmark.hashtags
        
        expect(hashtags).to include("test")
        expect(hashtags).to include("multiple")
        expect(hashtags).to include("hashtags")
        expect(hashtags).to include("ruby")
        expect(hashtags.size).to eq(4)
      end

      it "returns unique hashtags only" do
        duplicate_bookmark = Bookmark.create!(
          user: user,
          url: "https://example.com/test2",
          title: "Test",
          description: "This has #duplicate #tags and #duplicate again",
          event_id: "duplicate123"
        )

        hashtags = duplicate_bookmark.hashtags
        expect(hashtags.count("duplicate")).to eq(1)
        expect(hashtags.count("tags")).to eq(1)
      end

      it "handles descriptions without hashtags" do
        no_hashtag_bookmark = Bookmark.create!(
          user: user,
          url: "https://example.com/test3",
          title: "Test",
          description: "This description has no hashtags at all",
          event_id: "nohashtag123"
        )

        expect(no_hashtag_bookmark.hashtags).to be_empty
      end

      it "handles nil descriptions" do
        nil_description_bookmark = Bookmark.create!(
          user: user,
          url: "https://example.com/test4",
          title: "Test",
          description: nil,
          event_id: "nil123"
        )

        expect(nil_description_bookmark.hashtags).to be_empty
      end
    end
  end

  describe "after_create callback for event publication" do
    it "schedules event publication when signed_event_content is present" do
      expect(PublishNostrEventJob).to receive(:perform_later)

      Bookmark.create!(
        user: user,
        url: "https://example.com/test",
        title: "Test",
        event_id: "test123",
        signed_event_content: '{"kind": 39701, "id": "test123"}'
      )
    end

    it "does not schedule publication when signed_event_content is nil" do
      expect(PublishNostrEventJob).not_to receive(:perform_later)

      Bookmark.create!(
        user: user,
        url: "https://example.com/test",
        title: "Test",
        event_id: "manual-test123"
      )
    end

    it "handles JSON parsing errors gracefully" do
      allow(Rails.logger).to receive(:error)
      expect(PublishNostrEventJob).not_to receive(:perform_later)

      Bookmark.create!(
        user: user,
        url: "https://example.com/test",
        title: "Test",
        event_id: "test123",
        signed_event_content: 'invalid json'
      )

      expect(Rails.logger).to have_received(:error).with(/Failed to parse signed event content/)
    end
  end
end
