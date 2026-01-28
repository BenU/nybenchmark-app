# frozen_string_literal: true

# Handles loading curated financial trends for entity dashboard
module EntityTrends
  extend ActiveSupport::Concern

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

  def any_trends?
    @balance_sheet_trends.present? || @debt_service_trends.present? ||
      @revenue_trends.present? || @expenditure_trends.present?
  end
end
