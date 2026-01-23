# frozen_string_literal: true

require "application_system_test_case"

class EntitiesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one) # Assumes 'one' is approved in fixtures
    sign_in @user
  end

  test "visiting the index" do
    visit entities_url
    assert_selector "h1", text: "Entities"
  end

  test "creating a City" do
    visit entities_url
    click_on "New Entity"

    fill_in "Name", with: "Test City"
    fill_in "Slug", with: "test-city"
    select "City", from: "Kind"
    select "NY", from: "State"

    # Specific Governance fields for a City
    select "Strong Mayor", from: "Government structure"
    select "Independent", from: "Fiscal autonomy"

    click_on "Create Entity"

    assert_text "Entity was successfully created"
    assert_text "Test City"
    assert_text "Strong mayor"
  end

  test "creating a School District with validation logic" do
    visit entities_url
    click_on "New Entity"

    fill_in "Name", with: "Test Schools"
    fill_in "Slug", with: "test-schools"
    select "School District", from: "Kind"

    # Intentionally leave School Legal Type blank first to test validation
    click_on "Create Entity"
    assert_text "School legal type can't be blank"

    # Fix the error
    select "Big Five", from: "School legal type"
    select "Dependent", from: "Fiscal autonomy"
    select "Appointed", from: "Board selection"

    click_on "Create Entity"

    assert_text "Entity was successfully created"
    assert_text "Test Schools"
    assert_text "Big five"
  end

  test "updating an Entity" do
    entity = entities(:yonkers)
    visit entity_url(entity)
    click_on "Edit", match: :first

    fill_in "Name", with: "Yonkers Updated"
    click_on "Update Entity"

    assert_text "Entity was successfully updated"
    assert_text "Yonkers Updated"
  end

  # ==========================================
  # DATA COMPLETENESS INDICATORS
  # ==========================================

  test "entity index shows Needs research for missing government structure" do
    visit entities_url

    # Albany fixture has no government_structure - it's the only "Albany" row
    albany_row = find("tr") { |row| row.text.include?("Albany") && row.text.include?("City") }
    within(albany_row) do
      assert_text "Needs research"
    end

    # Yonkers (city) fixture has government_structure set
    yonkers_row = find("tr") { |row| row.text.include?("Yonkers") && row.text.include?("City") }
    within(yonkers_row) do
      assert_text "Strong mayor"
      assert_no_text "Needs research"
    end
  end

  test "entity index shows document and observation counts" do
    visit entities_url

    # Table should have Docs and Obs columns
    assert_selector "th", text: "Docs"
    assert_selector "th", text: "Obs"

    # Yonkers (city) has documents and observations (from fixtures)
    yonkers_row = find("tr") { |row| row.text.include?("Yonkers") && row.text.include?("City") }
    within(yonkers_row) do
      # Should show counts (not just muted 0)
      assert_selector "td", text: /\d+/
    end
  end

  test "entity index shows Gov. Structure column" do
    visit entities_url

    assert_selector "th", text: "Gov. Structure"
  end

  test "entity show displays banner when government structure is missing" do
    albany = entities(:albany)
    visit entity_url(albany)

    # Should show the "Help wanted" banner
    assert_text "Help wanted"
    assert_text "Government structure information is missing"
    assert_link "Add governance details"
  end

  test "entity show does not display banner when government structure is present" do
    yonkers = entities(:yonkers)
    visit entity_url(yonkers)

    # Should NOT show the "Help wanted" banner
    assert_no_text "Help wanted"
    assert_no_text "Government structure information is missing"
  end

  test "entity show displays Not specified for missing governance fields" do
    albany = entities(:albany)
    visit entity_url(albany)

    # All governance fields should show, with "Not specified" for empty ones
    assert_text "Structure"
    assert_text "Fiscal Autonomy"
    assert_text "ICMA Recognition"
    assert_text "Notes"

    # Albany has no government_structure or fiscal_autonomy
    assert_text "Not specified"
    assert_link "Add details"
  end

  test "entity show displays humanized government structure when present" do
    yonkers = entities(:yonkers)
    visit entity_url(yonkers)

    assert_text "Strong mayor"
    assert_text "Independent" # fiscal_autonomy
  end

  # ==========================================
  # ORGANIZATION NOTE AND ICMA RECOGNITION
  # ==========================================

  test "entity form includes organization_note textarea" do
    visit entities_url
    click_on "New Entity"

    assert_selector "textarea[name='entity[organization_note]']"
    assert_selector "label", text: "Organization note"
  end

  test "entity form includes icma_recognition_year field" do
    visit entities_url
    click_on "New Entity"

    assert_selector "input[name='entity[icma_recognition_year]']"
    assert_selector "label", text: "ICMA Recognition Year"
  end

  test "creating an entity with organization_note and icma_recognition_year" do
    visit entities_url
    click_on "New Entity"

    fill_in "Name", with: "Test ICMA City"
    fill_in "Slug", with: "test-icma-city"
    select "City", from: "Kind"
    select "NY", from: "State"
    select "Council Manager", from: "Government structure"
    fill_in "ICMA Recognition Year", with: "1950"
    fill_in "Organization note", with: "Council-manager form since 1950"

    click_on "Create Entity"

    assert_text "Entity was successfully created"
    assert_text "Test ICMA City"
  end

  test "entity show displays organization_note when present" do
    yonkers = entities(:yonkers)
    visit entity_url(yonkers)

    # Yonkers fixture has organization_note: "Council President + 6 District Representatives"
    assert_text "Notes"
    assert_text "Council President + 6 District Representatives"
  end

  test "entity show displays icma_recognition_year when present" do
    # Update New Rochelle to have ICMA recognition year
    nr = entities(:new_rochelle)
    nr.update!(icma_recognition_year: 1932)

    visit entity_url(nr)

    assert_text "ICMA Recognition"
    assert_text "1932"
  end

  # ==========================================
  # PARENT ENTITY SELECTOR (Fiscal Dependency)
  # ==========================================
  # Note: parent_id represents fiscal/reporting roll-up only, not geographic containment.
  # Examples: Big Five school districts are fiscally dependent on their city.
  # Villages are geographically within towns but fiscally independent.

  test "entity form hides parent selector when fiscal_autonomy is independent" do
    visit new_entity_url

    select "Independent", from: "Fiscal autonomy"

    # Parent selector should be hidden
    assert_no_selector "select[name='entity[parent_id]']", visible: true
  end

  test "entity form shows parent selector when fiscal_autonomy is dependent" do
    visit new_entity_url

    select "Dependent", from: "Fiscal autonomy"

    # Parent selector should be visible
    assert_selector "select[name='entity[parent_id]']", visible: true
    assert_selector "label", text: "Parent entity"
  end

  test "parent selector lists cities, counties, towns, and villages but not school districts" do
    # Create a town and village for testing
    Entity.create!(name: "Test Town", kind: "town", state: "NY", slug: "test-town")
    Entity.create!(name: "Test Village", kind: "village", state: "NY", slug: "test-village")

    visit new_entity_url

    select "Dependent", from: "Fiscal autonomy"

    # Should include cities, counties, towns, villages with their type shown
    within "select[name='entity[parent_id]']" do
      assert_selector "option", text: "Yonkers (City)"
      assert_selector "option", text: "New Rochelle (City)"
      assert_selector "option", text: "Test Town (Town)"
      assert_selector "option", text: "Test Village (Village)"
      # Should NOT include school districts (never fiscal parents)
      assert_no_selector "option", text: "Yonkers Public Schools"
      assert_no_selector "option", text: "New Rochelle City School District"
    end
  end

  test "creating a dependent school district with parent city" do
    visit new_entity_url

    fill_in "Name", with: "Test Dependent District"
    fill_in "Slug", with: "test-dependent-district"
    select "School District", from: "Kind"
    select "Dependent", from: "Fiscal autonomy"
    select "Big Five", from: "School legal type"
    select "Yonkers (City)", from: "Parent entity"

    click_on "Create Entity"

    assert_text "Entity was successfully created"

    # Verify the parent was saved
    entity = Entity.find_by(name: "Test Dependent District")
    assert_equal entities(:yonkers), entity.parent
  end

  test "entity show displays parent entity when present" do
    # Yonkers Schools is fiscally dependent on Yonkers
    yonkers_schools = entities(:yonkers_schools)
    visit entity_url(yonkers_schools)

    assert_text "Parent Entity"
    assert_text "Yonkers"
  end

  # ==========================================
  # NAVIGATION AND RELATED ENTITY DISPLAY
  # ==========================================

  test "entity show page has back link to index" do
    visit entity_url(entities(:yonkers))

    assert_link "Back to Entities"
    click_on "Back to Entities"
    assert_current_path entities_path
  end

  test "entity show displays children entities for parent" do
    # Yonkers is parent of Yonkers Schools
    yonkers = entities(:yonkers)
    visit entity_url(yonkers)

    assert_text "Dependent Entities"
    assert_link "Yonkers Public Schools"
  end

  test "entity index shows fiscal autonomy column" do
    visit entities_url

    assert_selector "th", text: "Fiscal"
    # Yonkers is independent
    yonkers_row = find("tr") { |row| row.text.include?("Yonkers") && row.text.include?("City") }
    within(yonkers_row) do
      assert_text "Independent"
    end
  end

  # ==========================================
  # CONDITIONAL SCHOOL DISTRICT FIELDS
  # ==========================================

  test "entity form hides school fields when kind is not school district" do
    visit new_entity_url

    select "City", from: "Kind"

    # School fields should be hidden
    assert_no_selector "select[name='entity[school_legal_type]']", visible: true
  end

  test "entity form shows school fields when kind is school district" do
    visit new_entity_url

    select "School District", from: "Kind"

    # School fields should be visible
    assert_selector "select[name='entity[school_legal_type]']", visible: true
    assert_selector "select[name='entity[board_selection]']", visible: true
    assert_selector "select[name='entity[executive_selection]']", visible: true
  end

  # ==========================================
  # SORTABLE COLUMNS AND PAGINATION
  # ==========================================

  test "entity index has sortable column headers" do
    visit entities_url

    # Should have sortable headers for Name, Type, Docs, Obs
    assert_selector "a.sortable-header", text: "Name"
    assert_selector "a.sortable-header", text: "Type"
    assert_selector "a.sortable-header", text: "Docs"
    assert_selector "a.sortable-header", text: "Obs"
  end

  test "clicking sortable column header sorts table" do
    visit entities_url

    # Click on Name header to sort (should be ascending by default)
    click_on "Name"

    # Should have sort params in URL
    assert_current_path(/sort=name/)
    assert_current_path(/direction=asc/)

    # Should show sort indicator (up arrow) and active class
    assert_selector "a.sortable-header.active", text: /Name.*↑/
  end

  test "clicking same column header toggles sort direction" do
    visit entities_url(sort: "name", direction: "asc")

    # Click Name again to toggle to desc
    click_on "Name"

    assert_current_path(/direction=desc/)
    assert_selector "a.sortable-header.active", text: /Name.*↓/
  end

  test "entity index shows pagination when many entities exist" do
    # Create enough entities to trigger pagination (25 per page)
    30.times do |i|
      Entity.create!(name: "Paginated Entity #{i}", kind: "city", state: "NY", slug: "paginated-#{i}")
    end

    visit entities_url

    # Should show pagination controls
    assert_selector "nav[aria-label='Entity pages']"
  end

  test "pagination preserves sort params" do
    # Create enough entities for multiple pages
    30.times do |i|
      Entity.create!(name: "Paginated Entity #{i}", kind: "city", state: "NY", slug: "paginated-#{i}")
    end

    visit entities_url(sort: "name", direction: "desc")

    # Click page 2 within the pagination nav
    within "nav[aria-label='Entity pages']" do
      click_on "2"
    end

    # Should preserve sort params
    assert_current_path(/sort=name/)
    assert_current_path(/direction=desc/)
  end

  test "entity index has sortable government structure column" do
    visit entities_url

    # Should have sortable header for Gov. Structure
    assert_selector "a.sortable-header", text: "Gov. Structure"
  end

  test "clicking government structure header sorts entities" do
    visit entities_url

    # Click on Gov. Structure header to sort
    click_on "Gov. Structure"

    # Should have sort params in URL
    assert_current_path(/sort=government_structure/)
    assert_current_path(/direction=asc/)

    # Should show sort indicator
    assert_selector "a.sortable-header.active", text: /Gov. Structure.*↑/
  end
end
