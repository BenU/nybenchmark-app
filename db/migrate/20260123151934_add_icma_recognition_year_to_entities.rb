class AddIcmaRecognitionYearToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :icma_recognition_year, :integer
  end
end
