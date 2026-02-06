# frozen_string_literal: true

class SchoolDistrictComparisonsController < ApplicationController
  include SchoolDistrictScatterData

  def show
    load_filter_options
    @scatter_data = load_scatter_data(
      x_axis: @x_axis, y_axis: @y_axis, year: @year,
      min_enrollment: @min_enrollment, district_type: @district_type
    )
  end

  private

  def load_filter_options
    @metrics = scatter_plot_metrics
    @x_axis = selected_x_axis
    @y_axis = selected_y_axis
    @years = available_scatter_years
    @year = selected_year
    @min_enrollment = selected_min_enrollment
    @district_type = selected_district_type
    @legal_type_colors = legal_type_colors
    @legal_type_labels = legal_type_labels
  end
end
