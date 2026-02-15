# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  # ==========================================
  # METHODOLOGY PAGE
  # ==========================================

  test "methodology page loads successfully" do
    get methodology_url
    assert_response :success
  end

  test "methodology page is indexable (no noindex meta tag)" do
    get methodology_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "methodology page mentions OSC data source" do
    get methodology_url
    assert_response :success
    assert_select "main", text: /NYS Comptroller/
  end

  test "methodology page mentions Census data source" do
    get methodology_url
    assert_response :success
    assert_select "main", text: /Census Bureau/
  end

  test "methodology page has data accuracy section" do
    get methodology_url
    assert_response :success
    assert_select "h2", text: "Data Accuracy"
    assert_select "main", text: /cannot guarantee completeness/
  end

  test "methodology page does not have open source section" do
    get methodology_url
    assert_response :success
    assert_select "h2", text: "Open Source", count: 0
    assert_select "a", text: /MIT license/, count: 0
  end

  test "methodology page mentions county partisan data source" do
    get methodology_url
    assert_response :success
    assert_select "main", text: /county board of elections/
  end

  # ==========================================
  # NON-FILERS PAGE
  # ==========================================

  test "non-filers page loads successfully" do
    get non_filers_url
    assert_response :success
  end

  test "non-filers page is indexable (no noindex meta tag)" do
    get non_filers_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "non-filers page explains why filing matters" do
    get non_filers_url
    assert_response :success
    assert_select "main", text: /filing/i
  end

  test "non-filers page links to methodology" do
    get non_filers_url
    assert_response :success
    assert_select "a[href=?]", methodology_path
  end

  test "non-filers page does not list NYC" do
    get non_filers_url
    assert_response :success
    assert_select "td", text: "New York City", count: 0
  end

  # ==========================================
  # VERSION ENDPOINT
  # ==========================================

  test "version endpoint returns JSON with sha" do
    get version_url
    assert_response :success
    json = response.parsed_body
    assert json.key?("sha"), "Expected JSON to contain 'sha' key"
    assert json["sha"].present?, "Expected sha to be present"
  end

  test "version endpoint returns valid JSON content type" do
    get version_url
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end
end
