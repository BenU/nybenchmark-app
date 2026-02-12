# frozen_string_literal: true

# Loads scatter plot data for school district comparisons.
# Used by SchoolDistrictComparisonsController.
module SchoolDistrictScatterData # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  # Metrics available for X/Y axis selection.
  # Format: key => { label: "Human Label", format: :display_format }
  SCATTER_METRICS = {
    "school_enrollment" => { label: "Enrollment", format: :integer },
    "school_per_pupil_spending" => { label: "Per-Pupil Spending", format: :currency },
    "school_per_pupil_instruction" => { label: "Per-Pupil Instruction", format: :currency },
    "school_per_pupil_administration" => { label: "Per-Pupil Administration", format: :currency },
    "school_admin_overhead_pct" => { label: "Administrative Overhead %", format: :percentage },
    "school_state_aid_dependency_pct" => { label: "State Aid Dependency %", format: :percentage }
  }.freeze

  # Default axes for initial page load
  DEFAULT_X_AXIS = "school_enrollment"
  DEFAULT_Y_AXIS = "school_per_pupil_spending"

  # Colors for each school_legal_type (matching entity color scheme)
  LEGAL_TYPE_COLORS = {
    "big_five" => "#dc2626",      # Red - fiscally dependent on cities
    "small_city" => "#f97316",    # Orange
    "central" => "#2563eb",       # Blue - most common
    "union_free" => "#16a34a",    # Green
    "common" => "#8b5cf6"         # Purple - rare
  }.freeze

  LEGAL_TYPE_LABELS = {
    "big_five" => "Big Five",
    "small_city" => "Small City",
    "central" => "Central",
    "union_free" => "Union Free",
    "common" => "Common"
  }.freeze

  private

  def scatter_plot_metrics
    SCATTER_METRICS
  end

  def legal_type_colors
    LEGAL_TYPE_COLORS
  end

  def legal_type_labels
    LEGAL_TYPE_LABELS
  end

  # Returns the selected X axis metric key, falling back to default
  def selected_x_axis
    key = params[:x_axis]
    SCATTER_METRICS.key?(key) ? key : DEFAULT_X_AXIS
  end

  # Returns the selected Y axis metric key, falling back to default
  def selected_y_axis
    key = params[:y_axis]
    SCATTER_METRICS.key?(key) ? key : DEFAULT_Y_AXIS
  end

  # Returns the selected fiscal year, falling back to most recent
  def selected_year
    year = params[:year].to_i
    available = available_scatter_years
    available.include?(year) ? year : available.first
  end

  # Returns the selected minimum enrollment filter
  def selected_min_enrollment
    val = params[:min_enrollment].to_i
    [0, 50, 100, 250, 500, 1000].include?(val) ? val : 0
  end

  # Returns the selected district type filter (nil means all types)
  def selected_district_type
    type = params[:district_type]
    LEGAL_TYPE_LABELS.key?(type) ? type : nil
  end

  # Returns fiscal years that have scatter plot data, most recent first
  def available_scatter_years
    @available_scatter_years ||= Observation.joins(:metric, :entity)
                                            .where(entities: { kind: :school_district })
                                            .where(metrics: { key: SCATTER_METRICS.keys })
                                            .distinct
                                            .pluck(:fiscal_year)
                                            .sort
                                            .reverse
  end

  # Loads scatter plot data for the selected axes and year.
  def load_scatter_data(x_axis:, y_axis:, year:, min_enrollment: 0, district_type: nil)
    district_ids = filtered_district_ids(district_type, year, min_enrollment)
    return [] if district_ids.empty?

    x_values = metric_values_by_entity(x_axis, district_ids, year)
    y_values = metric_values_by_entity(y_axis, district_ids, year)
    common_ids = (x_values.keys & y_values.keys) & district_ids
    return [] if common_ids.empty?

    entities = Entity.where(id: common_ids).index_by(&:id)
    build_scatter_series(common_ids, x_values, y_values, entities)
  end

  def filtered_district_ids(district_type, year, min_enrollment)
    districts = Entity.school_districts
    districts = districts.where(school_legal_type: district_type) if district_type.present?
    ids = districts.pluck(:id)
    min_enrollment.positive? ? filter_by_enrollment(ids, year, min_enrollment) : ids
  end

  def filter_by_enrollment(district_ids, year, min_enrollment)
    enrollment_values = metric_values_by_entity("school_enrollment", district_ids, year)
    district_ids.select { |id| enrollment_values[id].to_i >= min_enrollment }
  end

  # Returns {entity_id => value} hash for a metric in a given year
  def metric_values_by_entity(metric_key, entity_ids, year)
    Observation
      .joins(:metric)
      .where(entity_id: entity_ids, fiscal_year: year, metrics: { key: metric_key })
      .pluck(:entity_id, :value_numeric)
      .to_h
  end

  # Groups data into series by school_legal_type for Chart.js
  # rubocop:disable Metrics/CyclomaticComplexity
  def build_scatter_series(entity_ids, x_values, y_values, entities)
    # Group entity IDs by their legal type
    by_type = entity_ids.group_by { |id| entities[id]&.school_legal_type }

    LEGAL_TYPE_COLORS.filter_map do |type, color|
      ids = by_type[type] || []
      next if ids.empty?

      data_points = ids.map { |id| build_data_point(id, x_values, y_values, entities) }

      { name: LEGAL_TYPE_LABELS[type] || type.titleize, data: data_points, backgroundColor: color }
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def build_data_point(id, x_values, y_values, entities)
    entity = entities[id]
    { x: x_values[id], y: y_values[id], name: entity&.name || "Unknown", slug: entity&.slug }
  end
end
