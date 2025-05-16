require 'rails_helper'

RSpec.describe Relay, type: :model do
  describe "validations" do
    it "requires a url" do
      relay = Relay.new
      expect(relay).not_to be_valid
      expect(relay.errors[:url]).to include("can't be blank")
    end
    
    it "requires a unique url" do
      Relay.create!(url: "wss://test.relay")
      relay = Relay.new(url: "wss://test.relay")
      expect(relay).not_to be_valid
      expect(relay.errors[:url]).to include("has already been taken")
    end
  end
  
  describe "#mark_as_connected" do
    it "updates the last_connected_at timestamp" do
      relay = Relay.create!(url: "wss://test.relay")
      expect(relay.last_connected_at).to be_nil
      
      relay.mark_as_connected
      
      expect(relay.last_connected_at).not_to be_nil
      expect(relay.last_connected_at).to be_within(1.second).of(Time.current)
    end
  end
end
