class Relay < ApplicationRecord
  validates :url, presence: true, uniqueness: true
  
  has_many :publications, dependent: :destroy
  has_many :bookmarks, through: :publications
  
  def mark_as_connected
    update(last_connected_at: Time.current)
  end
end
