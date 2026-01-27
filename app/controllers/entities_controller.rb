# frozen_string_literal: true

class EntitiesController < ApplicationController
  include Pagy::Method

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_entity, only: %i[show edit update]

  def index
    @pagy, @entities = pagy(:offset, entities_scope, limit: 25)
  end

  def show
    # Pre-fetch related data for the Hub sections
    @documents = @entity.documents.order(fiscal_year: :desc)
    @observations = @entity.observations.includes(:metric).order(fiscal_year: :desc).limit(10)

    # Load trend data for financial charts
    @category_trends = load_category_trends
    @fiscal_year_range = @entity.observations.pluck(:fiscal_year).minmax if @category_trends.present?
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

  def entities_scope
    Entity
      .includes(:parent)
      .select("entities.*",
              "(SELECT COUNT(*) FROM documents WHERE documents.entity_id = entities.id) AS documents_count",
              "(SELECT COUNT(*) FROM observations WHERE observations.entity_id = entities.id) AS observations_count")
      .where(filter_params)
      .sorted_by(params[:sort], params[:direction])
  end

  def load_category_trends
    base_scope = Observation.joins(:metric).where(entity: @entity)
    # Get categories with their account_type (revenue/expenditure/balance_sheet)
    categories = base_scope.where.not(metrics: { level_1_category: nil })
                           .distinct.pluck("metrics.level_1_category", "metrics.account_type")
    categories.to_h do |category, account_type|
      data = base_scope.where(metrics: { level_1_category: category })
                       .group(:fiscal_year).sum(:value_numeric).sort.to_h
      [category, { data: data, account_type: account_type }]
    end
  end
end
