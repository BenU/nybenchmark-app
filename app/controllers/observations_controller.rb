# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Pagy::Method

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_observation, only: %i[show edit update destroy verify]
  before_action :set_collections, only: %i[new create edit update verify]

  def index
    scope = Observation.includes(:entity, :metric, :document)
                       .where(filter_params)
                       .search(params[:q])
                       .sorted_by(params[:sort])

    @pagy, @observations = pagy(:offset, scope, limit: 20)
    load_filter_options
  end

  def show; end

  def verify
    # Renders 'verify.html.erb'
    @document = @observation.document
  end

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

    if @observation.save
      redirect_to verify_observation_path(@observation), notice: "Observation created. Please verify details."
    else
      filter_documents
      render :new, status: :unprocessable_content
    end
  end

  def update
    @observation.assign_attributes(observation_params)

    # 1. Handle Verification Logic
    is_verify_action = params[:commit_action] == "verify_next"
    @observation.verification_status = :verified if is_verify_action

    # 2. Save and Delegate Response
    if @observation.save
      handle_update_success(is_verify_action)
    else
      handle_update_failure(is_verify_action)
    end
  end

  def destroy
    @observation.destroy
    redirect_to observations_url, notice: "Observation was successfully destroyed."
  end

  private

  def handle_update_success(is_verify_action)
    if is_verify_action
      next_obs = @observation.next_provisional_observation
      if next_obs
        redirect_to verify_observation_path(next_obs), notice: "Observation verified. Find next item below..."
      else
        redirect_to observations_path, notice: "Verified. Queue empty!"
      end
    else
      redirect_to @observation, notice: "Observation was successfully updated."
    end
  end

  def handle_update_failure(is_verify_action)
    filter_documents

    # If error occurred in verify cockpit, re-render cockpit
    if is_verify_action || action_name == "verify" || request.path.include?("/verify")
      @document = @observation.document
      render :verify, status: :unprocessable_content
    else
      render :edit, status: :unprocessable_content
    end
  end

  def set_observation
    @observation = Observation.includes(:entity, :metric, :document).find(params[:id])
  end

  def set_collections
    @entities = Entity.order(:name)
    @metrics = Metric.order(:label)
  end

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

  def observation_params
    params.expect(observation: %i[
                    entity_id document_id metric_id value_numeric value_text
                    page_reference notes verification_status pdf_page
                  ])
  end

  def filter_params
    params.permit(:entity_id, :metric_id, :fiscal_year, :document_id).compact_blank
  end
end
