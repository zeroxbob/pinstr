require "rails_helper"

RSpec.describe BookmarkTag, type: :model do
  before(:all) do
    User.create!(id: 1, email: "test@example.com", public_key: "some_key") unless User.exists?(1)

    unless Bookmark.exists?(url: "https://example.com")
      Bookmark.create!(
        user_id: 1,
        url: "https://example.com",
        title: "Some Title",
        event_id: "some_id"
      )
    end

    Tag.create!(name: "TagSample") unless Tag.exists?(name: "TagSample")
  end

  it "is valid with valid references" do
    bookmark = Bookmark.find_by(url: "https://example.com")
    tag = Tag.find_by(name: "TagSample")

    bookmark_tag = BookmarkTag.new(bookmark: bookmark, tag: tag)
    expect(bookmark_tag).to be_valid
  end

  it "requires bookmark" do
    bookmark_tag = BookmarkTag.new(bookmark: nil, tag: Tag.new(name: "NoBookmark"))
    expect(bookmark_tag).not_to be_valid
  end

  it "requires tag" do
    bookmark_tag = BookmarkTag.new(bookmark: Bookmark.new, tag: nil)
    expect(bookmark_tag).not_to be_valid
  end
end
