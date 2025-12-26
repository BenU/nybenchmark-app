# frozen_string_literal: true

class EntitiesController < ApplicationController
  def index
    @entities = Entity.order(:name)
  end

  def show
    # Strict lookup by slug
    @entity = Entity.find_by!(slug: params[:slug])

    # Pre-fetch related data for the Hub sections
    @documents = @entity.documents.order(fiscal_year: :desc)

    # Eager load metric/document to prevent N+1 queries in the view
    @observations = @entity.observations.includes(:metric).order(fiscal_year: :desc).limit(10)
  end
end
