# frozen_string_literal: true

module TrendChartHelper
  # Extends a year-keyed data hash to cover the full range from the first data
  # year through target_year, filling gaps with nil so Chart.js shows breaks.
  # Returns string keys (sorted) so Chart.js uses a category scale, not linear.
  def extend_chart_data_to_year(data, target_year)
    return data if data.blank?

    extended = data.dup
    if target_year
      first_year = extended.keys.min
      last_year = [extended.keys.max, target_year].max
      (first_year..last_year).each { |y| extended[y] ||= nil }
    end

    # Convert integer keys to strings so Chart.js treats them as categories
    extended.sort.to_h.transform_keys(&:to_s)
  end

  # Returns [first_year, last_year] from a string-keyed chart data hash.
  def chart_year_range(data)
    return [nil, nil] if data.blank?

    [data.keys.first, data.keys.last]
  end
end
