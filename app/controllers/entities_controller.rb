# frozen_string_literal: true

class EntitiesController < ApplicationController
  include Pagy::Method
  include EntityTrends

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_entity, only: %i[show edit update]

  def index
    load_non_filer_ids
    @pagy, @entities = pagy(:offset, entities_scope, limit: 25)
  end

  def show
    # Pre-fetch related data for the Hub sections
    @documents = @entity.documents.order(fiscal_year: :desc)
    @observations = @entity.observations.includes(:metric).order(fiscal_year: :desc).limit(10)

    # Load curated trend data for financial dashboard
    load_curated_trends
    load_hero_stats
    @fiscal_year_range = @entity.observations.pluck(:fiscal_year).minmax if any_trends?

    # Filing status for non-filer banner and chart annotations
    load_filing_status
  end

  def new
    @entity = Entity.new
  end

  def edit; end

  def create
    @entity = Entity.new(entity_params)

    if @entity.save
      redirect_to @entity, notice: "Entity was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @entity.update(entity_params)
      redirect_to @entity, notice: "Entity was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_entity
    # Because we used `param: :slug` in routes, we look up by slug, not id
    @entity = Entity.find_by!(slug: params[:slug])
  end

  def entity_params
    params.expect(
      entity: %i[name kind slug state parent_id
                 government_structure fiscal_autonomy icma_recognition_year
                 school_legal_type board_selection executive_selection
                 organization_note]
    )
  end

  def filter_params
    params.permit(:kind, :government_structure).compact_blank
  end

  def load_non_filer_ids
    as_of_year = Entity.latest_majority_year
    return @non_filer_ids = Set.new unless as_of_year

    report = Entity.filing_report(as_of_year)
    @non_filer_ids = report.values.flatten.to_set(&:id)
  end

  def load_filing_status
    @latest_majority_year = Entity.latest_majority_year
    return unless @latest_majority_year

    @last_osc_year = @entity.last_osc_filing_year
    @filing_category = @entity.filing_category(@latest_majority_year)
    @missing_osc_years = load_missing_osc_years
  end

  def load_missing_osc_years
    return [] unless @fiscal_year_range

    @entity.osc_missing_years(@fiscal_year_range.first..@fiscal_year_range.last)
  end

  def entities_scope
    scope = base_entity_scope.where(filter_params)
    scope = apply_filing_status_filter(scope)
    scope.sorted_by(params[:sort], params[:direction])
  end

  def base_entity_scope
    doc_count = "(SELECT COUNT(*) FROM documents WHERE documents.entity_id = entities.id) AS documents_count"
    obs_count = "(SELECT COUNT(*) FROM observations WHERE observations.entity_id = entities.id) AS observations_count"
    Entity.includes(:parent).select("entities.*", doc_count, obs_count)
  end

  def apply_filing_status_filter(scope)
    return scope if @non_filer_ids.blank?

    case params[:filing_status]
    when "late" then scope.where(id: @non_filer_ids.to_a)
    when "current" then scope.where.not(id: @non_filer_ids.to_a)
    else scope
    end
  end
end
