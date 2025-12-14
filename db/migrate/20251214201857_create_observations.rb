class CreateObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :observations do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :metric, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :fiscal_year, null: false
      t.decimal :value_numeric, precision: 20, scale: 2
      t.text :value_text
      t.string :page_reference, null: false
      t.text :notes

      t.timestamps
    end
  end
end
