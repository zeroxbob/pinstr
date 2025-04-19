class AddSignedEventFieldsToBookmarks < ActiveRecord::Migration[8.0]
  def change
    add_column :bookmarks, :signed_event_content, :text
    add_column :bookmarks, :signed_event_sig, :string
  end
end
