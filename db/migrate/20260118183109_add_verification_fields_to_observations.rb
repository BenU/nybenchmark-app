class AddVerificationFieldsToObservations < ActiveRecord::Migration[8.1]
  def change
    add_column :observations, :verification_status, :integer, default: 0, null: false
    add_column :observations, :pdf_page, :integer

    add_index :observations, :verification_status
  end
end