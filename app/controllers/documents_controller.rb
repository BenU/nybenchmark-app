# frozen_string_literal: true

class DocumentsController < ApplicationController
  include Pagy::Method

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_document, only: %i[show edit update]

  def index
    scope = Document.includes(:entity).sorted_by(params[:sort], params[:direction])
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
end
