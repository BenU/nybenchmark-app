# frozen_string_literal: true

class EntitiesController < ApplicationController
  before_action :authenticate_user!, except: %i[index show]
  before_action :set_entity, only: %i[show edit update]

  def index
    @entities = Entity
                .left_joins(:documents, :observations)
                .select(
                  "entities.*",
                  "COUNT(DISTINCT documents.id) AS documents_count",
                  "COUNT(DISTINCT observations.id) AS observations_count"
                )
                .group("entities.id")
                .order(:name)
  end

  def show
    # Pre-fetch related data for the Hub sections
    @documents = @entity.documents.order(fiscal_year: :desc)
    @observations = @entity.observations.includes(:metric).order(fiscal_year: :desc).limit(10)
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
end
