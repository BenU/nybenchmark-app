class AddUniqueIndexToEntitiesName < ActiveRecord::Migration[8.1]
  def change
    add_index :entities, [:name, :state, :kind], unique: true
  end
end
