class CreateEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :entities do |t|
      t.string :name
      t.string :kind, null: false, default: "city"
      t.string :state, null: false, default: "NY"
      t.string :slug, null: false

      t.timestamps
    end
    add_index :entities, :slug, unique: true
  end
end
