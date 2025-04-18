class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :public_key, null: false
      t.string :username
      t.datetime :last_login

      t.timestamps
    end

    add_index :users, :public_key, unique: true
  end
end
