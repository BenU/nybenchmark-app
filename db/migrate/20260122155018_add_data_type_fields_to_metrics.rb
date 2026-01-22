class AddDataTypeFieldsToMetrics < ActiveRecord::Migration[8.1]
  def change
    # value_type: 0 = numeric (default), 1 = text
    add_column :metrics, :value_type, :integer, default: 0, null: false
    # display_format: currency, currency_rounded, percentage, integer, decimal, fte, rate
    add_column :metrics, :display_format, :string
    # formula: optional, for derived metrics (e.g., "police_fte + fire_fte")
    add_column :metrics, :formula, :string
  end
end
