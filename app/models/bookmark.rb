class Bookmark < ApplicationRecord
  belongs_to :user
  validates :url, presence: true
  validates :title, presence: true
  validates :event_id, presence: true, uniqueness: true
  
  has_many :publications, dependent: :destroy
  has_many :relays, through: :publications
  
  validate :url_must_be_valid
  validate :url_must_be_unique_for_user, on: :create
  
  before_validation :normalize_url
  
  after_create :schedule_event_publication
  
  # Publication related methods
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
  
  # URL related methods
  def self.find_by_url(url)
    normalized_url = UrlService.normalize(url)
    
    # Try to find an exact match first
    bookmark = find_by(url: normalized_url)
    return bookmark if bookmark
    
    # If no exact match, find a bookmark that is equivalent
    all.find do |b|
      UrlService.equivalent?(b.url, normalized_url)
    end
  end
  
  def self.user_has_bookmarked?(user, url)
    normalized_url = UrlService.normalize(url)
    
    # Try to find an exact match first
    return true if user.bookmarks.exists?(url: normalized_url)
    
    # If no exact match, check equivalence
    user.bookmarks.any? do |bookmark|
      UrlService.equivalent?(bookmark.url, normalized_url)
    end
  end
  
  private
  
  def normalize_url
    self.url = UrlService.normalize(url) if url.present?
  end
  
  def url_must_be_valid
    if url.present? && !UrlService.valid?(url)
      errors.add(:url, "is not a valid URL")
    end
  end
  
  def url_must_be_unique_for_user
    if url.present? && user.present? && self.class.user_has_bookmarked?(user, url)
      errors.add(:url, "has already been bookmarked by you")
    end
  end
  
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
