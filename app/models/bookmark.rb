class Bookmark < ApplicationRecord
  belongs_to :user
  validates :url, presence: true
  validates :title, presence: true
  validates :event_id, presence: true, uniqueness: true
  
  has_many :publications, dependent: :destroy
  has_many :relays, through: :publications
  
  after_create :schedule_event_publication
  
  def record_publication(relay, success, error_message = nil)
    Publication.record_publication(self, relay, success, error_message)
  end
  
  def published_to_relay?(relay)
    publications.successful.exists?(relay: relay)
  end
  
  def successful_publications
    publications.successful
  end
  
  def failed_publications
    publications.failed
  end
  
  private
  
  def schedule_event_publication
    return unless signed_event_content.present?
    
    begin
      event_data = JSON.parse(signed_event_content)
      PublishNostrEventJob.perform_later(event_data)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse signed event content: #{e.message}")
    end
  end
end
