# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :set_noindex, only: :version

  def methodology; end

  def version
    revision_path = Rails.root.join("REVISION")
    sha = if revision_path.exist?
            revision_path.read.strip
          else
            `git rev-parse HEAD`.strip
          end

    render json: { sha: sha }
  end

  def non_filers
    @as_of_year = Entity.latest_majority_year || Time.current.year
    @filing_report = Entity.filing_report(@as_of_year)
    @total_cities = Entity.where(kind: :city).where.not(slug: "nyc").count
    @non_filer_count = @filing_report.values.flatten.size
    @filer_count = @total_cities - @non_filer_count
  end
end
