require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#bookmarklet_code" do
    it "generates JavaScript bookmarklet code for development" do
      allow(Rails.env).to receive(:development?).and_return(true)
      
      code = helper.bookmarklet_code
      
      expect(code).to include("http://localhost:3000/bookmarklet")
      expect(code).to include("popup=true")
      expect(code).to include("encodeURIComponent")
      expect(code).to include("window.open")
      expect(code).to include("toolbar=no")
      expect(code).to include("width=750")
      expect(code).to include("height=700")
    end

    it "generates JavaScript bookmarklet code for production" do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(helper).to receive(:request).and_return(double(base_url: "https://example.com"))
      
      code = helper.bookmarklet_code
      
      expect(code).to include("https://example.com/bookmarklet")
      expect(code).to include("popup=true")
    end

    it "captures current page URL and title" do
      code = helper.bookmarklet_code
      
      expect(code).to include("d.location.href")
      expect(code).to include("d.title")
    end

    it "captures selected text" do
      code = helper.bookmarklet_code
      
      expect(code).to include("getSelection")
      expect(code).to include("createRange")
    end

    it "handles Firefox specifically" do
      code = helper.bookmarklet_code
      
      expect(code).to include("Firefox")
      expect(code).to include("setTimeout")
    end

    it "falls back to redirect if popup is blocked" do
      code = helper.bookmarklet_code
      
      expect(code).to include("if(!w.open")
      expect(code).to include("l.href=")
    end
  end

  describe "#bookmarklet_code_debug" do
    it "generates readable JavaScript code for debugging" do
      allow(Rails.env).to receive(:development?).and_return(true)
      
      code = helper.bookmarklet_code_debug
      
      expect(code).to include("// Get the current document")
      expect(code).to include("// Get any selected text")
      expect(code).to include("// Parse the URL")
      expect(code).to include("// Function to open popup")
      expect(code).to include("bookmarkletUrl =")
      expect(code).to include("localhost:3000")
    end

    it "includes comments explaining each step" do
      code = helper.bookmarklet_code_debug
      
      expect(code).to include("// Get the current document and window")
      expect(code).to include("// Get any selected text on the page")
      expect(code).to include("// Get current page URL and title")
      expect(code).to include("// Encode parameters for the URL")
      expect(code).to include("// Try to open a popup window")
      expect(code).to include("// If popup is blocked, redirect instead")
    end
  end
end
