# frozen_string_literal: true

# Loads county partisan composition and financial data for scatter charts.
# Produces scatter datasets: Fund Balance %, Debt Service %, and Operating Ratio
# vs. Conservative % of county council.
module CountyPartisanScatterData # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  CUSTODIAL_FUND_CODE = "T"
  INTERFUND_TRANSFER_CATEGORY = "Other Uses"
  INTERFUND_REVENUE_CATEGORY = "Other Sources"

  # GASB 54 (effective FY 2011) replaced A910/A911 with A917
  GASB54_CUTOVER_YEAR = 2011
  PRE_GASB54_FUND_BALANCE_CODES = %w[A910 A911].freeze

  PARTISAN_CSV = Rails.root.join("db/seeds/county_data/council_partisan_composition_2025.csv")

  # Single neutral color for all data points — the background zones convey partisanship
  # Tailwind slate-500: visible against both light (#fff) and dark (#13171f) backgrounds
  DOT_COLOR = "#64748b"

  private

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def load_partisan_data
    @load_partisan_data ||= begin
      require "csv"
      data = {}
      CSV.foreach(PARTISAN_CSV, headers: true) do |row|
        name = row["Name"]
        dems = row["# Democrats"].to_i + row["# Liberal not Dems"].to_i
        reps = row["# Republicans"].to_i + row["# Conservative not Reps"].to_i
        total = dems + reps + row["Unknown"].to_i

        next if total.zero?

        conservative_pct = (reps.to_f / total * 100).round(1)
        majority = reps > dems ? "R-Majority" : "D-Majority"
        data[name] = { conservative_pct: conservative_pct, majority: majority }
      end
      data
    end
  end

  def available_county_years
    county_ids = Entity.where(kind: :county).pluck(:id)
    return [] if county_ids.empty?

    min_counties = (county_ids.size * 0.7).ceil

    year_counts = Observation.joins(:metric)
                             .where(entity_id: county_ids, metrics: { account_type: :expenditure })
                             .where.not(metrics: { fund_code: CUSTODIAL_FUND_CODE })
                             .where.not(metrics: { level_1_category: INTERFUND_TRANSFER_CATEGORY })
                             .group(:fiscal_year)
                             .select("fiscal_year, COUNT(DISTINCT entity_id) AS county_count")

    year_counts.select { |r| r.county_count >= min_counties }
               .map(&:fiscal_year)
               .sort
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Pick the most recent year with sufficient coverage.
  def best_county_year
    available_county_years.last
  end

  def load_fund_balance_scatter(year)
    county_ids = Entity.where(kind: :county).pluck(:id)
    return [] if county_ids.empty?

    expenditures = total_county_expenditures(county_ids, year)
    fund_balances = county_fund_balances(county_ids, year)

    build_partisan_scatter(county_ids, expenditures, fund_balances)
  end

  def load_debt_service_scatter(year)
    county_ids = Entity.where(kind: :county).pluck(:id)
    return [] if county_ids.empty?

    expenditures = total_county_expenditures(county_ids, year)
    debt_service = county_debt_service(county_ids, year)

    build_partisan_scatter(county_ids, expenditures, debt_service)
  end

  def load_operating_ratio_scatter(year)
    county_ids = Entity.where(kind: :county).pluck(:id)
    return [] if county_ids.empty?

    expenditures = total_county_expenditures(county_ids, year)
    revenues = total_county_revenues(county_ids, year)

    build_partisan_scatter(county_ids, expenditures, revenues, ratio_mode: true)
  end

  def total_county_expenditures(county_ids, year)
    Observation.joins(:metric)
               .where(entity_id: county_ids, fiscal_year: year, metrics: { account_type: :expenditure })
               .where.not(metrics: { fund_code: CUSTODIAL_FUND_CODE })
               .where.not(metrics: { level_1_category: INTERFUND_TRANSFER_CATEGORY })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  def total_county_revenues(county_ids, year)
    Observation.joins(:metric)
               .where(entity_id: county_ids, fiscal_year: year, metrics: { account_type: :revenue })
               .where.not(metrics: { fund_code: CUSTODIAL_FUND_CODE })
               .where.not(metrics: { level_1_category: INTERFUND_REVENUE_CATEGORY })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  # Uses A917 (GASB 54, FY 2011+) or A910+A911 (pre-GASB 54) for fund balance
  def county_fund_balances(county_ids, year)
    codes = year >= GASB54_CUTOVER_YEAR ? ["A917"] : PRE_GASB54_FUND_BALANCE_CODES

    Observation.joins(:metric)
               .where(entity_id: county_ids, fiscal_year: year, metrics: { account_code: codes })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  def county_debt_service(county_ids, year)
    Observation.joins(:metric)
               .where(entity_id: county_ids, fiscal_year: year,
                      metrics: { level_1_category: "Debt Service" })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def build_partisan_scatter(county_ids, expenditures, numerators, ratio_mode: false) # rubocop:disable Lint/UnusedMethodArgument
    partisan = load_partisan_data
    entities = Entity.where(id: county_ids).index_by(&:id)

    points = []

    (expenditures.keys & numerators.keys).each do |eid|
      entity = entities[eid]
      next unless entity

      denom = expenditures[eid]
      next if denom.nil? || denom.zero?

      # Match entity name "Albany County" -> partisan key "Albany"
      short_name = entity.name.delete_suffix(" County")
      partisan_info = partisan[short_name]
      next unless partisan_info

      # Operating ratio: revenue/expenditure * 100 (>100 = surplus)
      # Other metrics: numerator/expenditure * 100 (percentage of expenditures)
      pct = (numerators[eid].to_f / denom * 100).round(1)

      points << {
        x: partisan_info[:conservative_pct],
        y: pct,
        name: entity.name
      }
    end

    return [] if points.empty?

    [{ name: "Counties", data: points, backgroundColor: DOT_COLOR }]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
