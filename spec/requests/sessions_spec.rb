require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /index" do
    pending "add some examples (or delete) #{__FILE__}"
  end

  describe "POST /auth" do
    it "creates a session for a valid public key" do
      post "/auth", params: { public_key: "test_pubkey_123" }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Logged in with public key test_pubkey_123")
    end

    it "rejects empty public key" do
      post "/auth", params: { public_key: "" }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("No public key provided")
    end
  end

  describe "DELETE /auth" do
    it "logs out user" do
      user = User.create!(public_key: "test_pubkey_456", email: "test@example.com")
      post "/auth", params: { public_key: user.public_key }
      delete "/auth"
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Logged out")
    end
  end
end
