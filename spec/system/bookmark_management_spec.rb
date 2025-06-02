require 'rails_helper'

RSpec.describe "Bookmark Management", type: :system do
  before do
    @user = User.create!(username: "testuser", public_key: "testpubkey")
    
    @bookmark = Bookmark.create!(
      user: @user,
      url: "https://www.greatblog.com/amazing_post",
      title: "Test Bookmark",
      description: "A test description",
      event_id: "test_event_id_123",
      signed_event_content: { id: "test_event_id_123", pubkey: "testpubkey" }.to_json,
      signed_event_sig: "test_signature_123"
    )
  end

  it "displays the created bookmark" do
    visit bookmarks_path
    
    expect(page).to have_content("Test Bookmark")
    expect(page).to have_link(@bookmark.url, href: @bookmark.url)
    expect(page).to have_content("A test description")
  end
end
