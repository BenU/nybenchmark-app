# frozen_string_literal: true

class MetricsController < ApplicationController
  include Pagy::Method

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_metric, only: %i[show edit update]

  def index
    scope = Metric.where(filter_params).sorted_by(params[:sort], params[:direction])
    @pagy, @metrics = pagy(:offset, scope, limit: 25)
  end

  def show; end

  def new
    @metric = Metric.new
  end

  def edit; end

  def create
    @metric = Metric.new(metric_params)

    if @metric.save
      redirect_to @metric, notice: "Metric was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @metric.update(metric_params)
      redirect_to @metric, notice: "Metric was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_metric
    @metric = Metric.find(params[:id])
  end

  def metric_params
    params.expect(metric: %i[key label unit description value_type display_format formula data_source account_code])
  end

  def filter_params
    params.permit(:value_type, :data_source).compact_blank
  end
end
