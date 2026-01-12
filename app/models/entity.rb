# frozen_string_literal: true

class Entity < ApplicationRecord
  has_paper_trail

  has_many :documents, dependent: :destroy
  has_many :observations, dependent: :destroy

  belongs_to :parent, class_name: "Entity", optional: true, inverse_of: :children
  has_many :children,
           class_name: "Entity",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :nullify

  enum :kind, {
    city: "city",
    town: "town",
    village: "village",
    county: "county",
    school_district: "school_district"
  }, suffix: true

  enum :government_structure, {
    strong_mayor: "strong_mayor",
    council_manager: "council_manager",
    commission: "commission",
    town_board: "town_board",
    mayor_administrator: "mayor_administrator"
  }, suffix: true

  enum :fiscal_autonomy, {
    independent: "independent",
    dependent: "dependent"
  }, suffix: true

  enum :board_selection, {
    elected: "elected",
    appointed: "appointed",
    mixed: "mixed"
  }, suffix: true

  enum :executive_selection, {
    elected_executive: "elected_executive",
    appointed_professional: "appointed_professional"
  }, suffix: true

  enum :school_legal_type, {
    big_five: "big_five",
    small_city: "small_city",
    central: "central",
    union_free: "union_free",
    common: "common"
  }, suffix: true

  scope :school_districts, -> { where(kind: "school_district") }

  validates :name, presence: true
  validates :name, uniqueness: {
    scope: %i[state kind],
    message: "already exists for this type of entity in this state"
  }
  validates :slug, presence: true, uniqueness: true

  validate :school_legal_type_matches_kind

  private

  def school_legal_type_matches_kind
    if school_district_kind?
      errors.add(:school_legal_type, "can't be blank") if school_legal_type.blank?
    elsif school_legal_type.present?
      errors.add(:school_legal_type, "must be blank unless kind is school_district")
    end
  end
end
