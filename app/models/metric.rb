# frozen_string_literal: true

class Metric < ApplicationRecord
  has_paper_trail
  has_many :observations, dependent: :restrict_with_error

  # -- Enums --
  enum :value_type, { numeric: 0, text: 1 }, default: :numeric, validate: true

  enum :data_source, {
    manual: 0,          # Manually entered
    osc: 1,             # NYS Comptroller AFR data (non-NYC, and NYC pre-2011)
    census: 2,          # US Census Bureau (population, income, poverty)
    dcjs: 3,            # NYS Division of Criminal Justice Services (crime stats)
    rating_agency: 4,   # Bond ratings (Moody's, S&P, Fitch)
    derived: 5,         # Calculated from other metrics (per capita, ratios)
    nyc_checkbook: 6    # NYC Checkbook data (NYC 2011+)
  }, default: :manual, validate: true, suffix: :data_source

  # -- Constants --
  VALID_DISPLAY_FORMATS = %w[currency currency_rounded percentage integer decimal fte rate].freeze

  # -- Validations --
  validates :key, :label, presence: true
  validates :key, uniqueness: true
  validate :validate_display_format

  # -- Scopes --
  scope :sorted_by, lambda { |column, direction|
    direction = "asc" unless %w[asc desc].include?(direction)

    case column
    when "label"
      order(label: direction)
    when "value_type"
      order(value_type: direction, label: :asc)
    when "key"
      order(key: direction)
    else
      order(label: :asc)
    end
  }

  # -- Helper Methods --
  def derived?
    formula.present?
  end

  def expects_numeric?
    numeric?
  end

  def expects_text?
    text?
  end

  def format_value(raw_value)
    return nil if raw_value.nil?
    return raw_value if text?

    format_numeric_value(raw_value)
  end

  private

  def validate_display_format
    return unless numeric?

    if display_format.blank?
      errors.add(:display_format, "is required for numeric metrics")
    elsif VALID_DISPLAY_FORMATS.exclude?(display_format)
      errors.add(:display_format, "is not a valid display format")
    end
  end

  def format_numeric_value(raw_value)
    case display_format
    when "currency" then format_currency(raw_value, decimals: 2)
    when "currency_rounded" then format_currency(raw_value, decimals: 0)
    when "percentage" then "#{format_decimal(raw_value, 1)}%"
    when "integer" then number_with_delimiter(raw_value.round)
    when "decimal" then format_decimal(raw_value, 2)
    when "fte", "rate" then format_decimal(raw_value, 1)
    else raw_value.to_s
    end
  end

  def format_currency(value, decimals:)
    formatted = number_with_delimiter(value.abs.round(decimals))
    formatted = add_decimal_places(formatted, decimals) if decimals.positive?
    value.negative? ? "-$#{formatted}" : "$#{formatted}"
  end

  def format_decimal(value, decimals)
    rounded = value.round(decimals)
    if decimals.positive? && rounded >= 1000
      # Add commas for thousands
      int_part, dec_part = rounded.to_s.split(".")
      dec_part ||= "0" * decimals
      dec_part = dec_part.ljust(decimals, "0")
      "#{number_with_delimiter(int_part.to_i)}.#{dec_part}"
    else
      format("%.#{decimals}f", rounded)
    end
  end

  def number_with_delimiter(number)
    number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
  end

  def add_decimal_places(formatted, decimals)
    if formatted.include?(".")
      int_part, dec_part = formatted.split(".")
      "#{int_part}.#{dec_part.ljust(decimals, '0')}"
    else
      "#{formatted}.#{'0' * decimals}"
    end
  end
end
