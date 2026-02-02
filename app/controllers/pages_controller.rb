# frozen_string_literal: true

class PagesController < ApplicationController
  def methodology; end

  def non_filers
    @as_of_year = Entity.latest_majority_year || Time.current.year
    @filing_report = Entity.filing_report(@as_of_year)
    @total_cities = Entity.where(kind: :city).where.not(slug: "nyc").count
    @non_filer_count = @filing_report.values.flatten.size
    @filer_count = @total_cities - @non_filer_count
  end
end
