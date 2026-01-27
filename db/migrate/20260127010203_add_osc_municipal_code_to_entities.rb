class AddOscMunicipalCodeToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :osc_municipal_code, :string
    add_index :entities, :osc_municipal_code
  end
end
