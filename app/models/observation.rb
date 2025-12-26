# frozen_string_literal: true

class Observation < ApplicationRecord
  has_paper_trail
  belongs_to :entity
  belongs_to :metric
  belongs_to :document

  # Basic Type Checks
  # CHANGE THIS LINE:
  validates :value_numeric, numericality: true, allow_nil: true

  validates :fiscal_year, presence: true

  # Custom Logical Validations
  validate :fiscal_year_matches_document
  validate :validate_value_exclusivity

  private

  def fiscal_year_matches_document
    return unless document && fiscal_year

    return unless fiscal_year != document.fiscal_year

    errors.add(:fiscal_year, "must match the document's fiscal year (#{document.fiscal_year})")
  end

  def validate_value_exclusivity
    has_numeric = !value_numeric.nil?
    has_text = value_text.present?

    if has_numeric && has_text
      errors.add(:base, "Cannot have both a numeric and text value")
    elsif !has_numeric && !has_text
      errors.add(:base, "Must have either a numeric value or a text value")
    end
  end
end
