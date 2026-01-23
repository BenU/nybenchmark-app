# frozen_string_literal: true

require "application_system_test_case"

class ObservationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one) # Assumes Devise fixtures exist
    sign_in @user

    @observation = observations(:yonkers_expenditures_numeric)

    @entity = entities(:yonkers)
    @document = documents(:yonkers_acfr_fy2024)
    @metric = metrics(:expenditures)

    # We need a document from a DIFFERENT entity to verify filtering works
    @other_document = documents(:new_rochelle_acfr_fy2024)
  end

  test "navigation: creating a new observation from index" do
    visit observations_path

    # 1. Assert Link Exists and Click
    assert_link "New observation"
    click_on "New observation"

    # 2. Verify Destination (uses cockpit layout with h2)
    assert_selector "h2", text: "New Observation"
    assert_current_path new_observation_path
  end

  test "navigation: editing an observation from show page" do
    visit observation_path(@observation)

    # 1. Assert Link Exists and Click
    assert_link "Edit"
    click_on "Edit"

    # 2. Verify Destination (uses cockpit layout with h2)
    assert_selector "h2", text: "Edit Observation"
    assert_current_path edit_observation_path(@observation)
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
    fill_in "Citation (printed page)", with: "p. 42"

    click_on "Create Observation"

    assert_text "Observation created. Please verify details."

    # 5. Verify Logic (Fiscal Year auto-assignment)
    obs = Observation.last
    assert_equal 2024, obs.fiscal_year
    assert_equal 500_000.0, obs.value_numeric
    assert_equal @document, obs.document
  end

  test "creating observation with correct value type for metric" do
    # Pre-select entity via param to skip the refresh step for this test
    visit new_observation_path(entity_id: @entity.id)

    select @document.title, from: "Document"
    select @metric.label, from: "Metric" # @metric is numeric (expenditures)

    # With metric selected, only numeric field should be visible
    assert_selector "input[type='number'][name='observation[value_numeric]']", visible: true
    assert_no_selector "input[name='observation[value_text]']", visible: true

    fill_in "Numeric Value", with: "100"
    fill_in "Citation (printed page)", with: "p. 10"

    click_on "Create Observation"

    assert_text "Observation created"
  end

  # --- Verify Cockpit: Conditional Input Field Tests ---

  test "verify cockpit shows only numeric input for numeric metric" do
    # Use an observation with a numeric metric
    numeric_obs = observations(:yonkers_expenditures_numeric)
    assert numeric_obs.metric.expects_numeric?, "Fixture metric should expect numeric"

    visit verify_observation_path(numeric_obs)

    # Should see numeric input field
    assert_selector "input[type='number'][name='observation[value_numeric]']"

    # Should NOT see text input field
    assert_no_selector "input[name='observation[value_text]']"
    assert_no_selector "textarea[name='observation[value_text]']"
  end

  test "verify cockpit shows only text input for text metric" do
    # Use an observation with a text metric (bond_rating fixture has value_type: text)
    text_obs = observations(:new_rochelle_bond_rating_text)
    assert text_obs.metric.expects_text?, "Fixture metric should expect text"

    visit verify_observation_path(text_obs)

    # Should see text input field
    assert_selector "input[name='observation[value_text]']"

    # Should NOT see numeric input field
    assert_no_selector "input[type='number'][name='observation[value_numeric]']"
  end

  test "verify cockpit displays formatted value preview for numeric metric" do
    # expenditures fixture has display_format: currency
    numeric_obs = observations(:yonkers_expenditures_numeric)
    assert_equal "currency", numeric_obs.metric.display_format

    visit verify_observation_path(numeric_obs)

    # Should show a formatted preview of the current value
    # The exact format depends on implementation, but we check for currency formatting
    assert_selector "[data-formatted-preview]", text: "$"
  end

  # --- Index View: Formatted Value Tests ---

  test "observations index displays formatted currency value" do
    # yonkers_expenditures_numeric has value_numeric and metric with display_format: currency
    visit observations_path

    # Should show currency-formatted value with $ sign and commas
    within("tbody") do
      assert_text "$"
    end
  end

  test "observations index displays text value for text metric" do
    # new_rochelle_bond_rating_text has value_text
    obs = observations(:new_rochelle_bond_rating_text)

    visit observations_path

    # Should display the text value (e.g., "Aa2")
    within("tbody") do
      assert_text obs.value_text
    end
  end

  # --- Show View: Formatted Value Tests ---

  test "observation show displays formatted currency value" do
    obs = observations(:yonkers_expenditures_numeric)
    formatted_value = obs.metric.format_value(obs.value_numeric)

    visit observation_path(obs)

    # Should show the formatted value with $ and commas
    assert_text formatted_value
  end

  test "observation show displays text value for text metric" do
    obs = observations(:new_rochelle_bond_rating_text)

    visit observation_path(obs)

    # Should display the text value
    assert_text obs.value_text
  end

  # --- Form: Conditional Value Field Tests ---

  test "observation edit form shows only numeric field for numeric metric" do
    obs = observations(:yonkers_expenditures_numeric)
    assert obs.metric.expects_numeric?

    visit edit_observation_path(obs)

    # Should have numeric input
    assert_selector "input[type='number'][name='observation[value_numeric]']"
    # Should NOT have text input
    assert_no_selector "input[name='observation[value_text]']"
  end

  test "observation edit form shows only text field for text metric" do
    obs = observations(:new_rochelle_bond_rating_text)
    assert obs.metric.expects_text?

    visit edit_observation_path(obs)

    # Should have text input
    assert_selector "input[name='observation[value_text]']"
    # Should NOT have numeric input
    assert_no_selector "input[type='number'][name='observation[value_numeric]']"
  end

  # --- New Observation Form: Dynamic Value Field Tests ---

  test "new observation form shows no value field until metric is selected" do
    visit new_observation_path(entity_id: @entity.id)

    # Initially, neither value field should be visible (or both should be hidden)
    # Check for the value section - it should show a message to select metric
    assert_text "Select a metric to see value field"
  end

  test "new observation form shows numeric field when numeric metric is selected" do
    visit new_observation_path(entity_id: @entity.id)

    # Select a numeric metric (expenditures is numeric with display_format: currency)
    select @metric.label, from: "Metric"

    # Should show numeric input
    assert_selector "input[type='number'][name='observation[value_numeric]']", visible: true
    # Should NOT show text input
    assert_no_selector "input[name='observation[value_text]']", visible: true
  end

  test "new observation form shows text field when text metric is selected" do
    text_metric = metrics(:bond_rating)

    visit new_observation_path(entity_id: @entity.id)

    # Select a text metric
    select text_metric.label, from: "Metric"

    # Should show text input
    assert_selector "input[name='observation[value_text]']", visible: true
    # Should NOT show numeric input
    assert_no_selector "input[type='number'][name='observation[value_numeric]']", visible: true
  end

  test "new observation form switches value field when changing metric type" do
    text_metric = metrics(:bond_rating)

    visit new_observation_path(entity_id: @entity.id)

    # First select numeric metric
    select @metric.label, from: "Metric"
    assert_selector "input[type='number'][name='observation[value_numeric]']", visible: true

    # Then switch to text metric
    select text_metric.label, from: "Metric"
    assert_selector "input[name='observation[value_text]']", visible: true
    assert_no_selector "input[type='number'][name='observation[value_numeric]']", visible: true
  end

  # ==========================================
  # SORTABLE COLUMN HEADERS
  # ==========================================

  test "observation index has sortable column headers" do
    visit observations_path

    # Should have sortable headers for Entity, Metric, Value, Year
    assert_selector "a.sortable-header", text: "Entity"
    assert_selector "a.sortable-header", text: "Metric"
    assert_selector "a.sortable-header", text: "Year"
  end

  test "clicking sortable column header sorts observations" do
    visit observations_path

    # Click on Entity header to sort
    click_on "Entity"

    # Should have sort params in URL
    assert_current_path(/sort=entity_name/)
    assert_current_path(/direction=asc/)

    # Should show sort indicator
    assert_selector "a.sortable-header.active", text: /Entity.*↑/
  end

  test "clicking same column header toggles sort direction" do
    visit observations_url(sort: "fiscal_year", direction: "desc")

    # Click Year again to toggle to asc
    click_on "Year"

    assert_current_path(/direction=asc/)
    assert_selector "a.sortable-header.active", text: /Year.*↑/
  end
end
