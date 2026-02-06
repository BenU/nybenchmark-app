# frozen_string_literal: true

module SchoolDistrictComparisonsHelper
  # Format a numeric value based on metric format type
  def format_scatter_value(value, format)
    return "—" if value.nil?

    case format
    when :currency then number_to_currency(value, precision: 0)
    when :percentage then "#{number_with_precision(value, precision: 1)}%"
    when :integer then number_with_delimiter(value.round)
    else value.to_s
    end
  end

  # Returns axis label with format hint
  def axis_label_with_format(metric_key, metrics)
    metrics[metric_key]&.dig(:label) || metric_key
  end
end
