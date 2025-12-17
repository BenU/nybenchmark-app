# frozen_string_literal: true

class DocumentsController < ApplicationController
  # HTTP Basic Auth using credentials
  http_basic_authenticate_with name: "admin", password: "password", only: %i[new create]

  def show
    @document = Document.find(params[:id])
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to root_path, notice: "Document uploaded successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def document_params
    params.expect(document: %i[title doc_type fiscal_year entity_id source_url notes file])
  end
end
