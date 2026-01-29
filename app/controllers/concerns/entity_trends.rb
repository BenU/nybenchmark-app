# frozen_string_literal: true

# Handles loading curated financial trends for entity dashboard
module EntityTrends # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  GENERAL_FUND_CODE = "A"

  BALANCE_SHEET_ACCOUNTS = {
    unassigned_fund_balance: { codes: %w[A917], label: "Unassigned Fund Balance" },
    cash_position: { codes: %w[A200 A201], label: "Cash Position" }
  }.freeze

  included do
    helper_method :any_trends?
  end

  private

  def load_curated_trends
    @balance_sheet_trends = load_balance_sheet_trends
    @debt_service_trends = load_debt_service_trends
    @revenue_trends = load_top_categories(account_type: :revenue, limit: 5)
    @expenditure_trends = load_top_categories(account_type: :expenditure, limit: 5, exclude: ["Debt Service"])
    @derived_trends = load_derived_trends
  end

  def load_balance_sheet_trends
    base_scope = Observation.joins(:metric).where(entity: @entity)
    trends = BALANCE_SHEET_ACCOUNTS.transform_values do |config|
      data = base_scope.where(metrics: { account_code: config[:codes] })
                       .group(:fiscal_year).sum(:value_numeric).sort.to_h
      { data: data, label: config[:label], account_type: "balance_sheet" }
    end
    trends.select { |_, info| info[:data].present? }
  end

  def load_debt_service_trends
    base_scope = Observation.joins(:metric).where(entity: @entity)
    data = base_scope.where(metrics: { level_1_category: "Debt Service" })
                     .group(:fiscal_year).sum(:value_numeric).sort.to_h
    return {} if data.blank?

    { "Debt Service" => { data: data, account_type: "expenditure" } }
  end

  def load_top_categories(account_type:, limit:, exclude: [])
    base_scope = Observation.joins(:metric).where(entity: @entity)
    type_scope = base_scope.where(metrics: { account_type: account_type })
                           .where.not(metrics: { level_1_category: [nil, ""] + exclude })
    type_scope = type_scope.where(metrics: { fund_code: GENERAL_FUND_CODE }) if account_type == :expenditure

    most_recent_year = type_scope.maximum(:fiscal_year)
    return {} if most_recent_year.nil?

    top_categories = rank_categories_by_value(type_scope, most_recent_year, limit)
    build_trend_data(base_scope, top_categories, account_type)
  end

  def rank_categories_by_value(scope, year, limit)
    scope.where(fiscal_year: year)
         .group("metrics.level_1_category")
         .sum(:value_numeric)
         .sort_by { |_, v| -v }
         .first(limit)
         .map(&:first)
  end

  def build_trend_data(base_scope, categories, account_type)
    categories.to_h do |category|
      data = base_scope.where(metrics: { level_1_category: category })
                       .group(:fiscal_year).sum(:value_numeric).sort.to_h
      [category, { data: data, account_type: account_type.to_s }]
    end
  end

  def load_derived_trends
    total_expenditures = load_total_expenditures_by_year
    return {} if total_expenditures.blank?

    derived_metric_configs.each_with_object({}) do |(key, numerator, label), result|
      trend = calculate_ratio_trend(numerator, total_expenditures, label)
      result[key] = trend if trend
    end
  end

  def derived_metric_configs
    [
      [:fund_balance_pct, @balance_sheet_trends.dig(:unassigned_fund_balance, :data), "Fund Balance %"],
      [:debt_service_pct, @debt_service_trends.dig("Debt Service", :data), "Debt Service %"]
    ]
  end

  def load_total_expenditures_by_year
    Observation.joins(:metric)
               .where(entity: @entity,
                      metrics: { account_type: :expenditure, fund_code: GENERAL_FUND_CODE })
               .group(:fiscal_year)
               .sum(:value_numeric)
  end

  def calculate_ratio_trend(numerator_data, denominator_data, label)
    return nil if numerator_data.blank? || denominator_data.blank?

    data = build_ratio_data(numerator_data, denominator_data)
    data.present? ? { data: data, label: label, account_type: "derived" } : nil
  end

  def build_ratio_data(numerator_data, denominator_data)
    (numerator_data.keys & denominator_data.keys).sort.each_with_object({}) do |year, hash|
      denom = denominator_data[year]
      hash[year] = (numerator_data[year].to_f / denom * 100).round(1) if denom&.nonzero?
    end
  end

  def load_hero_stats # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    @hero_stats = {}
    pop = latest_population
    @hero_stats[:population] = pop if pop

    if @derived_trends.dig(:fund_balance_pct, :data).present?
      @hero_stats[:fund_balance_pct] = @derived_trends[:fund_balance_pct][:data].values.last
    end
    if @derived_trends.dig(:debt_service_pct, :data).present?
      @hero_stats[:debt_service_pct] = @derived_trends[:debt_service_pct][:data].values.last
    end

    total_exp = load_total_expenditures_by_year
    return unless pop && total_exp.present?

    latest_year = total_exp.keys.max
    @hero_stats[:per_capita_spending] = (total_exp[latest_year].to_f / pop).round(0)
  end

  def latest_population
    Observation.joins(:metric)
               .where(entity: @entity, metrics: { key: "census_b01003_001e" })
               .order(fiscal_year: :desc).limit(1)
               .pick(:value_numeric)
  end

  def any_trends?
    @balance_sheet_trends.present? || @debt_service_trends.present? ||
      @revenue_trends.present? || @expenditure_trends.present? ||
      @derived_trends.present?
  end
end
