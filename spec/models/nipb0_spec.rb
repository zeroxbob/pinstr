require 'rails_helper'

RSpec.describe "NIP-B0 Web Bookmarking", type: :model do
  describe "NostrHelper" do
    it "builds a valid NIP-B0 web bookmark event" do
      pubkey = "2729620da105979b22acfdfe9585274a78c282869b493abfa4120d3af2061298"
      url = "https://alice.blog/post?param=value#section"
      title = "Blog insights by Alice"
      description = "A marvelous insight by Alice about the nature of blogs and posts. #post #insight"
      created_at = 1738869705
      
      event = NostrHelper.build_web_bookmark_event(
        pubkey: pubkey,
        url: url,
        title: title,
        description: description,
        created_at: created_at
      )
      
      # Verify kind
      expect(event[:kind]).to eq(39701)
      
      # Verify required fields
      expect(event[:pubkey]).to eq(pubkey)
      expect(event[:created_at]).to eq(created_at)
      expect(event[:content]).to eq(description)
      
      # Verify tags
      d_tag_found = false
      title_tag_found = false
      published_at_found = false
      hashtags = []
      
      event[:tags].each do |tag|
        case tag[0]
        when "d"
          d_tag_found = true
          # d tag should remove scheme, querystring and hash
          expect(tag[1]).to eq("alice.blog/post")
        when "title"
          title_tag_found = true
          expect(tag[1]).to eq(title)
        when "published_at"
          published_at_found = true
          expect(tag[1]).to eq(created_at.to_s)
        when "t"
          hashtags << tag[1]
        end
      end
      
      expect(d_tag_found).to be true
      expect(title_tag_found).to be true
      expect(published_at_found).to be true
      expect(hashtags).to include("post")
      expect(hashtags).to include("insight")
    end
    
    it "validates a NIP-B0 event format correctly" do
      valid_event = {
        "kind" => 39701,
        "id" => "d7a92714f81d0f712e715556aee69ea6da6bfb287e6baf794a095d301d603ec7",
        "pubkey" => "2729620da105979b22acfdfe9585274a78c282869b493abfa4120d3af2061298",
        "created_at" => 1738869705,
        "tags" => [
          ["d", "alice.blog/post"],
          ["published_at", "1738863000"],
          ["title", "Blog insights by Alice"],
          ["t", "post"],
          ["t", "insight"]
        ],
        "content" => "A marvelous insight by Alice about the nature of blogs and posts.",
        "sig" => "36d34e6448fe0223e9999361c39c492a208bc423d2fcdfc2a3404e04df7c22dc65bbbd62dbe8a4373c62e4d29aac285b5aa4bb9b4b8053bd6207a8b45fbd0c98"
      }
      
      invalid_event = {
        "kind" => 39701,
        "id" => "d7a92714f81d0f712e715556aee69ea6da6bfb287e6baf794a095d301d603ec7",
        "pubkey" => "2729620da105979b22acfdfe9585274a78c282869b493abfa4120d3af2061298",
        "created_at" => 1738869705,
        "tags" => [
          ["title", "Blog insights by Alice"]
          # Missing required "d" tag
        ],
        "content" => "A marvelous insight by Alice about the nature of blogs and posts.",
        "sig" => "36d34e6448fe0223e9999361c39c492a208bc423d2fcdfc2a3404e04df7c22dc65bbbd62dbe8a4373c62e4d29aac285b5aa4bb9b4b8053bd6207a8b45fbd0c98"
      }
      
      expect(NostrHelper.verify_nipb0_format(valid_event)).to be true
      expect(NostrHelper.verify_nipb0_format(invalid_event)).to be false
    end
    
    it "extracts metadata from a NIP-B0 event" do
      event = {
        "kind" => 39701,
        "id" => "d7a92714f81d0f712e715556aee69ea6da6bfb287e6baf794a095d301d603ec7",
        "pubkey" => "2729620da105979b22acfdfe9585274a78c282869b493abfa4120d3af2061298",
        "created_at" => 1738869705,
        "tags" => [
          ["d", "alice.blog/post"],
          ["published_at", "1738863000"],
          ["title", "Blog insights by Alice"],
          ["t", "post"],
          ["t", "insight"]
        ],
        "content" => "A marvelous insight by Alice about the nature of blogs and posts.",
        "sig" => "36d34e6448fe0223e9999361c39c492a208bc423d2fcdfc2a3404e04df7c22dc65bbbd62dbe8a4373c62e4d29aac285b5aa4bb9b4b8053bd6207a8b45fbd0c98"
      }
      
      metadata = NostrHelper.extract_metadata_from_event(event)
      
      expect(metadata[:event_id]).to eq(event["id"])
      expect(metadata[:description]).to eq(event["content"])
      expect(metadata[:d_tag]).to eq("alice.blog/post")
      expect(metadata[:published_at]).to eq(1738863000)
      expect(metadata[:title]).to eq("Blog insights by Alice")
      expect(metadata[:hashtags]).to include("post")
      expect(metadata[:hashtags]).to include("insight")
    end
  end
  
  describe "Bookmark model integration" do
    it "correctly generates a d_tag from a URL" do
      bookmark = Bookmark.new(url: "https://example.com/blog/post?param=value#section")
      expect(bookmark.d_tag).to eq("example.com/blog/post")
    end
    
    it "extracts hashtags from description" do
      bookmark = Bookmark.new(description: "This is a test #bookmark with multiple #hashtags")
      expect(bookmark.hashtags).to contain_exactly("bookmark", "hashtags")
    end
  end
end