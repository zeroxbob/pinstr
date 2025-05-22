require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#bookmarklet_code" do
    before do
      allow(Rails.env).to receive(:development?).and_return(true)
    end

    it "generates JavaScript code for the bookmarklet" do
      code = helper.bookmarklet_code

      expect(code).to be_a(String)
      expect(code).to include("localhost:3000")
      expect(code).to include("/bookmarklet?popup=true")
      expect(code).to include("encodeURIComponent")
      expect(code).to include("window.open")
      expect(code).to include("Pinstr")
    end

    it "includes proper window dimensions" do
      code = helper.bookmarklet_code

      expect(code).to include("width=750")
      expect(code).to include("height=700")
      expect(code).to include("toolbar=no")
      expect(code).to include("scrollbars=yes")
    end

    it "handles Firefox browser detection" do
      code = helper.bookmarklet_code

      expect(code).to include("Firefox")
      expect(code).to include("setTimeout")
    end

    it "captures page data correctly" do
      code = helper.bookmarklet_code

      # Should capture URL
      expect(code).to include("location.href")
      
      # Should capture title
      expect(code).to include("document.title")
      
      # Should capture selected text
      expect(code).to include("getSelection")
      expect(code).to include("createRange")
    end

    context "in production environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(helper.request).to receive(:base_url).and_return("https://example.com")
      end

      it "uses request.base_url instead of localhost" do
        code = helper.bookmarklet_code

        expect(code).to include("https://example.com")
        expect(code).not_to include("localhost")
      end
    end
  end

  describe "#bookmarklet_code_debug" do
    before do
      allow(Rails.env).to receive(:development?).and_return(true)
    end

    it "generates readable JavaScript code for debugging" do
      code = helper.bookmarklet_code_debug

      expect(code).to be_a(String)
      expect(code).to include("localhost:3000")
      expect(code).to include("/bookmarklet?popup=true")
      
      # Should be more readable than minified version
      expect(code).to include("\n") # Contains newlines
      expect(code).to include("  ") # Contains indentation
      expect(code).to include("// ") # Contains comments
    end

    it "has the same functionality as minified version" do
      minified = helper.bookmarklet_code
      readable = helper.bookmarklet_code_debug

      # Both should include the same core functionality
      %w[encodeURIComponent window.open document.title location.href getSelection].each do |func|
        expect(minified).to include(func)
        expect(readable).to include(func)
      end
    end

    it "includes helpful comments" do
      code = helper.bookmarklet_code_debug

      expect(code).to include("Get the current document")
      expect(code).to include("Get any selected text")
      expect(code).to include("Get current page URL")
      expect(code).to include("Encode parameters")
      expect(code).to include("Function to open popup")
    end
  end

  describe "bookmarklet code functionality" do
    it "creates properly encoded URLs" do
      code = helper.bookmarklet_code

      # Should use encodeURIComponent for URL parameters
      expect(code).to include("encodeURIComponent(l.href)")
      expect(code).to include("encodeURIComponent(d.title)")
      expect(code).to include("encodeURIComponent(s)")
    end

    it "handles popup blocking gracefully" do
      code = helper.bookmarklet_code

      # Should fallback to direct navigation if popup is blocked
      expect(code).to include("if(!w.open")
      expect(code).to include("l.href=p+")
    end

    it "constructs proper query parameters" do
      code = helper.bookmarklet_code

      expect(code).to include("&url=")
      expect(code).to include("&title=")
      expect(code).to include("&description=")
    end
  end
end
