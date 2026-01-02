# frozen_string_literal: true

class MetricsController < ApplicationController
  def index
    @metrics = Metric.order(:label)
  end

  def show
    @metric = Metric.find(params[:id])
  end
end
