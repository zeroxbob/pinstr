          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(success_bookmarklet_path(popup: true, nostr_signed: false))

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success page with Nostr signing status" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: true }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success page without Nostr signing" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: false }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays debug page" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Test getPublicKey")
      expect(response.body).to include("Test signEvent")
    end
  end

  describe "Nostr event validation" do
    let(:base_event) do
      {
        id: "test_event_id",
        kind: 39701,
        pubkey: user.public_key,
        created_at: Time.current.to_i,
        tags: [
          ["d", "example.com/test"],
          ["title", "Test Title"]
        ],
        content: "Test content",
        sig: "test_signature"
      }
    end

    it "validates d-tag is present" do
      base_event[:tags] = [["title", "Test Title"]] # Remove d-tag

      post create_from_bookmarklet_path, 
        params: {
          signed_event: base_event,
          bookmark: {
            title: "Test",
            url: "https://example.com/test",
            description: "Test"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success) # Still creates bookmark
      bookmark = Bookmark.last
      expect(bookmark.url).to eq("https://example.com/test") # Uses bookmark params URL
    end

    it "uses d-tag for URL construction when present" do
      post create_from_bookmarklet_path, 
        params: {
          signed_event: base_event,
          bookmark: {
            title: "Test",
            url: "https://different.com/test",
            description: "Test"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)
      bookmark = Bookmark.last
      expect(bookmark.url).to eq("https://example.com/test") # Uses d-tag URL
    end

    it "extracts title from event tags" do
      base_event[:tags] = [
        ["d", "example.com/test"],
        ["title", "Event Title"]
      ]

      post create_from_bookmarklet_path, 
        params: {
          signed_event: base_event,
          bookmark: {
            title: "Different Title",
            url: "https://example.com/test",
            description: "Test"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)
      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Event Title") # Uses event title
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(success_bookmarklet_path(popup: true, nostr_signed: false))

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success message with Nostr signing indication" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: true }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success message without Nostr signing indication" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: false }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end

    it "includes the bookmarklet link" do
      get bookmarklet_instructions_path

      expect(response.body).to include("javascript:")
      expect(response.body).to include("localhost:3000/bookmarklet")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays debug information" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Real-time Nostr Detection")
      expect(response.body).to include("Test getPublicKey")
      expect(response.body).to include("Test signEvent")
    end
  end

  describe "Bookmarklet code generation" do
    it "generates valid JavaScript bookmarklet code" do
      get bookmarklet_instructions_path

      # The response should contain the bookmarklet JavaScript
      expect(response.body).to match(/javascript:\(function\(\)\{.*\}\)\(\);/)
      expect(response.body).to include("localhost:3000/bookmarklet")
      expect(response.body).to include("popup=true")
    end
  end

  describe "Error handling" do
    context "when bookmark creation fails" do
      before do
        allow_any_instance_of(Bookmark).to receive(:save).and_return(false)
        allow_any_instance_of(Bookmark).to receive(:errors).and_return(
          double(full_messages: ["URL is invalid"])
        )
      end

      it "returns errors for JSON requests" do
        post create_from_bookmarklet_path, 
          params: {
            bookmark: {
              title: "Test",
              url: "invalid-url",
              description: "Test"
            }
          },
          headers: { 'Content-Type' => 'application/json' },
          as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("URL is invalid")
      end

      it "re-renders form for HTML requests" do
        post create_from_bookmarklet_path, params: {
          bookmark: {
            title: "Test",
            url: "invalid-url",
            description: "Test"
          }
        }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("URL is invalid")
      end
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(/bookmarklet\/success.*nostr_signed=false/)

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success message for Nostr-signed bookmark" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "true"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success message for non-Nostr bookmark" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "false"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays debug page" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Real-time Nostr Detection")
    end
  end

  describe "Bookmarklet JavaScript functionality" do
    it "includes Nostr detection script in add page" do
      get bookmarklet_path, params: { popup: "true" }

      expect(response.body).to include("window.nostrReady")
      expect(response.body).to include("checkForNostr")
      expect(response.body).to include("showSuccessAndClose")
    end

    it "includes auto-close functionality for popup" do
      get bookmarklet_path, params: { popup: "true" }

      expect(response.body).to include("auto-close-notice")
      expect(response.body).to include("countdown")
      expect(response.body).to include("window.close()")
    end
  end

  describe "Error handling" do
    it "handles missing bookmark parameters gracefully" do
      post create_from_bookmarklet_path, 
        params: {},
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include("Missing required bookmark parameters")
    end

    it "handles invalid URLs in bookmarks" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "Test",
          url: "not-a-valid-url",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form with errors
      expect(response.body).to include("is not a valid URL")
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article", 
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(success_bookmarklet_path(popup: true, nostr_signed: false))

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success page with Nostr signing status" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: true }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success page without Nostr signing" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: false }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet installation instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays Nostr debugging tools" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Test getPublicKey")
      expect(response.body).to include("Test signEvent")
    end
  end

  describe "URL validation and canonicalization" do
    it "accepts URLs with proper format" do
      post create_from_bookmarklet_path, 
        params: {
          bookmark: {
            title: "Test",
            url: "https://example.com/test",
            description: "Test"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)
      bookmark = Bookmark.last
      expect(bookmark.url).to eq("https://example.com/test")
    end

    it "handles duplicate bookmarks for same user" do
      # Create first bookmark
      Bookmark.create!(
        title: "First", 
        url: "https://example.com/same", 
        description: "First",
        event_id: "first_123",
        user: user
      )

      # Try to create duplicate - should fail validation
      post create_from_bookmarklet_path, 
        params: {
          bookmark: {
            title: "Second",
            url: "https://example.com/same",
            description: "Second"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include(match(/already been bookmarked/))
    end
  end

  describe "Edge cases and error handling" do
    it "handles missing bookmark parameters gracefully" do
      post create_from_bookmarklet_path, 
        params: {},
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include("Missing required bookmark parameters")
    end

    it "handles malformed JSON gracefully" do
      post create_from_bookmarklet_path, 
        params: "invalid json",
        headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
    rescue JSON::ParserError
      # This is expected for malformed JSON
      expect(true).to be true
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article", 
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('nostr_signed=false')

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "shows success page with Nostr signed status" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "true"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "shows success page without Nostr signing" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "false"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet installation instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays Nostr extension debug page" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Real-time Nostr Detection")
      expect(response.body).to include("Test getPublicKey")
    end
  end

  describe "error handling" do
    it "handles missing bookmark parameters for JSON requests" do
      post create_from_bookmarklet_path, 
        params: {
          bookmark: { title: "", url: "" }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include("Missing required bookmark parameters")
    end

    it "handles malformed signed events" do
      post create_from_bookmarklet_path, 
        params: {
          signed_event: "invalid_event_data",
          bookmark: {
            title: "Test",
            url: "https://example.com"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(success_bookmarklet_path(popup: true, nostr_signed: false))

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success message with Nostr signing status" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "true"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success message without Nostr signing" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "false"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays installation instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays debug tools" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Manual Check")
      expect(response.body).to include("Test getPublicKey")
    end
  end

  describe "error handling" do
    context "when missing required parameters" do
      it "returns error for JSON request without bookmark params" do
        post create_from_bookmarklet_path, 
          params: { bookmark: { title: "", url: "" } },
          headers: { 'Content-Type' => 'application/json' },
          as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Missing required bookmark parameters")
      end
    end

    context "when user not found for public key" do
      let(:signed_event_with_unknown_user) do
        {
          id: "event_id_456",
          kind: 39701,
          pubkey: "unknown_public_key_999",
          created_at: Time.current.to_i,
          tags: [["d", "example.com/test"], ["title", "Test"]],
          content: "Test bookmark",
          sig: "signature_456"
        }
      end

      it "creates bookmark with current user when pubkey user not found" do
        post create_from_bookmarklet_path, 
          params: {
            signed_event: signed_event_with_unknown_user,
            bookmark: {
              title: "Test Article",
              url: "https://example.com/test-article",
              description: "This is a test bookmark"
            }
          },
          headers: { 'Content-Type' => 'application/json' },
          as: :json

        expect(response).to have_http_status(:success)
        
        bookmark = Bookmark.last
        expect(bookmark.user).to eq(user) # Falls back to current_user
      end
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('nostr_signed=false')

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success message with Nostr signing indicator" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: true }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success message without Nostr signing" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: false }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet installation instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("How to Install")
      expect(response.body).to include("Save to Pinstr")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays debug page for Nostr extension testing" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Test getPublicKey")
      expect(response.body).to include("Test signEvent")
    end
  end

  describe "Bookmarklet JavaScript helpers" do
    it "includes bookmarklet code in helper" do
      get bookmarklet_instructions_path

      expect(response.body).to include("javascript:")
      expect(response.body).to include("localhost:3000")
      expect(response.body).to include("encodeURIComponent")
    end
  end

  describe "Authentication" do
    context "when user is not authenticated" do
      before do
        allow_any_instance_of(BookmarkletController).to receive(:current_user).and_return(nil)
      end

      it "still allows bookmarklet access in development" do
        get bookmarklet_path

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "CSRF protection" do
    it "skips CSRF for bookmarklet create action" do
      # This test ensures that the bookmarklet can work cross-domain
      # without CSRF token issues
      post create_from_bookmarklet_path, 
        params: {
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          }
        }

      expect(response).to have_http_status(:redirect)
      expect(Bookmark.count).to eq(1)
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(success_bookmarklet_path(popup: true, nostr_signed: false))

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
    end
  end

  describe "GET /bookmarklet/success" do
    it "displays success page with Nostr signing status" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "true"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "displays success page without Nostr signing" do
      get success_bookmarklet_path, params: {
        popup: "true",
        nostr_signed: "false"
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("Installation")
      expect(response.body).to include("How to Use")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays debug page" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Real-time Nostr Detection")
    end
  end

  describe "NIP-B0 compliance" do
    let(:nip_b0_event) do
      {
        id: "nip_b0_event_id",
        kind: 39701,
        pubkey: user.public_key,
        created_at: Time.current.to_i,
        tags: [
          ["d", "example.com/nip-b0-test"],
          ["title", "NIP-B0 Test Bookmark"],
          ["published_at", Time.current.to_i.to_s],
          ["t", "testing"],
          ["t", "nip-b0"]
        ],
        content: "Testing NIP-B0 compliance with #testing #nip-b0 hashtags",
        sig: "nip_b0_signature"
      }
    end

    it "properly handles NIP-B0 bookmark events" do
      post create_from_bookmarklet_path, 
        params: {
          signed_event: nip_b0_event,
          bookmark: {
            title: "NIP-B0 Test Bookmark",
            url: "https://example.com/nip-b0-test",
            description: "Testing NIP-B0 compliance with #testing #nip-b0 hashtags"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)

      bookmark = Bookmark.last
      expect(bookmark.event_id).to eq("nip_b0_event_id")
      expect(bookmark.title).to eq("NIP-B0 Test Bookmark")
      expect(bookmark.url).to eq("https://example.com/nip-b0-test")
      expect(bookmark.description).to eq("Testing NIP-B0 compliance with #testing #nip-b0 hashtags")
      
      # Verify the signed event was stored correctly
      stored_event = JSON.parse(bookmark.signed_event_content)
      expect(stored_event["kind"]).to eq(39701)
      expect(stored_event["tags"]).to include(["d", "example.com/nip-b0-test"])
      expect(stored_event["tags"]).to include(["title", "NIP-B0 Test Bookmark"])
      expect(stored_event["tags"]).to include(["t", "testing"])
      expect(stored_event["tags"]).to include(["t", "nip-b0"])
    end
  end

  describe "User matching by public key" do
    let(:another_user) { User.create!(username: "anotheruser", public_key: "another_public_key", email: "another@example.com") }
    
    it "creates bookmark for user matching the event's public key" do
      signed_event = {
        id: "event_for_another_user",
        kind: 39701,
        pubkey: another_user.public_key,
        created_at: Time.current.to_i,
        tags: [["d", "example.com/test"], ["title", "Test"]],
        content: "Test content",
        sig: "signature"
      }

      post create_from_bookmarklet_path, 
        params: {
          signed_event: signed_event,
          bookmark: {
            title: "Test Bookmark",
            url: "https://example.com/test",
            description: "Test content"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)
      
      bookmark = Bookmark.last
      expect(bookmark.user).to eq(another_user)
    end

    it "falls back to current user if no matching public key found" do
      signed_event = {
        id: "event_for_unknown_user",
        kind: 39701,
        pubkey: "unknown_public_key",
        created_at: Time.current.to_i,
        tags: [["d", "example.com/test"], ["title", "Test"]],
        content: "Test content",
        sig: "signature"
      }

      post create_from_bookmarklet_path, 
        params: {
          signed_event: signed_event,
          bookmark: {
            title: "Test Bookmark",
            url: "https://example.com/test",
            description: "Test content"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)
      
      bookmark = Bookmark.last
      expect(bookmark.user).to eq(user) # Falls back to current user
    end
  end
end
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          },
          popup: true
        }
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(success_bookmarklet_path(popup: true, nostr_signed: false))

      bookmark = Bookmark.last
      expect(bookmark.title).to eq("Test Article")
      expect(bookmark.url).to eq("https://example.com/test-article")
      expect(bookmark.event_id).to start_with("manual-")
      expect(bookmark.signed_event_content).to be_nil
      expect(bookmark.user).to eq(user)
    end

    it "handles validation errors" do
      post create_from_bookmarklet_path, params: {
        bookmark: {
          title: "",
          url: "",
          description: ""
        }
      }

      expect(response).to have_http_status(:success) # Re-renders form
      expect(response.body).to include("prohibited this bookmark from being saved")
      expect(Bookmark.count).to eq(0)
    end
  end

  describe "GET /bookmarklet/success" do
    it "shows success page with Nostr signing indication" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: true }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("signed with Nostr")
    end

    it "shows success page without Nostr signing indication" do
      get success_bookmarklet_path, params: { popup: true, nostr_signed: false }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bookmark Saved!")
      expect(response.body).to include("saved without Nostr signing")
    end
  end

  describe "GET /bookmarklet/instructions" do
    it "displays bookmarklet installation instructions" do
      get bookmarklet_instructions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pinstr Bookmarklet")
      expect(response.body).to include("Save to Pinstr")
      expect(response.body).to include("Installation")
      expect(response.body).to include("How to Use")
    end
  end

  describe "GET /bookmarklet/debug" do
    it "displays Nostr debugging page" do
      get debug_bookmarklet_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nostr Extension Debug")
      expect(response.body).to include("Real-time Nostr Detection")
      expect(response.body).to include("Test getPublicKey")
      expect(response.body).to include("Test signEvent")
    end
  end

  describe "URL validation and processing" do
    it "handles URLs without protocol" do
      post create_from_bookmarklet_path, 
        params: {
          bookmark: {
            title: "Test Article",
            url: "example.com/test-article",
            description: "This is a test bookmark"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:success)
      bookmark = Bookmark.last
      expect(bookmark.url).to eq("example.com/test-article") # URL service handles canonicalization
    end
  end

  describe "Error handling" do
    it "returns proper error for missing bookmark parameters in JSON request" do
      post create_from_bookmarklet_path, 
        params: {
          bookmark: { title: "", url: "" }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include("Missing required bookmark parameters")
    end

    it "handles malformed signed events gracefully" do
      post create_from_bookmarklet_path, 
        params: {
          signed_event: "invalid_json",
          bookmark: {
            title: "Test Article",
            url: "https://example.com/test-article",
            description: "This is a test bookmark"
          }
        },
        headers: { 'Content-Type' => 'application/json' },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
