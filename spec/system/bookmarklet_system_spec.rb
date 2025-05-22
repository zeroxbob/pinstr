require 'rails_helper'

RSpec.describe "Bookmarklet System", type: :system do
  let(:user) { User.create!(username: "testuser", public_key: "test_public_key_123", email: "test@example.com") }
  
  before do
    driven_by(:rack_test)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe "Bookmarklet form" do
    it "displays the bookmarklet form with prefilled data" do
      visit bookmarklet_path(
        url: "https://example.com/article",
        title: "Example Article",
        description: "Selected text from article",
        popup: "true"
      )

      expect(page).to have_content("Save Bookmark to Pinstr")
      expect(page).to have_field("Title", with: "Example Article")
      expect(page).to have_field("Url", with: "https://example.com/article")
      expect(page).to have_field("Description", with: "Selected text from article")
      expect(page).to have_button("Save Bookmark")
      expect(page).to have_button("Cancel")
    end

    it "shows Nostr extension status" do
      visit bookmarklet_path(popup: "true")

      expect(page).to have_content("Checking for Nostr extension")
    end

    it "includes helpful links" do
      visit bookmarklet_path(popup: "true")

      expect(page).to have_link("Nostr not working?")
    end
  end

  describe "Bookmarklet success page" do
    it "shows success message with Nostr signing status" do
      visit success_bookmarklet_path(popup: true, nostr_signed: true)

      expect(page).to have_content("Bookmark Saved!")
      expect(page).to have_content("signed with Nostr")
      expect(page).to have_content("published to relays")
      expect(page).to have_button("Close")
      expect(page).to have_link("View All Bookmarks")
    end

    it "shows success message without Nostr signing" do
      visit success_bookmarklet_path(popup: true, nostr_signed: false)

      expect(page).to have_content("Bookmark Saved!")
      expect(page).to have_content("saved without Nostr signing")
      expect(page).to have_link("Set up Nostr integration")
    end
  end

  describe "Bookmarklet instructions page" do
    it "displays comprehensive instructions" do
      visit bookmarklet_instructions_path

      expect(page).to have_content("Pinstr Bookmarklet")
      expect(page).to have_content("Installation")
      expect(page).to have_content("How to Use")
      expect(page).to have_content("Nostr Integration")
      expect(page).to have_content("Troubleshooting")
      
      # Should have the actual bookmarklet link
      expect(page).to have_link("Save to Pinstr")
      
      # Should mention recommended extensions
      expect(page).to have_content("Alby")
      expect(page).to have_content("nos2x")
      
      # Should have links to external resources
      expect(page).to have_link("Get Alby")
      expect(page).to have_link("Get nos2x")
    end
  end

  describe "Bookmarklet debug page" do
    it "displays debugging tools" do
      visit debug_bookmarklet_path

      expect(page).to have_content("Nostr Extension Debug")
      expect(page).to have_content("Real-time Nostr Detection")
      expect(page).to have_content("Browser Information")
      expect(page).to have_content("Test Results")
      
      expect(page).to have_button("Manual Check")
      expect(page).to have_button("Test getPublicKey")
      expect(page).to have_button("Test signEvent")
      
      expect(page).to have_content("User Agent")
      expect(page).to have_content("Extensions Detected")
    end
  end

  describe "Form submission (HTML fallback)" do
    it "successfully creates a bookmark via form submission" do
      visit bookmarklet_path

      fill_in "Title", with: "Test Bookmark"
      fill_in "Url", with: "https://example.com/test"
      fill_in "Description", with: "A test bookmark from system spec"
      
      expect {
        click_button "Save Bookmark"
      }.to change(Bookmark, :count).by(1)

      # Should redirect to success page
      expect(page).to have_current_path(/bookmarklet\/success/)
      expect(page).to have_content("Bookmark Saved!")

      # Verify the bookmark was created correctly
      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Bookmark")
      expect(bookmark.url).to eq("https://example.com/test")
      expect(bookmark.description).to eq("A test bookmark from system spec")
      expect(bookmark.user).to eq(user)
      expect(bookmark.event_id).to start_with("manual-")
    end

    it "displays validation errors for invalid input" do
      visit bookmarklet_path

      # Leave required fields empty
      fill_in "Title", with: ""
      fill_in "Url", with: ""
      
      click_button "Save Bookmark"

      expect(page).to have_content("prohibited this bookmark from being saved")
      expect(page).to have_content("can't be blank")
      expect(Bookmark.count).to eq(0)
    end
  end

  describe "Responsive design and accessibility" do
    it "has accessible form labels and structure" do
      visit bookmarklet_path

      expect(page).to have_css("label[for='bookmark_title']", text: "Title")
      expect(page).to have_css("label[for='bookmark_url']", text: "Url")  
      expect(page).to have_css("label[for='bookmark_description']", text: "Description")
      
      expect(page).to have_css("input[required]#bookmark_title")
      expect(page).to have_css("input[required]#bookmark_url")
    end

    it "includes proper meta tags for mobile" do
      visit bookmarklet_path(popup: "true")

      expect(page).to have_css("meta[name='viewport']", visible: false)
    end
  end

  describe "JavaScript functionality" do
    before do
      driven_by(:selenium_chrome_headless)
    end

    it "displays dynamic Nostr status messages", js: true do
      visit bookmarklet_path(popup: "true")

      # Should show initial checking message
      expect(page).to have_content("Checking for Nostr extension")
      
      # Since we don't have actual Nostr extension in test,
      # should eventually show "No Nostr extension detected"
      expect(page).to have_content("No Nostr extension detected", wait: 15)
    end

    it "prevents multiple form submissions", js: true do
      visit bookmarklet_path

      fill_in "Title", with: "Test Bookmark"
      fill_in "Url", with: "https://example.com/test"
      
      # Click submit button multiple times rapidly
      find("#submit-button").click
      find("#submit-button").click
      find("#submit-button").click

      # Should only create one bookmark
      expect(Bookmark.count).to eq(1)
    end

    it "disables submit button during submission", js: true do
      visit bookmarklet_path

      fill_in "Title", with: "Test Bookmark"
      fill_in "Url", with: "https://example.com/test"
      
      submit_button = find("#submit-button")
      submit_button.click
      
      # Button should be disabled and text changed
      expect(submit_button).to be_disabled
      expect(submit_button.value).to eq("Saving...")
    end
  end

  describe "Popup window behavior" do
    it "includes popup-specific styling and behavior" do
      visit bookmarklet_path(popup: "true")

      # Should use bookmarklet layout
      expect(page).to have_css("body")
      expect(page).to have_content("Save Bookmark to Pinstr")
      
      # Should have Cancel button that could close window
      expect(page).to have_button("Cancel")
    end
  end
end
