# frozen_string_literal: true

class Observation < ApplicationRecord
  has_paper_trail
  belongs_to :entity
  belongs_to :metric
  belongs_to :document

  # Allow editing document source_url from observation form
  accepts_nested_attributes_for :document, update_only: true

  # -- Enums --
  enum :verification_status, { provisional: 0, verified: 1, flagged: 2 }, default: :provisional, validate: true

  # -- Callbacks --
  before_validation :sync_fiscal_year_from_document

  # Basic Type Checks
  validates :value_numeric, numericality: true, allow_nil: true
  validates :fiscal_year, presence: true
  validates :pdf_page, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Custom Logical Validations
  validate :fiscal_year_matches_document
  validate :validate_value_exclusivity
  validate :value_type_matches_metric

  # -- Scopes --
  scope :search, lambda { |term|
    return if term.blank?

    pattern = "%#{sanitize_sql_like(term.strip)}%"
    left_joins(:entity, :metric, :document).where(
      "entities.name ILIKE :q OR metrics.key ILIKE :q OR metrics.label ILIKE :q OR documents.title ILIKE :q",
      q: pattern
    )
  }

  scope :sorted_by, lambda { |column, direction = nil|
    # Support both new format (column, direction) and legacy format (selection string)
    if direction.nil?
      # Legacy format - single selection string
      case column
      when "fiscal_year_desc" then order(fiscal_year: :desc, updated_at: :desc)
      when "entity_name_asc"  then left_joins(:entity).order("entities.name ASC", updated_at: :desc)
      else order(updated_at: :desc)
      end
    else
      # New format - column + direction
      direction = "desc" unless %w[asc desc].include?(direction)

      case column
      when "entity_name"
        left_joins(:entity).order("entities.name #{direction.upcase}", updated_at: :desc)
      when "metric_label"
        left_joins(:metric).order("metrics.label #{direction.upcase}", updated_at: :desc)
      when "fiscal_year"
        order(fiscal_year: direction, updated_at: :desc)
      when "updated_at"
        order(updated_at: direction)
      else
        order(updated_at: :desc)
      end
    end
  }

  # -- Queue Logic --
  def next_provisional_observation
    # 1. Try to find the next provisional item by ID (stable ordering)
    # 2. If none found (end of list), wrap around to the first provisional item that isn't this one
    Observation.provisional.where("id > ?", id).order(:id).first ||
      Observation.provisional.where.not(id: id).order(:id).first
  end

  private

  def fiscal_year_matches_document
    return unless document && fiscal_year

    return unless fiscal_year != document.fiscal_year

    errors.add(:fiscal_year, "must match the document's fiscal year (#{document.fiscal_year})")
  end

  def sync_fiscal_year_from_document
    self.fiscal_year = document.fiscal_year if document.present?
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

  def value_type_matches_metric
    return unless metric

    if metric.expects_numeric? && value_numeric.nil?
      errors.add(:value_numeric, "is required for this metric")
    elsif metric.expects_text? && value_text.blank?
      errors.add(:value_text, "is required for this metric")
    end
  end
end
