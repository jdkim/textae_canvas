class AddIdTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :id_token, :text
  end
end
