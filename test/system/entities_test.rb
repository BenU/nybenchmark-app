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

  test "entity show displays needs research message in governance section when empty" do
    albany = entities(:albany)
    visit entity_url(albany)

    assert_text "Governance structure needs research"
    assert_link "Add details"
  end

  test "entity show displays humanized government structure when present" do
    yonkers = entities(:yonkers)
    visit entity_url(yonkers)

    assert_text "Strong mayor"
    assert_no_text "Governance structure needs research"
  end
end
