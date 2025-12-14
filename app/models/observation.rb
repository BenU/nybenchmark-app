class Observation < ApplicationRecord
  has_paper_trail
  belongs_to :entity
  belongs_to :metric
  belongs_to :document
  validates :fiscal_year, :page_reference, presence: true
  validate :value_must_be_present

  private
  def value_must_be_present
    if value_numeric.blank? && value_text.blank?
      errors.add(:base, "Either numeric value or text value must be present")
    end
  end
end