class AddOscFieldsToMetrics < ActiveRecord::Migration[8.1]
  def change
    add_column :metrics, :data_source, :integer, default: 0, null: false
    add_column :metrics, :account_code, :string
    add_column :metrics, :fund_code, :string
    add_column :metrics, :function_code, :string
    add_column :metrics, :object_code, :string

    add_index :metrics, :data_source
    add_index :metrics, :account_code
    add_index :metrics, :fund_code
  end
end
