# frozen_string_literal: true

# Derives OSC filing status from observation data.
# No additional schema columns needed — everything is computed from existing observations.
module FilingStatus
  extend ActiveSupport::Concern

  CHRONIC_THRESHOLD = 3 # Years behind before classified as chronic/ceased
  SPORADIC_RATE_THRESHOLD = 80.0 # Filing rate below this = sporadic
  FILING_RATE_WINDOW = 10 # Years to consider for filing rate

  # Most recent fiscal year with OSC-sourced observation data for this entity.
  def last_osc_filing_year
    observations.joins(:metric)
                .where(metrics: { data_source: :osc })
                .maximum(:fiscal_year)
  end

  # Years within the given range that have NO OSC observations.
  def osc_missing_years(range)
    filed = observations.joins(:metric)
                        .where(metrics: { data_source: :osc })
                        .where(fiscal_year: range)
                        .distinct.pluck(:fiscal_year)
    range.to_a - filed
  end

  # Percentage of years filed within the given range (0.0-100.0).
  def osc_filing_rate(range)
    total = range.size
    return 0.0 if total.zero?

    missing = osc_missing_years(range).size
    ((total - missing).to_f / total * 100).round(1)
  end

  # Categorize a city's filing status relative to a target year.
  # Returns :chronic, :recent_lapse, :sporadic, or nil (current filer).
  def filing_category(as_of_year)
    last_year = last_osc_filing_year
    return nil if last_year == as_of_year

    gap = last_year.nil? ? as_of_year : (as_of_year - last_year)
    return :chronic if gap >= CHRONIC_THRESHOLD

    rate_range = (as_of_year - FILING_RATE_WINDOW + 1)..as_of_year
    osc_filing_rate(rate_range) < SPORADIC_RATE_THRESHOLD ? :sporadic : :recent_lapse
  end

  class_methods do
    # Most recent fiscal year where >= 50% of cities have OSC data.
    def latest_majority_year
      city_ids = where(kind: :city).pluck(:id)
      return nil if city_ids.empty?

      min_cities = city_ids.size / 2

      year_counts = Observation.joins(:metric)
                               .where(entity_id: city_ids, metrics: { data_source: :osc })
                               .group(:fiscal_year)
                               .select("fiscal_year, COUNT(DISTINCT entity_id) AS city_count")

      year_counts.select { |r| r.city_count >= min_cities }
                 .max_by(&:fiscal_year)
                 &.fiscal_year
    end

    # Returns non-filing cities grouped by category.
    # { chronic: [entities], recent_lapse: [entities], sporadic: [entities] }
    def filing_report(as_of_year)
      report = { chronic: [], recent_lapse: [], sporadic: [] }

      where(kind: :city).find_each do |city|
        category = city.filing_category(as_of_year)
        report[category] << city if category
      end

      report.each_value { |list| list.sort_by!(&:name) }
    end
  end
end
