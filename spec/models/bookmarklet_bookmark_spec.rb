require 'rails_helper'

RSpec.describe "Bookmark (Bookmarklet-specific functionality)", type: :model do
  let(:user) { User.create!(username: "testuser", public_key: "test_pubkey", email: "test@example.com") }

  describe "creation from bookmarklet" do
    context "with signed Nostr event" do
      let(:signed_event_content) do
        {
          id: "event_123",
          kind: 39701,
          pubkey: user.public_key,
          created_at: Time.current.to_i,
          tags: [
            ["d", "example.com/article"],
            ["title", "Example Article"],
            ["published_at", Time.current.to_i.to_s],
            ["t", "technology"],
            ["t", "programming"]
          ],
          content: "This is an interesting article about #technology and #programming",
          sig: "signature_123"
        }.to_json
      end

      it "creates bookmark with all Nostr event data" do
        bookmark = Bookmark.create!(
          user: user,
          title: "Example Article",
          url: "https://example.com/article",
          description: "This is an interesting article about #technology and #programming",
          event_id: "event_123",
          signed_event_content: signed_event_content,
          signed_event_sig: "signature_123"
        )

        expect(bookmark).to be_valid
        expect(bookmark.signed_event_content).to be_present
        expect(bookmark.signed_event_sig).to eq("signature_123")
        
        # Parse the signed event content
        event_data = JSON.parse(bookmark.signed_event_content)
        expect(event_data["kind"]).to eq(39701)
        expect(event_data["pubkey"]).to eq(user.public_key)
        expect(event_data["tags"]).to include(["d", "example.com/article"])
        expect(event_data["tags"]).to include(["title", "Example Article"])
      end

      it "schedules event publication after creation" do
        expect(PublishNostrEventJob).to receive(:perform_later)

        Bookmark.create!(
          user: user,
          title: "Example Article",
          url: "https://example.com/article",
          description: "Test description",
          event_id: "event_123",
          signed_event_content: signed_event_content,
          signed_event_sig: "signature_123"
        )
      end
    end

    context "without signed Nostr event" do
      it "creates bookmark with manual event ID" do
        bookmark = Bookmark.create!(
          user: user,
          title: "Manual Bookmark",
          url: "https://example.com/manual",
          description: "Manually created bookmark",
          event_id: "manual-abc123"
        )

        expect(bookmark).to be_valid
        expect(bookmark.signed_event_content).to be_nil
        expect(bookmark.signed_event_sig).to be_nil
        expect(bookmark.event_id).to start_with("manual-")
      end

      it "does not schedule event publication without signed content" do
        expect(PublishNostrEventJob).not_to receive(:perform_later)

        Bookmark.create!(
          user: user,
          title: "Manual Bookmark",
          url: "https://example.com/manual",
          description: "Manually created bookmark",
          event_id: "manual-abc123"
        )
      end
    end
  end

  describe "URL processing for bookmarklet" do
    it "canonicalizes URLs from bookmarklet" do
      bookmark = Bookmark.new(
        user: user,
        title: "Test",
        url: "HTTPS://EXAMPLE.COM/PATH/?utm_source=test",
        description: "Test",
        event_id: "test123"
      )

      expect(bookmark).to be_valid
      # URL should be canonicalized (implementation depends on UrlService)
    end

    it "handles URLs without protocol" do
      bookmark = Bookmark.new(
        user: user,
        title: "Test",
        url: "example.com/path",
        description: "Test",
        event_id: "test123"
      )

      # Should be handled by UrlService canonicalization
      expect(bookmark).to be_valid
    end
  end

  describe "d-tag extraction" do
    it "extracts d-tag from URL correctly" do
      bookmark = Bookmark.create!(
        user: user,
        title: "Test Article",
        url: "https://example.com/path/to/article?param=value#section",
        description: "Test",
        event_id: "test123"
      )

      d_tag = bookmark.d_tag
      expect(d_tag).to eq("example.com/path/to/article")
    end

    it "handles URLs without query parameters" do
      bookmark = Bookmark.create!(
        user: user,
        title: "Test Article",
        url: "https://example.com/simple-path",
        description: "Test",
        event_id: "test123"
      )

      d_tag = bookmark.d_tag
      expect(d_tag).to eq("example.com/simple-path")
    end

    it "returns nil for blank URLs" do
      bookmark = Bookmark.new(
        user: user,
        title: "Test",
        url: nil,
        description: "Test",
        event_id: "test123"
      )

      expect(bookmark.d_tag).to be_nil
    end
  end

  describe "hashtag extraction" do
    it "extracts hashtags from description" do
      bookmark = Bookmark.create!(
        user: user,
        title: "Test Article",
        url: "https://example.com/article",
        description: "This is about #ruby and #rails development. Also #testing!",
        event_id: "test123"
      )

      hashtags = bookmark.hashtags
      expect(hashtags).to contain_exactly("ruby", "rails", "testing")
    end

    it "handles descriptions without hashtags" do
      bookmark = Bookmark.create!(
        user: user,
        title: "Test Article",
        url: "https://example.com/article",
        description: "This is a normal description without any hash tags.",
        event_id: "test123"
      )

      hashtags = bookmark.hashtags
      expect(hashtags).to be_empty
    end

    it "handles nil description" do
      bookmark = Bookmark.create!(
        user: user,
        title: "Test Article",
        url: "https://example.com/article",
        description: nil,
        event_id: "test123"
      )

      hashtags = bookmark.hashtags
      expect(hashtags).to be_empty
    end

    it "removes duplicate hashtags" do
      bookmark = Bookmark.create!(
        user: user,
        title: "Test Article",
        url: "https://example.com/article",
        description: "Testing #ruby and #rails. More about #ruby programming.",
        event_id: "test123"
      )

      hashtags = bookmark.hashtags
      expect(hashtags).to contain_exactly("ruby", "rails")
    end
  end

  describe "NIP-B0 compliance" do
    it "uses correct event kind for bookmarks" do
      expect(Bookmark::NOSTR_KIND_BOOKMARK).to eq(39701)
    end

    it "validates event structure for signed bookmarks" do
      signed_event = {
        id: "event_123",
        kind: 39701,
        pubkey: user.public_key,
        created_at: Time.current.to_i,
        tags: [["d", "example.com"]],
        content: "test",
        sig: "signature"
      }

      bookmark = Bookmark.create!(
        user: user,
        title: "Test",
        url: "https://example.com",
        description: "test",
        event_id: "event_123",
        signed_event_content: signed_event.to_json,
        signed_event_sig: "signature"
      )

      event_data = JSON.parse(bookmark.signed_event_content)
      expect(event_data["kind"]).to eq(39701)
      expect(event_data["tags"]).to be_an(Array)
      expect(event_data["tags"].first).to eq(["d", "example.com"])
    end
  end
end
