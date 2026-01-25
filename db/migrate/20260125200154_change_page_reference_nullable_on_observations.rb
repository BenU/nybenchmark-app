class ChangePageReferenceNullableOnObservations < ActiveRecord::Migration[8.1]
  def change
    change_column_null :observations, :page_reference, true
  end
end
