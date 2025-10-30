class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Database authenticatable
      t.string :email,              null: false, default: ""

      # Google OAuth specific
      t.string :google_id

      t.timestamps null: false
    end
  end
end
