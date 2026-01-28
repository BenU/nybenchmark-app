# frozen_string_literal: true

require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Using 'yonkers' (NYC) from your uploaded entities.yml
    @entity = entities(:yonkers)
  end

  test "should get index" do
    get entities_url
    assert_response :success

    # Pico.css Semantic Check: Main container presence
    assert_select "main.container"

    # Content Check: Should list entities
    assert_select "h1", "New York Entities"

    # Verify the table lists the entity name
    assert_select "table" do
      assert_select "tr", minimum: 1
      assert_select "td", text: @entity.name
    end
  end

  test "should show entity hub" do
    # Routing via Slug (e.g., /entities/nyc)
    get entity_url(@entity.slug)
    assert_response :success

    # Header Check
    assert_select "hgroup" do
      assert_select "h1", @entity.name
      # Checks for state or subtitle
      assert_select "p", text: /New York/
    end

    # Hub Requirements: Verify Sections exist for the related data
    assert_select "section#documents" do
      assert_select "h2", "Financial Documents"
    end

    assert_select "section#observations" do
      assert_select "h2", "Recent Data"
    end
  end

  test "update accepts icma_recognition_year" do
    sign_in users(:one)

    patch entity_url(@entity.slug), params: {
      entity: { icma_recognition_year: 1975 }
    }

    assert_redirected_to entity_url(@entity.slug)
    @entity.reload
    assert_equal 1975, @entity.icma_recognition_year
  end

  # ==========================================
  # FILTER TESTS
  # ==========================================

  test "index filter form has Clear button before Apply button" do
    get entities_url
    assert_response :success
    assert_match(/Clear.*Apply/m, response.body)
  end

  # ==========================================
  # CURATED FINANCIAL DASHBOARD TESTS
  # ==========================================

  test "show displays financial trends section with curated layout" do
    get entity_url(@entity.slug)
    assert_response :success

    # Should render trends section
    assert_select "section#financial-trends" do
      assert_select "h2", "Financial Trends"
    end
  end

  test "show displays fiscal year range in trends header" do
    get entity_url(@entity.slug)
    assert_response :success

    # Should show year range in subheading
    assert_select "section#financial-trends p", text: /\d{4}-\d{4}/
  end

  test "show does not display trends section for entity without observations" do
    albany = entities(:albany)
    get entity_url(albany.slug)
    assert_response :success

    # Albany has no observations
    assert_select "section#financial-trends", count: 0
  end

  # ==========================================
  # FISCAL HEALTH SECTION TESTS
  # ==========================================

  test "show displays fiscal health section with balance sheet items" do
    get entity_url(@entity.slug)
    assert_response :success

    # Should have Fiscal Health subsection
    assert_select "section#financial-trends h3", text: /Fiscal Health/

    # Should show Unassigned Fund Balance card (from A917)
    assert_select "article.trend-card--balance-sheet", text: /Unassigned Fund Balance/

    # Should show Cash Position card (A200 + A201 combined)
    assert_select "article.trend-card--balance-sheet", text: /Cash Position/

    # Should show Debt Service card
    assert_select "article.trend-card--expenditure", text: /Debt Service/
  end

  test "show displays correct value for unassigned fund balance" do
    get entity_url(@entity.slug)
    assert_response :success

    # Fixture has $75M for 2023 - should appear in card
    assert_select "article.trend-card", text: /Unassigned Fund Balance.*\$75,000,000/m
  end

  test "show displays combined cash position from A200 and A201" do
    get entity_url(@entity.slug)
    assert_response :success

    # A200 ($25M) + A201 ($10M) = $35M
    assert_select "article.trend-card", text: /Cash Position.*\$35,000,000/m
  end

  # ==========================================
  # DERIVED METRICS TESTS
  # ==========================================

  test "show displays fund balance percentage when data available" do
    get entity_url(@entity.slug)
    assert_response :success
    assert_select "article.trend-card--derived", minimum: 1
    assert_select ".trend-card--derived", text: /Fund Balance %/
  end

  test "show displays debt service percentage when data available" do
    get entity_url(@entity.slug)
    assert_response :success
    assert_select ".trend-card--derived", text: /Debt Service %/
  end

  test "derived metrics show percentage values" do
    get entity_url(@entity.slug)
    assert_response :success
    # Percentage should appear with % symbol
    assert_select ".trend-card--derived .trend-latest", text: /%/
  end

  test "derived metrics do not appear for entity without observations" do
    albany = entities(:albany)
    get entity_url(albany.slug)
    assert_response :success
    assert_select "article.trend-card--placeholder", count: 0
    assert_select "article.trend-card--derived", count: 0
  end

  # ==========================================
  # TOP REVENUE SOURCES TESTS
  # ==========================================

  test "show displays top revenue sources section" do
    get entity_url(@entity.slug)
    assert_response :success

    # Should have Top Revenue Sources subsection
    assert_select "section#financial-trends h3", text: /Top Revenue Sources/

    # Should show property taxes (largest revenue category)
    assert_select "article.trend-card--revenue", text: /Real Property Taxes/
  end

  test "show displays revenue categories sorted by value descending" do
    get entity_url(@entity.slug)
    assert_response :success

    # Get all revenue category names in order
    response_body = response.body
    property_pos = response_body.index("Real Property Taxes")
    sales_pos = response_body.index("Non-property Taxes")
    state_pos = response_body.index("State Aid")

    # Property taxes (350M) should appear before Sales tax (85M), which should appear before State aid (45M)
    assert property_pos < sales_pos, "Property taxes should appear before sales tax"
    assert sales_pos < state_pos, "Sales tax should appear before state aid"
  end

  # ==========================================
  # TOP EXPENDITURES TESTS
  # ==========================================

  test "show displays top expenditures section" do
    get entity_url(@entity.slug)
    assert_response :success

    # Should have Top Expenditures subsection
    assert_select "section#financial-trends h3", text: /Top Expenditures/

    # Should show Public Safety (expenditure category)
    assert_select "article.trend-card--expenditure", text: /Public Safety/
  end

  test "show excludes Debt Service from top expenditures section" do
    get entity_url(@entity.slug)
    assert_response :success

    # Find the Top Expenditures section and verify Debt Service is not there
    # (it should be in Fiscal Health instead)
    response_body = response.body

    # Find where Top Expenditures section starts
    expenditures_section_start = response_body.index("Top Expenditures")
    assert expenditures_section_start, "Top Expenditures section should exist"

    # Debt Service should appear BEFORE Top Expenditures (in Fiscal Health section)
    debt_service_pos = response_body.index("Debt Service")
    assert debt_service_pos < expenditures_section_start,
           "Debt Service should be in Fiscal Health, not Top Expenditures"
  end

  # ==========================================
  # EMPTY DATA HANDLING TESTS
  # ==========================================

  test "show handles entity with no observations gracefully" do
    albany = entities(:albany)
    get entity_url(albany.slug)
    assert_response :success

    # Should not display trends section at all
    assert_select "section#financial-trends", count: 0

    # Page should still render without errors
    assert_select "h1", "Albany"
  end

  # ==========================================
  # CSS CLASS TESTS
  # ==========================================

  test "show displays balance sheet cards with correct CSS class" do
    get entity_url(@entity.slug)
    assert_response :success

    # Balance sheet items should have blue styling
    assert_select "article.trend-card--balance-sheet", minimum: 2
  end

  test "show displays revenue cards with correct CSS class" do
    get entity_url(@entity.slug)
    assert_response :success

    # Revenue items should have green styling
    assert_select "article.trend-card--revenue", minimum: 1
  end

  test "show displays expenditure cards with correct CSS class" do
    get entity_url(@entity.slug)
    assert_response :success

    # Expenditure items should have red styling
    assert_select "article.trend-card--expenditure", minimum: 1
  end
end
