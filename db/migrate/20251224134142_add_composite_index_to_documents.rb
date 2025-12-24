class AddCompositeIndexToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_index :documents, [:entity_id, :fiscal_year, :doc_type], unique: true
  end
end