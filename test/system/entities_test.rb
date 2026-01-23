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
end
