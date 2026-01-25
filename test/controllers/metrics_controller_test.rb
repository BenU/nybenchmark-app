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
end
