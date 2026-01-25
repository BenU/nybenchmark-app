class AddSourceTypeToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :source_type, :integer, default: 0, null: false
    add_index :documents, :source_type
  end
end
