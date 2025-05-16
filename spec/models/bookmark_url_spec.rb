require 'rails_helper'

RSpec.describe Bookmark, type: :model do
  let(:user) { User.create!(username: "testuser", public_key: "testpubkey") }
  
  describe "URL validation and normalization" do
    it "normalizes the URL before validation" do
      bookmark = Bookmark.new(
        user: user,
        url: "EXAMPLE.com/path/",
        title: "Test",
        event_id: "test123"
      )
      
      bookmark.valid?
      expect(bookmark.url).to eq("https://example.com/path")
    end
    
    it "validates that the URL is valid" do
      bookmark = Bookmark.new(
        user: user,
        url: "not a url",
        title: "Test",
        event_id: "test123"
      )
      
      expect(bookmark).not_to be_valid
      expect(bookmark.errors[:url]).to include("is not a valid URL")
    end
    
    it "prevents duplicate URLs for the same user" do
      # Create first bookmark
      Bookmark.create!(
        user: user,
        url: "https://example.com",
        title: "First Bookmark",
        event_id: "test123"
      )
      
      # Try to create another with the same URL
      bookmark = Bookmark.new(
        user: user,
        url: "https://example.com",
        title: "Second Bookmark",
        event_id: "test456"
      )
      
      expect(bookmark).not_to be_valid
      expect(bookmark.errors[:url]).to include("has already been bookmarked by you")
    end
    
    it "prevents duplicate URLs with different formats for the same user" do
      # Create first bookmark
      Bookmark.create!(
        user: user,
        url: "https://example.com/path",
        title: "First Bookmark",
        event_id: "test123"
      )
      
      # Try to create another with an equivalent URL
      bookmark = Bookmark.new(
        user: user,
        url: "http://www.example.com/path/",
        title: "Second Bookmark",
        event_id: "test456"
      )
      
      expect(bookmark).not_to be_valid
      expect(bookmark.errors[:url]).to include("has already been bookmarked by you")
    end
    
    it "allows the same URL to be bookmarked by different users" do
      user2 = User.create!(username: "user2", public_key: "pubkey2")
      
      # Create bookmark for first user
      Bookmark.create!(
        user: user,
        url: "https://example.com",
        title: "User 1 Bookmark",
        event_id: "test123"
      )
      
      # Create bookmark with same URL for second user
      bookmark = Bookmark.new(
        user: user2,
        url: "https://example.com",
        title: "User 2 Bookmark",
        event_id: "test456"
      )
      
      expect(bookmark).to be_valid
    end
  end
  
  describe ".find_by_url" do
    before do
      @bookmark = Bookmark.create!(
        user: user,
        url: "https://example.com/path",
        title: "Test Bookmark",
        event_id: "test123"
      )
    end
    
    it "finds a bookmark by its exact URL" do
      found = Bookmark.find_by_url("https://example.com/path")
      expect(found).to eq(@bookmark)
    end
    
    it "finds a bookmark by an equivalent URL" do
      found = Bookmark.find_by_url("http://www.example.com/path/")
      expect(found).to eq(@bookmark)
    end
    
    it "returns nil for non-existent URLs" do
      found = Bookmark.find_by_url("https://notfound.com")
      expect(found).to be_nil
    end
  end
  
  describe ".user_has_bookmarked?" do
    before do
      Bookmark.create!(
        user: user,
        url: "https://example.com/path",
        title: "Test Bookmark",
        event_id: "test123"
      )
    end
    
    it "returns true if the user has bookmarked the exact URL" do
      expect(Bookmark.user_has_bookmarked?(user, "https://example.com/path")).to be true
    end
    
    it "returns true if the user has bookmarked an equivalent URL" do
      expect(Bookmark.user_has_bookmarked?(user, "http://www.example.com/path/")).to be true
    end
    
    it "returns false if the user has not bookmarked the URL" do
      expect(Bookmark.user_has_bookmarked?(user, "https://notbookmarked.com")).to be false
    end
    
    it "returns false if the URL is bookmarked by a different user" do
      user2 = User.create!(username: "user2", public_key: "pubkey2")
      expect(Bookmark.user_has_bookmarked?(user2, "https://example.com/path")).to be false
    end
  end
end
