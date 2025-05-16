class AdminController < ApplicationController
  before_action :authenticate_user! # Assuming you have this method
  
  def dashboard
    @bookmarks = Bookmark.all.order(created_at: :desc)
    
    # Count event types
    @nipb0_count = 0
    @legacy_count = 0
    
    @bookmarks.each do |bookmark|
      if bookmark.signed_event_content.present?
        begin
          event = JSON.parse(bookmark.signed_event_content)
          kind = event['kind'] || event[:kind]
          
          if kind == 39701
            @nipb0_count += 1
          elsif kind == 30001
            @legacy_count += 1
          end
        rescue
          # Skip invalid events
        end
      end
    end
  end
end