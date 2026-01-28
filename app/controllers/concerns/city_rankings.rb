# frozen_string_literal: true

# Computes cross-city rankings for the landing page.
# Three rankings: Fund Balance %, Debt Service %, Per-Capita Spending.
module CityRankings
  extend ActiveSupport::Concern

  private

  def load_city_rankings # rubocop:disable Metrics/MethodLength
    city_ids = Entity.where(kind: :city).pluck(:id)
    @rankings_year = most_recent_expenditure_year(city_ids)
    return if @rankings_year.nil?

    expenditures = total_expenditures_by_entity(city_ids, @rankings_year)
    return if expenditures.blank?

    @fund_balance_ranking = build_ranking(
      fund_balances_by_entity(city_ids, @rankings_year),
      expenditures, :percentage
    )
    @debt_service_ranking = build_ranking(
      debt_service_by_entity(city_ids, @rankings_year),
      expenditures, :percentage
    )
    @per_capita_ranking = build_ranking(
      expenditures,
      population_by_entity(city_ids, @rankings_year),
      :currency
    )
  end

  # Pick the most recent fiscal year where at least half of all cities have
  # expenditure data. This avoids selecting a year where only a handful of
  # early filers have reported.
  def most_recent_expenditure_year(city_ids)
    min_cities = city_ids.size / 2

    year_counts = Observation.joins(:metric)
                             .where(entity_id: city_ids, metrics: { account_type: :expenditure })
                             .group(:fiscal_year)
                             .select("fiscal_year, COUNT(DISTINCT entity_id) AS city_count")

    year_counts.select { |r| r.city_count >= min_cities }
               .max_by(&:fiscal_year)
               &.fiscal_year
  end

  def total_expenditures_by_entity(city_ids, year)
    Observation.joins(:metric)
               .where(entity_id: city_ids, fiscal_year: year, metrics: { account_type: :expenditure })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  def fund_balances_by_entity(city_ids, year)
    Observation.joins(:metric)
               .where(entity_id: city_ids, fiscal_year: year, metrics: { account_code: "A917" })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  def debt_service_by_entity(city_ids, year)
    Observation.joins(:metric)
               .where(entity_id: city_ids, fiscal_year: year, metrics: { level_1_category: "Debt Service" })
               .group(:entity_id)
               .sum(:value_numeric)
  end

  def population_by_entity(city_ids, year)
    Observation.joins(:metric)
               .where(entity_id: city_ids, metrics: { key: "census_b01003_001e" })
               .where(fiscal_year: ..year)
               .select("DISTINCT ON (entity_id) entity_id, value_numeric, fiscal_year")
               .order(:entity_id, fiscal_year: :desc)
               .each_with_object({}) { |obs, hash| hash[obs.entity_id] = obs.value_numeric }
  end

  def build_ranking(numerators, denominators, format) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    entities_by_id = Entity.where(id: numerators.keys | denominators.keys).index_by(&:id)

    common_ids = numerators.keys & denominators.keys
    ranked = common_ids.filter_map do |eid|
      denom = denominators[eid]
      next if denom.nil? || denom.zero?

      value = if format == :percentage
                (numerators[eid].to_f / denom * 100).round(1)
              else
                (numerators[eid].to_f / denom).round(0)
              end
      { entity: entities_by_id[eid], value: value }
    end

    ranked.sort_by { |r| -r[:value] }
  end
end
