class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :title, null: false
      t.string :doc_type, null: false
      t.integer :fiscal_year, null: false
      t.text :source_url, null: false
      t.text :notes

      t.timestamps
    end
  end
end
