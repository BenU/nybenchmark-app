# frozen_string_literal: true

class DocumentsController < ApplicationController
  # HTTP Basic Auth using credentials
  before_action :authenticate_admin, only: %i[new create]

  def index
    # Eager load :entity to avoid N+1 queries when listing names
    @documents = Document.includes(:entity).order(fiscal_year: :desc)
  end

  def show
    @document = Document.find(params[:id])
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to @document, notice: "Document uploaded successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def document_params
    params.expect(document: %i[title doc_type fiscal_year entity_id source_url notes file])
  end

  # Define the authentication logic securely
  def authenticate_admin
    authenticate_or_request_with_http_basic do |username, password|
      # Use fetch to ensure the app crashes loudly if you forget to set these ENVs
      username == ENV.fetch("HTTP_AUTH_USER") &&
        password == ENV.fetch("HTTP_AUTH_PASSWORD")
    end
  end
end
