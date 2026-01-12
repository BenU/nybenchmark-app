# frozen_string_literal: true

class AddGovernanceFieldsToEntities < ActiveRecord::Migration[8.1]
  def change
    add_reference :entities, :parent, foreign_key: { to_table: :entities }, index: true, null: true

    add_column :entities, :government_structure, :string
    add_column :entities, :fiscal_autonomy, :string
    add_column :entities, :board_selection, :string
    add_column :entities, :executive_selection, :string
    add_column :entities, :school_legal_type, :string
    add_column :entities, :organization_note, :text

    add_index :entities, :government_structure
    add_index :entities, :fiscal_autonomy
    add_index :entities, :board_selection
    add_index :entities, :executive_selection
    add_index :entities, :school_legal_type
  end
end