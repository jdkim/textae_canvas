class AddUserToAiAnnotations < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_annotations, :user, foreign_key: true, index: true, null: true
  end
end
