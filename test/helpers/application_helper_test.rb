# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  MockRequest = Struct.new(:query_parameters)

  # Mock request for query_parameters - must be fresh each call to pick up @query_params
  def request
    MockRequest.new(@query_params || {})
  end

  # ==========================================
  # SORTABLE COLUMN HEADER TESTS
  # ==========================================

  test "sortable_column_header renders link with label" do
    @query_params = {}

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: nil,
      current_direction: nil
    )

    assert_includes html, "Name"
    assert_includes html, "href="
    assert_includes html, "sort=name"
    assert_includes html, "direction=asc"
  end

  test "sortable_column_header shows up arrow when active and ascending" do
    @query_params = { sort: "name", direction: "asc" }

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: "name",
      current_direction: "asc"
    )

    assert_includes html, "↑"
    assert_includes html, "active"
  end

  test "sortable_column_header shows down arrow when active and descending" do
    @query_params = { sort: "name", direction: "desc" }

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: "name",
      current_direction: "desc"
    )

    assert_includes html, "↓"
    assert_includes html, "active"
  end

  test "sortable_column_header toggles to descending when currently ascending" do
    @query_params = { sort: "name", direction: "asc" }

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: "name",
      current_direction: "asc"
    )

    # Should link to desc when currently asc
    assert_includes html, "direction=desc"
  end

  test "sortable_column_header toggles to ascending when currently descending" do
    @query_params = { sort: "name", direction: "desc" }

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: "name",
      current_direction: "desc"
    )

    # Should link to asc when currently desc
    assert_includes html, "direction=asc"
  end

  test "sortable_column_header uses default_direction for inactive column" do
    @query_params = {}

    html = sortable_column_header(
      column: "fiscal_year",
      label: "Year",
      path: :documents_path,
      current_sort: nil,
      current_direction: nil,
      default_direction: "desc"
    )

    # Should use desc as default direction
    assert_includes html, "direction=desc"
  end

  test "sortable_column_header preserves existing query params" do
    @query_params = { page: "2", q: "search term" }

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: nil,
      current_direction: nil
    )

    # Should preserve page and q params
    assert_includes html, "page=2"
    assert_includes html, "q=search"
  end

  test "sortable_column_header inactive column has no arrow" do
    @query_params = { sort: "kind", direction: "asc" }

    html = sortable_column_header(
      column: "name",
      label: "Name",
      path: :entities_path,
      current_sort: "kind",
      current_direction: "asc"
    )

    # Should not have arrow when not the active sort column
    assert_not_includes html, "↑"
    assert_not_includes html, "↓"
    assert_not_includes html, "active"
  end
end
