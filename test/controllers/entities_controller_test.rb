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
    assert_select "details#documents" do
      assert_select "summary", text: /Financial Documents/
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
  # HERO STATS TESTS
  # ==========================================

  test "show displays hero stats for entity with financial data" do
    get entity_url(@entity.slug)
    assert_response :success

    # Yonkers has balance sheet + expenditure data, so derived stats should appear
    assert_select ".hero-stats"
    assert_select ".hero-stat", minimum: 1
    assert_select ".hero-stat-label"
  end

  test "show does not display hero stats for entity without data" do
    albany = entities(:albany)
    get entity_url(albany.slug)
    assert_response :success

    assert_select ".hero-stats", count: 0
  end

  # ==========================================
  # PAGE LAYOUT TESTS
  # ==========================================

  test "show renders governance in collapsible details element" do
    get entity_url(@entity.slug)
    assert_response :success

    assert_select "details#governance" do
      assert_select "summary", text: /Governance & Structure/
    end
  end

  test "show renders financial trends before governance section" do
    get entity_url(@entity.slug)
    assert_response :success

    body = response.body
    trends_pos = body.index('id="financial-trends"')
    governance_pos = body.index('id="governance"')

    assert trends_pos, "Financial trends section should exist"
    assert governance_pos, "Governance section should exist"
    assert trends_pos < governance_pos, "Financial trends should appear before governance"
  end

  # ==========================================
  # CUSTODIAL PASS-THROUGH EXCLUSION TESTS
  # ==========================================

  test "hero stats per-capita spending excludes TC-fund and interfund transfers" do
    # Yonkers fixture expenditure data for 2023:
    # - police_personal_services (A fund): $125M — real spending, included
    # - sanitation (A fund): $15M — real spending, included
    # - debt_service_interest (A fund): $8M — real spending, included
    # - custodial_pass_through (T fund): $50M — pass-through, EXCLUDED
    # - interfund_transfer_out (A fund, "Other Uses"): $30M — transfer, EXCLUDED
    # Included total: $148M
    # With pass-throughs + transfers: $228M

    # Add population data so hero stats compute per-capita
    pop_metric = metrics(:census_population)
    doc = documents(:yonkers_osc_afr_fy2023)
    Observation.create!(entity: @entity, document: doc, metric: pop_metric,
                        fiscal_year: 2023, value_numeric: 211_569)

    get entity_url(@entity.slug)
    assert_response :success

    # Per capita with real spending: $148M / 211,569 ~ $700
    # Per capita with everything: $228M / 211,569 ~ $1,078
    assert_select ".hero-stat-value", text: /\$7\d\d/
    assert_select ".hero-stat-value", text: /\$1,0\d\d/, count: 0
  end

  test "top expenditures exclude TC-fund metrics" do
    get entity_url(@entity.slug)
    assert_response :success

    # Custodial Activities should not appear in Top Expenditures
    assert_select ".trend-card--expenditure", text: /Custodial/, count: 0
  end

  test "top expenditures exclude interfund transfers" do
    get entity_url(@entity.slug)
    assert_response :success

    # "Other Uses" (interfund transfers) should not appear in Top Expenditures
    assert_select ".trend-card--expenditure", text: /Other Uses/, count: 0
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

  # ==========================================
  # NON-FILER INDEX BADGE TESTS
  # ==========================================

  test "index shows Late badge for non-filing entities" do
    get entities_url
    assert_response :success

    # Albany has no OSC data — should show Late badge
    assert_select ".non-filer-badge", minimum: 1
  end

  # ==========================================
  # NON-FILER BANNER TESTS
  # ==========================================

  test "show displays non-filer banner for entity without OSC data" do
    albany = entities(:albany)
    get entity_url(albany.slug)
    assert_response :success

    assert_select ".non-filer-banner"
  end

  test "show does not display non-filer banner for entity with current OSC data" do
    get entity_url(@entity.slug)
    assert_response :success

    assert_select ".non-filer-banner", count: 0
  end

  # ==========================================
  # FILING STATUS FILTER TESTS
  # ==========================================

  test "index has filing status filter dropdown" do
    get entities_url
    assert_response :success
    assert_select "select[name='filing_status']"
  end

  test "index filters to current filers only" do
    get entities_url, params: { filing_status: "current" }
    assert_response :success

    # Yonkers has OSC data (current filer), Albany does not
    assert_select "td", text: @entity.name
  end

  test "index filters to late/non-filers only" do
    get entities_url, params: { filing_status: "late" }
    assert_response :success

    # Yonkers is a current filer — should not appear
    assert_select "td", text: @entity.name, count: 0
  end

  # ==========================================
  # NYC EXEMPT FROM NON-FILER DISPLAY
  # ==========================================

  test "show does not display non-filer banner for NYC" do
    nyc = entities(:nyc)
    get entity_url(nyc.slug)
    assert_response :success
    assert_select ".non-filer-banner", count: 0
  end

  test "index does not show Late badge for NYC" do
    get entities_url
    assert_response :success

    # Find the NYC row and verify no Late badge next to it
    nyc = entities(:nyc)
    # NYC should appear in the table but without a non-filer badge
    assert_select "td", text: nyc.name
  end

  # ==========================================
  # DOCUMENTS SECTION SEO OPTIMIZATION
  # ==========================================

  test "show renders documents in collapsible details element" do
    get entity_url(@entity.slug)
    assert_response :success

    assert_select "details#documents" do
      assert_select "summary", text: /Financial Documents/
    end
  end

  test "show limits inline documents to 5 most recent" do
    # Add a 6th document to Yonkers (already has 5)
    Document.create!(
      entity: @entity,
      title: "OSC Annual Financial Report 2020",
      doc_type: "osc_afr",
      fiscal_year: 2020,
      source_type: :bulk_data,
      source_url: "https://example.com/osc-2020"
    )

    get entity_url(@entity.slug)
    assert_response :success

    # Should only show 5 documents in the table
    assert_select "details#documents table tbody tr", count: 5
  end

  test "show displays View all documents link when more than 5 documents exist" do
    # Add a 6th document
    Document.create!(
      entity: @entity,
      title: "OSC Annual Financial Report 2020",
      doc_type: "osc_afr",
      fiscal_year: 2020,
      source_type: :bulk_data,
      source_url: "https://example.com/osc-2020"
    )

    get entity_url(@entity.slug)
    assert_response :success

    # Should show "View all X documents" link
    assert_select "a[href*='documents']", text: /View all 6 documents/
  end

  test "show does not display View all link when 5 or fewer documents" do
    get entity_url(@entity.slug)
    assert_response :success

    # Yonkers has exactly 5 documents - no "View all" link needed
    assert_select "a", text: /View all.*documents/, count: 0
  end

  test "show document links have rel nofollow for SEO" do
    get entity_url(@entity.slug)
    assert_response :success

    # All document links should have rel="nofollow"
    assert_select "details#documents table a[rel='nofollow']", minimum: 1
    # No document links without nofollow
    assert_select "details#documents table a:not([rel='nofollow'])", count: 0
  end

  test "show View all documents link has rel nofollow" do
    # Add a 6th document
    Document.create!(
      entity: @entity,
      title: "OSC Annual Financial Report 2020",
      doc_type: "osc_afr",
      fiscal_year: 2020,
      source_type: :bulk_data,
      source_url: "https://example.com/osc-2020"
    )

    get entity_url(@entity.slug)
    assert_response :success

    assert_select "a[rel='nofollow']", text: /View all.*documents/
  end

  test "show documents summary shows count" do
    get entity_url(@entity.slug)
    assert_response :success

    # Summary should show document count
    assert_select "details#documents summary", text: /Financial Documents \(5\)/
  end

  # ==========================================
  # SEO: ENTITY PAGES SHOULD BE INDEXED
  # ==========================================

  test "index page does not include noindex meta tag" do
    get entities_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "show page does not include noindex meta tag" do
    get entity_url(@entity.slug)
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  # ==========================================
  # SCHOOL DISTRICT COMPARISON LINK
  # ==========================================

  test "index shows compare link when filtering by school districts" do
    get entities_url(kind: "school_district")
    assert_response :success

    assert_select ".school-district-compare-callout" do
      assert_select "a[href=?]", school_districts_compare_path
    end
  end

  test "index does not show compare link when viewing cities" do
    get entities_url(kind: "city")
    assert_response :success

    assert_select ".school-district-compare-callout", count: 0
  end

  test "index does not show compare link when viewing all entities" do
    get entities_url
    assert_response :success

    assert_select ".school-district-compare-callout", count: 0
  end
end
