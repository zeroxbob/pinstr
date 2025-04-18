require "rails_helper"

RSpec.describe Bookmark, type: :model do
  before(:all) do
    User.create!(id: 1, email: "test@example.com", public_key: "some_key") unless User.exists?(1)
  end

  subject(:bookmark) { described_class.new(user_id: 1, url: "https://example.com", title: "Example Title", event_id: "unique_event_id") }

  it "is valid with valid attributes" do
    expect(bookmark).to be_valid
  end

  it "requires url" do
    bookmark.url = nil
    expect(bookmark).not_to be_valid
  end

  it "requires title" do
    bookmark.title = nil
    expect(bookmark).not_to be_valid
  end

  it "requires event_id" do
    bookmark.event_id = nil
    expect(bookmark).not_to be_valid
  end

  it "requires event_id to be unique" do
    described_class.create!(user_id: 1, url: "https://example.org", title: "DupeTitle", event_id: "dupe_event")
    bookmark.event_id = "dupe_event"
    expect(bookmark).not_to be_valid
  end
end
