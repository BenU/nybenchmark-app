# frozen_string_literal: true

require "application_system_test_case"

class ObservationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one) # Assumes Devise fixtures exist
    sign_in @user

    @entity = entities(:yonkers)
    @document = documents(:yonkers_acfr_fy2024)
    @metric = metrics(:expenditures)

    # We need a document from a DIFFERENT entity to verify filtering works
    @other_document = documents(:new_rochelle_acfr_fy2024)
  end

  test "creating a new observation with dynamic document filtering" do
    visit new_observation_path

    # 1. Select Entity - triggers Stimulus refresh
    select @entity.name, from: "Entity"

    # 2. Verify Filtering (Wait for Turbo to update the DOM)
    # The target document should appear
    assert_selector "#observation_document_id option", text: @document.title
    # The non-matching document should NOT appear
    assert_no_selector "#observation_document_id option", text: @other_document.title

    # 3. Fill remaining dependencies
    select @document.title, from: "Document"
    select @metric.label, from: "Metric"

    # 4. Fill Value (Numeric)
    fill_in "Numeric Value", with: "500000.00"
    fill_in "Page reference", with: "p. 42"

    click_on "Create Observation"

    assert_text "Observation was successfully created"

    # 5. Verify Logic (Fiscal Year auto-assignment)
    obs = Observation.last
    assert_equal 2024, obs.fiscal_year
    assert_equal 500_000.0, obs.value_numeric
    assert_equal @document, obs.document
  end

  test "validating exclusive value logic" do
    # Pre-select entity via param to skip the refresh step for this test
    visit new_observation_path(entity_id: @entity.id)

    select @document.title, from: "Document"
    select @metric.label, from: "Metric"
    fill_in "Page reference", with: "p. 10"

    # Fill BOTH values to trigger validation error
    fill_in "Numeric Value", with: "100"
    fill_in "Text Value", with: "Pending Audit"

    click_on "Create Observation"

    assert_text "Cannot have both a numeric and text value"
  end
end
