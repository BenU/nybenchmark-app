# frozen_string_literal: true

require "test_helper"

class SchoolDistrictComparisonsControllerTest < ActionDispatch::IntegrationTest
  # ==========================================
  # BASIC PAGE LOADING
  # ==========================================

  test "compare page loads successfully" do
    get school_districts_compare_url
    assert_response :success
  end

  test "compare page is indexable (no noindex meta tag)" do
    get school_districts_compare_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "compare page has page title" do
    get school_districts_compare_url
    assert_response :success
    assert_select "h1", text: /School District Comparisons/
  end

  # ==========================================
  # AXIS CONTROLS
  # ==========================================

  test "compare page has x-axis dropdown" do
    get school_districts_compare_url
    assert_response :success
    assert_select "select[name='x_axis']"
  end

  test "compare page has y-axis dropdown" do
    get school_districts_compare_url
    assert_response :success
    assert_select "select[name='y_axis']"
  end

  test "compare page has year dropdown" do
    get school_districts_compare_url
    assert_response :success
    assert_select "select[name='year']"
  end

  # ==========================================
  # PARAMETER HANDLING
  # ==========================================

  test "compare page accepts x_axis parameter" do
    get school_districts_compare_url(x_axis: "school_enrollment")
    assert_response :success
  end

  test "compare page accepts y_axis parameter" do
    get school_districts_compare_url(y_axis: "school_per_pupil_spending")
    assert_response :success
  end

  test "compare page accepts year parameter" do
    get school_districts_compare_url(year: 2023)
    assert_response :success
  end

  test "compare page accepts all parameters together" do
    get school_districts_compare_url(
      x_axis: "school_enrollment",
      y_axis: "school_per_pupil_spending",
      year: 2023
    )
    assert_response :success
  end

  test "compare page ignores invalid axis parameters gracefully" do
    get school_districts_compare_url(x_axis: "invalid_metric", y_axis: "also_invalid")
    assert_response :success
  end

  test "compare page accepts min_enrollment parameter" do
    get school_districts_compare_url(min_enrollment: 500)
    assert_response :success
  end

  test "compare page ignores invalid min_enrollment parameter" do
    get school_districts_compare_url(min_enrollment: 999)
    assert_response :success
  end

  test "compare page accepts district_type parameter" do
    get school_districts_compare_url(district_type: "central")
    assert_response :success
  end

  test "compare page ignores invalid district_type parameter" do
    get school_districts_compare_url(district_type: "invalid_type")
    assert_response :success
  end

  # ==========================================
  # CONTENT STRUCTURE
  # ==========================================

  test "compare page has chart container" do
    get school_districts_compare_url
    assert_response :success
    assert_select ".scatter-chart-container"
  end

  test "compare page has legend" do
    get school_districts_compare_url
    assert_response :success
    assert_select ".scatter-legend"
  end

  test "compare page links to methodology" do
    get school_districts_compare_url
    assert_response :success
    assert_select "a[href=?]", methodology_path
  end
end
