class Bookmark < ApplicationRecord
  belongs_to :user
  validates :url, presence: true
  validates :title, presence: true
  validates :event_id, presence: true, uniqueness: true

  after_create :schedule_event_publication

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
