require 'rails_helper'

RSpec.describe BookmarkletController, type: :controller do
  let(:user) { User.create!(username: "testuser", public_key: "test_public_key_123", email: "test@example.com") }
  
  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "GET #add" do
    context "with valid parameters" do
      it "creates a new bookmark object with prefilled data" do
        get :add, params: { 
          url: "https://example.com", 
          title: "Test Title", 
          description: "Test description",
          popup: "true"
        }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:bookmark)).to be_a_new(Bookmark)
        expect(assigns(:bookmark).url).to eq("https://example.com")
        expect(assigns(:bookmark).title).to eq("Test Title")
        expect(assigns(:bookmark).description).to eq("Test description")
        expect(assigns(:in_popup)).to be true
      end
    end

    context "without popup parameter" do
      it "renders with application layout" do
        get :add, params: { url: "https://example.com", title: "Test" }
        
        expect(assigns(:in_popup)).to be false
      end
    end
  end

  describe "GET #success" do
    it "renders success page" do
      get :success, params: { popup: "true", nostr_signed: "true" }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:in_popup)).to be true
    end
  end

  describe "GET #instructions" do
    it "renders instructions page" do
      get :instructions
      
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #debug" do
    it "renders debug page" do
      get :debug
      
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    let(:bookmark_params) do
      {
        title: "Test Bookmark",
        url: "https://example.com/test",
        description: "A test bookmark"
      }
    end

    context "with signed Nostr event (JSON request)" do
      let(:signed_event) do
        {
          id: "event_id_123",
          kind: 39701,
          pubkey: "test_public_key_123",
          created_at: Time.current.to_i,
          tags: [
            ["d", "example.com/test"],
            ["title", "Test Bookmark"],
            ["published_at", Time.current.to_i.to_s]
          ],
          content: "A test bookmark",
          sig: "signature_123"
        }
      end

      it "creates a bookmark with signed event data" do
        request.headers['Content-Type'] = 'application/json'
        
        post :create, params: {
          signed_event: signed_event,
          bookmark: bookmark_params,
          popup: true
        }, as: :json

        expect(response).to have_http_status(:success)
        
        created_bookmark = Bookmark.last
        expect(created_bookmark.title).to eq("Test Bookmark")
        expect(created_bookmark.url).to eq("https://example.com/test")
        expect(created_bookmark.event_id).to eq("event_id_123")
        expect(created_bookmark.signed_event_content).to be_present
        expect(created_bookmark.signed_event_sig).to eq("signature_123")
        expect(created_bookmark.user).to eq(user)

        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('success')
        expect(json_response['redirect_url']).to include('nostr_signed=true')
      end

      it "validates NIP-B0 event kind" do
        request.headers['Content-Type'] = 'application/json'
        signed_event[:kind] = 1 # Wrong kind
        
        post :create, params: {
          signed_event: signed_event,
          bookmark: bookmark_params
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(match(/Invalid event kind.*expected 39701/))
      end

      it "validates required event fields" do
        request.headers['Content-Type'] = 'application/json'
        signed_event.delete(:sig) # Missing signature
        
        post :create, params: {
          signed_event: signed_event,
          bookmark: bookmark_params
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include(match(/Missing required event fields/))
      end

      it "finds user by public key from event" do
        request.headers['Content-Type'] = 'application/json'
        different_user = User.create!(username: "differentuser", public_key: "different_key_456", email: "different@example.com")
        signed_event[:pubkey] = "different_key_456"
        
        post :create, params: {
          signed_event: signed_event,
          bookmark: bookmark_params
        }, as: :json

        expect(response).to have_http_status(:success)
        created_bookmark = Bookmark.last
        expect(created_bookmark.user).to eq(different_user)
      end
    end

    context "without signed event (JSON request)" do
      it "creates a bookmark without Nostr integration" do
        request.headers['Content-Type'] = 'application/json'
        
        post :create, params: {
          bookmark: bookmark_params,
          popup: true
        }, as: :json

        expect(response).to have_http_status(:success)
        
        created_bookmark = Bookmark.last
        expect(created_bookmark.title).to eq("Test Bookmark")
        expect(created_bookmark.url).to eq("https://example.com/test")
        expect(created_bookmark.event_id).to start_with("manual-")
        expect(created_bookmark.signed_event_content).to be_nil
        expect(created_bookmark.signed_event_sig).to be_nil
        expect(created_bookmark.user).to eq(user)

        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('success')
        expect(json_response['redirect_url']).to include('nostr_signed=false')
      end
    end

    context "form submission (HTML request)" do
      it "creates a bookmark with manual event ID" do
        post :create, params: {
          bookmark: bookmark_params,
          popup: true
        }

        expect(response).to have_http_status(:redirect)
        
        created_bookmark = Bookmark.last
        expect(created_bookmark.title).to eq("Test Bookmark")
        expect(created_bookmark.url).to eq("https://example.com/test")
        expect(created_bookmark.event_id).to start_with("manual-")
        expect(created_bookmark.signed_event_content).to be_nil
        expect(created_bookmark.user).to eq(user)
      end

      it "handles validation errors" do
        post :create, params: {
          bookmark: { title: "", url: "", description: "" }
        }

        expect(response).to have_http_status(:success) # Re-renders form
        expect(response.body).to include("prohibited this bookmark from being saved")
      end
    end

    context "missing required bookmark parameters" do
      it "returns error for JSON request" do
        request.headers['Content-Type'] = 'application/json'
        
        post :create, params: {
          bookmark: { title: "", url: "" }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Missing required bookmark parameters")
      end
    end
  end
end
