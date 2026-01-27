# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Pagy::Method

  layout "verify", only: %i[new edit verify]

  # 1. Strict Security: Guests can ONLY see Index and Show
  before_action :authenticate_user!, except: %i[index show]

  before_action :set_observation, only: %i[show edit update destroy verify]
  before_action :set_collections, only: %i[new create edit update verify]

  def index
    # 2. Scope Logic: Guests see verified only. Users see all.
    base_scope = user_signed_in? ? Observation.all : Observation.verified

    scope = base_scope.includes(:entity, :metric, :document)
                      .where(filter_params)
                      .search(params[:q])
                      .sorted_by(params[:sort], params[:direction])

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

    commit_action = params[:commit_action]
    is_verify_action = commit_action == "verify_next"
    is_skip_action = commit_action == "skip_next"
    @observation.verification_status = :verified if is_verify_action

    if @observation.save
      handle_update_success(commit_action)
    else
      handle_update_failure(is_verify_action || is_skip_action)
    end
  end

  def destroy
    @observation.destroy
    redirect_to observations_url, notice: "Observation was successfully destroyed."
  end

  private

  def handle_update_success(commit_action)
    case commit_action
    when "verify_next"
      redirect_to_next_or_index("Observation verified. Find next item below...", "Verified. Queue empty!")
    when "skip_next"
      redirect_to_next_or_index("Saved. Skipped to next item...", "Saved. No more provisional observations in queue.")
    else
      redirect_to @observation, notice: "Observation was successfully updated."
    end
  end

  def redirect_to_next_or_index(next_notice, empty_notice)
    next_obs = @observation.next_provisional_observation
    redirect_to next_obs ? verify_observation_path(next_obs) : observations_path,
                notice: next_obs ? next_notice : empty_notice
  end

  def handle_update_failure(from_cockpit)
    filter_documents
    cockpit_mode = from_cockpit || action_name == "verify" || request.path.include?("/verify")
    @document = @observation.document if cockpit_mode
    render cockpit_mode ? :verify : :edit, status: :unprocessable_content
  end

  def set_observation
    @observation = Observation.find(params[:id])
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
    @documents = Document.for_entity(@observation.entity_id)
  end

  def observation_params
    permitted = %i[entity_id document_id metric_id value_numeric value_text
                   page_reference notes verification_status pdf_page]
    permitted << { document_attributes: %i[id source_url] }
    params.expect(observation: permitted)
  end

  def filter_params
    # Allow filtering by status
    params.permit(:entity_id, :metric_id, :fiscal_year, :document_id, :verification_status).compact_blank
  end
end
