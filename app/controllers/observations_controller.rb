# frozen_string_literal: true

class ObservationsController < ApplicationController
  include Pagy::Method

  def index
    observations = Observation.includes(:entity, :metric, :document)
    observations = apply_filters(observations)
    observations = apply_search(observations)
    observations = apply_sort(observations)

    # Pagination (offset) — ordered relation required for deterministic paging
    @pagy, @observations = pagy(:offset, observations, limit: 50)

    # Filter UI support (only records that actually appear in observations)
    @entities_for_filter = Entity.joins(:observations).distinct.order(:name)
    @metrics_for_filter = Metric.joins(:observations).distinct.order(:label)
    @documents_for_filter = Document.joins(:observations).distinct.order(fiscal_year: :desc, title: :asc)
  end

  def show
    @observation = Observation.includes(:entity, :metric, :document).find(params[:id])
  end

  private

  def apply_filters(relation)
    filters = {
      entity_id: params[:entity_id].presence,
      metric_id: params[:metric_id].presence,
      fiscal_year: params[:fiscal_year].presence,
      document_id: params[:document_id].presence
    }.compact

    relation.where(filters)
  end

  def apply_search(relation)
    q = params[:q].to_s.strip
    return relation if q.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"

    relation
      .left_joins(:entity, :metric, :document)
      .where(
        "entities.name ILIKE :q OR metrics.key ILIKE :q OR metrics.label ILIKE :q OR documents.title ILIKE :q",
        q: pattern
      )
  end

  def apply_sort(relation)
    case params[:sort]
    when "fiscal_year_desc"
      relation.order(fiscal_year: :desc, updated_at: :desc)
    when "entity_name_asc"
      relation.left_joins(:entity).order("entities.name ASC").order(updated_at: :desc)
    else
      relation.order(updated_at: :desc)
    end
  end
end
