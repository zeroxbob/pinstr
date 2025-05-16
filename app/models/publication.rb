class Publication < ApplicationRecord
  belongs_to :bookmark
  belongs_to :relay
  
  validates :bookmark_id, uniqueness: { scope: :relay_id }
  validates :published_at, presence: true
  
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  
  def self.record_publication(bookmark, relay, success, error_message = nil)
    publication = find_or_initialize_by(bookmark: bookmark, relay: relay)
    publication.published_at = Time.current
    publication.success = success
    publication.error_message = error_message if error_message.present?
    publication.save!
    publication
  end
end
