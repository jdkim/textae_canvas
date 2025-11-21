class AddParentToAiAnnotations < ActiveRecord::Migration[7.1]
  def change
    add_reference :ai_annotations, :parent, foreign_key: { to_table: :ai_annotations }, index: true, null: true
  end
end
