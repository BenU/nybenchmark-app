class CreateMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :metrics do |t|
      t.string :key, null: false
      t.string :label, null: false
      t.string :unit
      t.text :description

      t.timestamps
    end
    add_index :metrics, :key, unique: true
  end
end
