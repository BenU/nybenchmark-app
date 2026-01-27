class AddAccountTypeToMetrics < ActiveRecord::Migration[8.1]
  def change
    # Values: 0=revenue, 1=expenditure, 2=balance_sheet
    add_column :metrics, :account_type, :integer
    add_index :metrics, :account_type
  end
end
