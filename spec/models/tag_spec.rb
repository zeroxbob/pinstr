require "rails_helper"

RSpec.describe Tag, type: :model do
  it "is valid with a unique name" do
    tag = Tag.new(name: "TagOne")
    expect(tag).to be_valid
  end

  it "requires a name" do
    tag = Tag.new(name: nil)
    expect(tag).not_to be_valid
  end

  it "requires the name to be unique" do
    Tag.create!(name: "Duplicate")
    tag = Tag.new(name: "Duplicate")
    expect(tag).not_to be_valid
  end
end
