class CreateBookmarks < ActiveRecord::Migration[7.0]
  def change
    create_table :bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :title, null: false
      t.text :description
      t.string :event_id, null: false
      t.datetime :created_at
    end
    add_index :bookmarks, :event_id, unique: true
  end
end
