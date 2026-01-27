# frozen_string_literal: true

require "test_helper"

class MetricsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @metric = metrics(:one)
    @text_metric = metrics(:bond_rating)
  end

  test "should get index" do
    get metrics_url
    assert_response :success
    assert_select "h1", "Metrics"
  end

  # ==========================================
  # FILTER TESTS
  # ==========================================

  test "index renders filter form" do
    get metrics_url
    assert_response :success
    assert_select "form[method='get'][action='#{metrics_path}']"
    assert_select "fieldset legend", text: "Filters"
  end

  test "index filters by value_type numeric" do
    get metrics_url(value_type: "numeric")
    assert_response :success
    # Should see numeric metrics only
    assert_select "td a", text: @metric.label
    # Should NOT see text metrics
    assert_select "td a", text: @text_metric.label, count: 0
  end

  test "index filters by value_type text" do
    get metrics_url(value_type: "text")
    assert_response :success
    # Should see text metrics only
    assert_select "td a", text: @text_metric.label
    # Should NOT see numeric metrics
    assert_select "td a", text: @metric.label, count: 0
  end

  test "index filter preserves sort params" do
    get metrics_url(value_type: "numeric", sort: "label", direction: "desc")
    assert_response :success
    assert_select "input[type='hidden'][name='sort'][value='label']"
    assert_select "input[type='hidden'][name='direction'][value='desc']"
  end

  test "index filter form has Clear before Apply" do
    get metrics_url
    assert_response :success
    assert_match(/Clear.*Apply/m, response.body)
  end

  # ==========================================
  # CATEGORY DISPLAY TESTS
  # ==========================================

  test "index displays category column" do
    get metrics_url
    assert_response :success
    assert_select "th", text: "Category"
  end

  test "index shows level_1_category for OSC metrics" do
    osc_metric = metrics(:police_personal_services)
    get metrics_url
    assert_response :success
    assert_select "td", text: osc_metric.level_1_category
  end

  test "index filter includes level_1_category dropdown" do
    get metrics_url
    assert_response :success
    assert_select "select[name='level_1_category']"
  end

  test "index filters by level_1_category" do
    osc_metric = metrics(:police_personal_services) # Public Safety
    sanitation_metric = metrics(:sanitation_personal_services) # Sanitation

    get metrics_url(level_1_category: "Public Safety")
    assert_response :success

    # Should see Public Safety metrics
    assert_select "td a", text: osc_metric.label
    # Should NOT see Sanitation metrics
    assert_select "td a", text: sanitation_metric.label, count: 0
  end

  test "show displays category for OSC metrics" do
    sign_in @user
    osc_metric = metrics(:police_personal_services)

    get metric_url(osc_metric)
    assert_response :success

    assert_select "strong", text: "Category:"
    assert_match osc_metric.level_1_category, response.body
    assert_match osc_metric.level_2_category, response.body
  end

  test "show does not display category section for metrics without categories" do
    sign_in @user

    get metric_url(@metric) # manual metric without categories
    assert_response :success

    # Should not show category labels for metrics without categories
    assert_select "strong", text: "Category:", count: 0
  end
end
