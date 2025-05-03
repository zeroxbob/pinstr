require 'rails_helper'

RSpec.describe "Bookmarks", type: :request do
  describe "POST /bookmarks" do
    let(:user) { User.create!(username: "testuser", public_key: "testpubkey") }
    let(:valid_attributes) do
      {
        title: "Test Bookmark",
        url: "http://example.com",
        description: "A test description"
      }
    end
    let(:valid_signed_event) do
      {
        id: "abc123",
        pubkey: user.public_key,
        sig: "signature123"
      }
    end

    context "with valid parameters" do
      it "creates a new Bookmark" do
        expect {
          post bookmarks_path, params: { bookmark: valid_attributes, signed_event: valid_signed_event }, as: :json
        }.to change(Bookmark, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"status":"success"')
      end
    end

    context "with invalid parameters" do
      it "does not create a new Bookmark" do
        expect {
          post bookmarks_path, params: { bookmark: valid_attributes.except(:title), signed_event: valid_signed_event }, as: :json
        }.to change(Bookmark, :count).by(0)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
