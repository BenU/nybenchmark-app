# frozen_string_literal: true

module ApplicationHelper
  # Renders a sortable column header link with direction indicator
  def sortable_column_header(column:, label:, path:, **options)
    is_active = options[:current_sort] == column.to_s
    current_dir = options[:current_direction]
    default_dir = options[:default_direction] || "asc"

    new_direction = compute_sort_direction(is_active, current_dir, default_dir)
    sort_params = request.query_parameters.merge(sort: column, direction: new_direction)
    indicator = sort_indicator(is_active, current_dir)
    css_class = is_active ? "sortable-header active" : "sortable-header"

    link_to "#{label}#{indicator}", send(path, sort_params), class: css_class
  end

  private

  def compute_sort_direction(is_active, current_dir, default_dir)
    return default_dir unless is_active

    current_dir == "asc" ? "desc" : "asc"
  end

  def sort_indicator(is_active, current_dir)
    return "" unless is_active

    current_dir == "asc" ? " ↑" : " ↓"
  end
end
