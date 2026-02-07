# frozen_string_literal: true

class CountyComparisonsController < ApplicationController
  include CountyPartisanScatterData

  def show
    @years = available_county_years
    @year = params[:year]&.to_i
    @year = best_county_year unless @years.include?(@year)

    load_scatter_datasets
  end

  private

  def load_scatter_datasets
    if @year
      @fund_balance_data = load_fund_balance_scatter(@year)
      @debt_service_data = load_debt_service_scatter(@year)
      @operating_ratio_data = load_operating_ratio_scatter(@year)
    else
      @fund_balance_data = []
      @debt_service_data = []
      @operating_ratio_data = []
    end
  end
end
