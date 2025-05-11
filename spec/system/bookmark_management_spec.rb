require 'rails_helper'

RSpec.describe "Bookmark Management", type: :system do
  before do
    User.create!(username: "testuser", public_key: "testpubkey")
  end

  it "creates a new bookmark successfully" do
    puts 'hi from before visit'
    visit new_bookmark_path
    puts 'hi from bookmark path'
    puts Capybara.current_driver

    fill_in "Title", with: "Test Bookmark"
    fill_in "Url", with: "https://www.greatblog.com/amazing_post"
    fill_in "Description", with: "A test description"

    # Simulate Nostr extension for signing
    page.execute_script(<<-JS)
      window.nostr = {
        signEvent: function() {
          return Promise.resolve({ id: "abc123", pubkey: "testpubkey", sig: "signature123" });
        }
      }
    JS

    click_button "Create Bookmark"

    expect(Bookmark.last.url).to eq("https://www.greatblog.com/amazing_post")
    # expect(page).to have_content("Bookmark was successfully created")
    # expect(page).to have_current_path(bookmarks_path)
  end
end
