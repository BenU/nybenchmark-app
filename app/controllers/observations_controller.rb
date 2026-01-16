# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Pagy::Method

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_observation, only: %i[show edit update destroy]
  before_action :set_collections, only: %i[new create edit update]

  def index
    scope = Observation.includes(:entity, :metric, :document)
                       .where(filter_params)
                       .search(params[:q])
                       .sorted_by(params[:sort])

    @pagy, @observations = pagy(:offset, scope, limit: 20)
    load_filter_options
  end

  def show; end

  def new
    @observation = Observation.new
    @observation.entity_id = params[:entity_id] if params[:entity_id].present?
    filter_documents
  end

  def edit
    @observation.entity_id = params[:entity_id] if params[:entity_id].present?
    filter_documents
  end

  def create
    @observation = Observation.new(observation_params)
    assign_fiscal_year

    if @observation.save
      redirect_to @observation, notice: "Observation was successfully created."
    else
      filter_documents
      render :new, status: :unprocessable_content
    end
  end

  def update
    @observation.assign_attributes(observation_params)
    assign_fiscal_year

    if @observation.save
      redirect_to @observation, notice: "Observation was successfully updated."
    else
      filter_documents
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @observation.destroy
    redirect_to observations_url, notice: "Observation was successfully destroyed."
  end

  private

  def set_observation
    @observation = Observation.includes(:entity, :metric, :document).find(params[:id])
  end

  def set_collections
    @entities = Entity.order(:name)
    @metrics = Metric.order(:label)
  end

  # Extracted to reduce AbcSize complexity in index action
  def load_filter_options
    @entities_for_filter = Entity.joins(:observations).distinct.order(:name)
    @metrics_for_filter = Metric.joins(:observations).distinct.order(:label)
    @documents_for_filter = Document.joins(:observations).distinct.order(fiscal_year: :desc, title: :asc)
  end

  def filter_documents
    @documents = if @observation.entity_id.present?
                   Document.where(entity_id: @observation.entity_id)
                           .order(fiscal_year: :desc, title: :asc)
                 else
                   []
                 end
  end

  def assign_fiscal_year
    return unless @observation.document

    @observation.fiscal_year = @observation.document.fiscal_year
  end

  def observation_params
    params.expect(observation: %i[entity_id document_id metric_id value_numeric value_text page_reference notes])
  end

  def filter_params
    # remove blank values so we don't generate "WHERE field IS NULL"
    params.permit(:entity_id, :metric_id, :fiscal_year, :document_id).compact_blank
  end
end
