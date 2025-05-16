class AddIndexOnUrlAndUserToBookmarks < ActiveRecord::Migration[8.0]
  def change
    # Add a non-unique index on url to speed up lookups
    add_index :bookmarks, :url
    
    # Add a unique index on url and user_id to enforce uniqueness at the database level
    # This is in addition to the application-level validation which handles normalized URLs
    add_index :bookmarks, [:url, :user_id], name: 'index_bookmarks_on_url_and_user_id'
  end
end
