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
    assert_text "strong_mayor"
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
    assert_text "big_five"
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
end
