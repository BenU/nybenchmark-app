# frozen_string_literal: true

namespace :data do
  desc "Backfill value_type and display_format for existing metrics"
  task backfill_metric_types: :environment do
    puts "Starting metric type backfill..."
    puts "Total metrics: #{Metric.count}"

    updated = 0
    errors = []

    Metric.find_each do |metric|
      # Determine value_type based on unit or key patterns
      value_type = determine_value_type(metric)

      # Determine display_format based on unit (only for numeric metrics)
      display_format = value_type == :numeric ? determine_display_format(metric) : nil

      # Skip if already correctly configured
      if metric.value_type == value_type.to_s && metric.display_format == display_format
        puts "  SKIP: #{metric.key} (already configured)"
        next
      end

      # Update the metric
      metric.value_type = value_type
      metric.display_format = display_format

      if metric.save
        puts "  OK: #{metric.key} -> type=#{value_type}, format=#{display_format || 'nil'}"
        updated += 1
      else
        errors << { key: metric.key, errors: metric.errors.full_messages }
        puts "  ERROR: #{metric.key} - #{metric.errors.full_messages.join(', ')}"
      end
    end

    puts "\nBackfill complete!"
    puts "  Updated: #{updated}"
    puts "  Errors: #{errors.count}"

    if errors.any?
      puts "\nErrors:"
      errors.each { |e| puts "  - #{e[:key]}: #{e[:errors].join(', ')}" }
    end

    # Validate all metrics are now valid
    invalid_metrics = Metric.all.reject(&:valid?)
    if invalid_metrics.any?
      puts "\nWARNING: #{invalid_metrics.count} metrics are still invalid:"
      invalid_metrics.each do |m|
        puts "  - #{m.key}: #{m.errors.full_messages.join(', ')}"
      end
    else
      puts "\nAll metrics are now valid!"
    end
  end

  desc "Fix observations where text values should be numeric (converts currency strings like '$81,455' to numbers)"
  task fix_observation_values: :environment do
    puts "Checking observations for mismatched value types..."

    fixed = 0
    errors = []

    Observation.includes(:metric).find_each do |obs|
      next if obs.valid?

      metric = obs.metric

      # If metric expects numeric but observation has text value that looks like a number
      if metric.expects_numeric? && obs.value_numeric.nil? && obs.value_text.present?
        # Try to parse the text value as a number
        parsed = parse_numeric_text(obs.value_text)

        if parsed
          obs.value_numeric = parsed
          obs.value_text = nil

          if obs.save
            puts "  FIXED: Observation #{obs.id} (#{metric.key}): '#{obs.value_text}' -> #{parsed}"
            fixed += 1
          else
            errors << { id: obs.id, errors: obs.errors.full_messages }
            puts "  ERROR: Observation #{obs.id} - #{obs.errors.full_messages.join(', ')}"
          end
        else
          puts "  SKIP: Observation #{obs.id} - Could not parse '#{obs.value_text}' as number"
        end
      end
    end

    puts "\nFix complete!"
    puts "  Fixed: #{fixed}"
    puts "  Errors: #{errors.count}"

    # Final validation check
    invalid_obs = Observation.all.reject(&:valid?)
    if invalid_obs.any?
      puts "\nWARNING: #{invalid_obs.count} observations are still invalid:"
      invalid_obs.each do |o|
        puts "  - ID #{o.id} (#{o.metric.key}): #{o.errors.full_messages.join(', ')}"
      end
    else
      puts "\nAll observations are now valid!"
    end
  end

  desc "Run all data backfill tasks"
  task backfill_all: %i[backfill_metric_types fix_observation_values] do
    puts "\n#{'=' * 50}"
    puts "All backfill tasks completed!"
    puts "=" * 50
  end

  private

  def determine_value_type(metric)
    # Text-based metrics (identified by unit or key patterns)
    text_patterns = [
      /bond.*rating/i,
      /credit.*rating/i,
      /gov.*organization/i
    ]

    text_units = ["Text"]

    if text_units.include?(metric.unit) || text_patterns.any? { |p| metric.key.match?(p) }
      :text
    else
      :numeric
    end
  end

  def determine_display_format(metric)
    unit = metric.unit.to_s.downcase.strip

    case unit
    when "usd", "dollars", "$"
      "currency"
    when "percent", "percentage", "%"
      "percentage"
    when "fte", "ftes"
      "fte"
    when "rate"
      "rate"
    when "count", "people", "employees"
      "integer"
    else
      # Infer from key patterns
      key = metric.key.to_s.downcase

      if key.include?("_fte") || key.end_with?("_fte")
        "fte"
      elsif key.include?("rate") && key.exclude?("rating")
        "rate"
      elsif key.include?("population") || key.include?("count") || key.include?("employees")
        "integer"
      elsif key.include?("revenue") || key.include?("expense") || key.include?("tax") ||
            key.include?("debt") || key.include?("liability") || key.include?("fund") ||
            key.include?("position") || key.include?("value") || key.include?("income") ||
            key.include?("payment") || key.include?("aid") || key.include?("levy") ||
            key.include?("rent")
        "currency"
      elsif key.include?("percentage") || (key.include?("_rate") && key.exclude?("crime_rate"))
        "percentage"
      else
        # Default to decimal for unknown numeric metrics
        "decimal"
      end
    end
  end
end

# Make private methods available as module functions for the task
def determine_value_type(metric)
  text_patterns = [
    /bond.*rating/i,
    /credit.*rating/i,
    /gov.*organization/i
  ]

  text_units = ["Text"]

  if text_units.include?(metric.unit) || text_patterns.any? { |p| metric.key.match?(p) }
    :text
  else
    :numeric
  end
end

def determine_display_format(metric)
  unit = metric.unit.to_s.downcase.strip

  case unit
  when "usd", "dollars", "$"
    "currency"
  when "percent", "percentage", "%"
    "percentage"
  when "fte", "ftes"
    "fte"
  when "rate"
    "rate"
  when "count", "people", "employees"
    "integer"
  else
    key = metric.key.to_s.downcase

    if key.include?("_fte") || key.end_with?("_fte")
      "fte"
    elsif key.include?("rate") && key.exclude?("rating")
      "rate"
    elsif key.include?("population") || key.include?("count") || key.include?("employees")
      "integer"
    elsif key.include?("revenue") || key.include?("expense") || key.include?("tax") ||
          key.include?("debt") || key.include?("liability") || key.include?("fund") ||
          key.include?("position") || key.include?("value") || key.include?("income") ||
          key.include?("payment") || key.include?("aid") || key.include?("levy") ||
          key.include?("rent")
      "currency"
    elsif key.include?("percentage") || (key.include?("_rate") && key.exclude?("crime_rate"))
      "percentage"
    else
      "decimal"
    end
  end
end

def parse_numeric_text(text)
  return nil if text.blank?

  # Remove currency symbols, commas, and whitespace
  cleaned = text.to_s.gsub(/[$,\s]/, "")

  # Handle percentages (remove % and keep the number)
  cleaned = cleaned.delete("%")

  # Try to parse as a number
  Float(cleaned)
rescue ArgumentError, TypeError
  nil
end
