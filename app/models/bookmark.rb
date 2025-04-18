class Bookmark < ApplicationRecord
  belongs_to :user
  validates :url, presence: true
  validates :title, presence: true
  validates :event_id, presence: true, uniqueness: true
end
