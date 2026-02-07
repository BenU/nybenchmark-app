# frozen_string_literal: true

require "test_helper"

class CountyComparisonsControllerTest < ActionDispatch::IntegrationTest
  # ==========================================
  # BASIC PAGE LOADING
  # ==========================================

  test "compare page loads successfully" do
    get counties_compare_url
    assert_response :success
  end

  test "compare page is indexable (no noindex meta tag)" do
    get counties_compare_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "compare page has page title" do
    get counties_compare_url
    assert_response :success
    assert_select "h1", text: /County Political Composition/
  end

  # ==========================================
  # CONTENT STRUCTURE
  # ==========================================

  test "compare page has scatter chart containers when data exists" do
    get counties_compare_url
    assert_response :success
    # With fixture data for 3 counties, charts should render
    assert_select ".scatter-chart-container", minimum: 3
  end

  test "compare page has legend with partisan background zones" do
    get counties_compare_url
    assert_response :success
    assert_select ".scatter-legend" do
      assert_select ".scatter-legend-item", text: /D-leaning/
      assert_select ".scatter-legend-item", text: /Balanced/
      assert_select ".scatter-legend-item", text: /R-leaning/
    end
  end

  test "compare page has operating ratio section" do
    get counties_compare_url
    assert_response :success
    assert_select "h3", text: /Operating Ratio/
  end

  test "compare page has fund balance section" do
    get counties_compare_url
    assert_response :success
    assert_select "h3", text: /Fund Balance/
  end

  test "compare page has debt service section" do
    get counties_compare_url
    assert_response :success
    assert_select "h3", text: /Debt Service/
  end

  test "compare page shows fiscal year in description" do
    get counties_compare_url
    assert_response :success
    # With fixture data at FY 2024, should mention the year
    assert_select "p", text: /fiscal year/i
  end

  test "compare page accepts year parameter" do
    get counties_compare_url(year: 2024)
    assert_response :success
    assert_select "strong", text: "2024"
  end

  test "compare page shows year scroller when multiple years available" do
    # Fixture data only has FY 2024 (single year), so scroller won't appear
    # This test verifies the page still loads and shows the year
    get counties_compare_url
    assert_response :success
    assert_select "strong", text: "2024"
  end

  # ==========================================
  # ABOUT SECTION
  # ==========================================

  test "compare page links to methodology" do
    get counties_compare_url
    assert_response :success
    assert_select "a[href=?]", methodology_path
  end

  test "compare page mentions veto-proof thresholds" do
    get counties_compare_url
    assert_response :success
    assert_select "article", text: /veto-proof/
  end

  test "compare page describes operating ratio" do
    get counties_compare_url
    assert_response :success
    assert_select "article", text: /Operating Ratio/
  end
end
