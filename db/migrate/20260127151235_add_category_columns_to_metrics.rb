class AddCategoryColumnsToMetrics < ActiveRecord::Migration[8.1]
  def change
    add_column :metrics, :level_1_category, :string
    add_column :metrics, :level_2_category, :string

    add_index :metrics, :level_1_category
    add_index :metrics, :level_2_category
  end
end
