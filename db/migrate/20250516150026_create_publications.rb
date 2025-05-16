class CreatePublications < ActiveRecord::Migration[8.0]
  def change
    create_table :publications do |t|
      t.references :bookmark, null: false, foreign_key: true
      t.references :relay, null: false, foreign_key: true
      t.datetime :published_at, null: false
      t.boolean :success, default: true
      t.text :error_message

      t.timestamps
    end
    
    add_index :publications, [:bookmark_id, :relay_id], unique: true
  end
end
