# frozen_string_literal: true

class DocumentsController < ApplicationController
  include Pagy::Method

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_document, only: %i[show edit update]
  before_action :load_doc_type_suggestions, only: %i[new edit create update]

  def index
    load_filter_options
    scope = Document.includes(:entity)
                    .where(filter_params)
                    .sorted_by(params[:sort], params[:direction])
    @pagy, @documents = pagy(:offset, scope, limit: 25)
  end

  def show; end

  def new
    @document = Document.new
    # Pre-select entity if passed in params (optional convenience)
    @document.entity_id = params[:entity_id] if params[:entity_id]
  end

  def edit; end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to @document, notice: "Document uploaded successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @document.update(document_params)
      redirect_to @document, notice: "Document was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    # Rails 8 'expect' syntax
    params.expect(document: %i[title doc_type fiscal_year entity_id source_url notes file])
  end

  def filter_params
    params.permit(:doc_type, :fiscal_year, :entity_id).compact_blank
  end

  def load_filter_options
    @doc_types = Document.distinct.pluck(:doc_type).compact.sort
    @fiscal_years = Document.distinct.pluck(:fiscal_year).compact.sort.reverse
    @entities_for_filter = Entity.joins(:documents).distinct.order(:name)
  end

  def load_doc_type_suggestions
    common_types = %w[acfr budget school_budget school_financials]
    existing_types = Document.distinct.pluck(:doc_type).compact
    @doc_type_suggestions = (common_types + existing_types).uniq.sort
  end
end
