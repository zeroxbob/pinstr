class CreateRelays < ActiveRecord::Migration[8.0]
  def change
    create_table :relays do |t|
      t.string :url, null: false
      t.string :name
      t.text :description
      t.datetime :last_connected_at

      t.timestamps
    end
    
    add_index :relays, :url, unique: true
  end
end
