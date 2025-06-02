require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /new" do
    it "renders the login form" do
      get "/sessions/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Login with Nostr")
    end
  end

  describe "POST /auth" do
    context "with JSON format" do
      it "creates a session for a valid public key" do
        post "/auth", params: { public_key: "test_pubkey_123" }, as: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include("success" => true, "message" => "Logged in successfully")
        expect(session[:user_id]).not_to be_nil
      end

      it "rejects empty public key" do
        post "/auth", params: { public_key: "" }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include("error" => "No public key provided")
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe "DELETE /auth" do
    context "with JSON format" do
      it "logs out user" do
        user = User.create!(public_key: "test_pubkey_456", username: "test_user_#{Time.now.to_i}")
        post "/auth", params: { public_key: user.public_key }, as: :json
        expect(session[:user_id]).to eq(user.id)
        
        delete "/auth", as: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include("success" => true, "message" => "Logged out successfully")
        expect(session[:user_id]).to be_nil
      end
    end
  end
end
