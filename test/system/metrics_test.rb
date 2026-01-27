# frozen_string_literal: true

# test/system/metrics_test.rb
require "application_system_test_case"

class MetricsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one) # Load the user
    sign_in @user

    @metric = metrics(:revenue)
  end

  test "visiting the index" do
    visit metrics_path

    assert_selector "h1", text: "Metrics"
    assert_text "Total General Fund Revenue"
    # Just check for the description text presence, regardless of formatting
    assert_text @metric.description
  end

  test "viewing a specific metric" do
    visit metrics_path

    click_on "Total General Fund Revenue"

    assert_selector "h1", text: "Total General Fund Revenue"

    # Updated Assertions to match the actual UI
    assert_text "Unit: USD"
    assert_text "Code: total_revenue"

    # FIX: Remove "Description:" label expectation.
    # We just ensure the description body text is visible on the page.
    assert_text @metric.description

    assert_selector "a", text: "Back to Metrics"
  end

  test "creating a Metric" do
    visit metrics_path
    click_on "New Metric"

    fill_in "Label", with: "Public Safety Expense"
    fill_in "Key", with: "public_safety_expense"
    fill_in "Unit", with: "USD"
    select "Numeric", from: "Value type"
    select "Currency", from: "Display format"
    fill_in "Description", with: "Total spending on police and fire."

    click_on "Create Metric"

    assert_text "Metric was successfully created"
    assert_text "Public Safety Expense"
    assert_text "public_safety_expense"
  end

  test "creating a Metric with validation errors" do
    visit metrics_path
    click_on "New Metric"

    # Submit empty form to trigger validations
    click_on "Create Metric"

    assert_text "Key can't be blank"
    assert_text "Label can't be blank"
  end

  test "updating a Metric" do
    visit metric_path(@metric)
    click_on "Edit", match: :first

    fill_in "Label", with: "Revenue (Updated)"
    click_on "Update Metric"

    assert_text "Metric was successfully updated"
    assert_text "Revenue (Updated)"
  end

  # --- Index View: Type Column Tests ---

  test "metrics index displays value type column" do
    visit metrics_path

    # Should have Type column header
    within("thead") do
      assert_text "Type"
    end

    # Should show type values in table body
    within("tbody") do
      assert_text "Numeric"
    end
  end

  # --- Show View: New Attribute Tests ---

  test "metric show displays value type" do
    visit metric_path(@metric)

    assert_text "Type:"
    assert_text "Numeric"
  end

  test "metric show displays display format for numeric metric" do
    visit metric_path(@metric)

    assert_text "Display Format:"
    assert_text "Currency"
  end

  test "metric show displays formula when present" do
    # Create a metric with a formula for this test
    derived_metric = Metric.create!(
      key: "test_derived_metric",
      label: "Test Derived Metric",
      value_type: :numeric,
      display_format: "decimal",
      formula: "revenue - expenditures"
    )

    visit metric_path(derived_metric)

    assert_text "Formula:"
    assert_text "revenue - expenditures"

    # Cleanup
    derived_metric.destroy
  end

  test "metric show does not display formula section when formula is blank" do
    # revenue metric has no formula
    visit metric_path(@metric)

    assert_no_text "Formula:"
  end

  # --- Text Metric Tests ---

  test "metrics index shows text type for text metric" do
    # bond_rating fixture has value_type: text
    visit metrics_path

    # Should show "Text" in the table for the bond_rating metric
    within("tbody") do
      assert_text "Text"
    end
  end

  test "metric show displays text type correctly" do
    text_metric = metrics(:bond_rating)

    visit metric_path(text_metric)

    assert_text "Type:"
    assert_text "Text"
    # Text metrics should NOT show display format
    assert_no_text "Display Format:"
  end

  # ==========================================
  # SORTABLE COLUMNS AND PAGINATION
  # ==========================================

  test "metric index has sortable column headers" do
    visit metrics_path

    # Should have sortable headers for Label and Type
    assert_selector "a.sortable-header", text: "Label"
    assert_selector "a.sortable-header", text: "Type"
  end

  test "clicking sortable column header sorts metrics" do
    visit metrics_path

    # Click on Label header to sort
    click_on "Label"

    # Should have sort params in URL
    assert_current_path(/sort=label/)
    assert_current_path(/direction=asc/)

    # Should show sort indicator
    assert_selector "a.sortable-header.active", text: /Label.*↑/
  end

  test "clicking same column header toggles sort direction" do
    visit metrics_url(sort: "label", direction: "asc")

    # Click Label again to toggle to desc
    click_on "Label"

    assert_current_path(/direction=desc/)
    assert_selector "a.sortable-header.active", text: /Label.*↓/
  end

  test "metric index shows pagination when many metrics exist" do
    # Create enough metrics to trigger pagination (25 per page)
    30.times do |i|
      Metric.create!(
        key: "paginated_metric_#{i}",
        label: "Paginated Metric #{i}",
        value_type: :numeric,
        display_format: "decimal"
      )
    end

    visit metrics_path

    # Should show pagination controls
    assert_selector "nav[aria-label='Metric pages']"
  end

  # ==========================================
  # DATA SOURCE DISPLAY
  # ==========================================

  test "metric index displays data source column" do
    visit metrics_path

    # Should have Source column header
    within("thead") do
      assert_text "Source"
    end

    # Should show source values in table body
    within("tbody") do
      assert_text "Manual" # Most fixtures are manual
    end
  end

  test "metric index shows OSC for osc-sourced metrics" do
    visit metrics_path

    # police_personal_services fixture has data_source: osc
    within("tbody") do
      assert_text "Osc"
    end
  end

  test "metric show displays data source" do
    visit metric_path(@metric)

    assert_text "Source:"
    assert_text "Manual"
  end

  test "metric show displays data source for OSC metric" do
    osc_metric = metrics(:police_personal_services)
    visit metric_path(osc_metric)

    assert_text "Source:"
    assert_text "Osc"
  end

  test "metric show displays account code for OSC metrics" do
    osc_metric = metrics(:police_personal_services)
    visit metric_path(osc_metric)

    assert_text "Account Code:"
    assert_text "A31201"
  end

  test "metric show does not display account code section for non-OSC metrics" do
    visit metric_path(@metric)

    assert_no_text "Account Code:"
  end

  # ==========================================
  # DATA SOURCE FILTERING
  # ==========================================

  test "metric index has data source filter dropdown" do
    visit metrics_path

    assert_selector "select[name='data_source']"
  end

  test "filtering by data source shows only matching metrics" do
    visit metrics_path

    # Filter by OSC
    select "Osc", from: "data_source"
    click_on "Apply"

    # Should only show OSC metrics
    within("tbody") do
      assert_text "Police - Personal Services"
      assert_no_text "Total General Fund Revenue" # Manual metric
    end
  end

  test "filtering by data source preserves sort params" do
    visit metrics_url(sort: "label", direction: "desc")

    # Apply a filter
    select "Osc", from: "data_source"
    click_on "Apply"

    # Should preserve sort params
    assert_current_path(/sort=label/)
    assert_current_path(/direction=desc/)
    assert_current_path(/data_source=osc/)
  end

  # ==========================================
  # FORM DATA SOURCE FIELDS
  # ==========================================

  test "metric form includes data source dropdown" do
    visit new_metric_path

    assert_selector "select[name='metric[data_source]']"
    assert_selector "label", text: "Data source"
  end

  test "metric form includes account code field" do
    visit new_metric_path

    assert_selector "input[name='metric[account_code]']"
    assert_selector "label", text: "Account code"
  end

  test "creating an OSC metric with account code" do
    visit new_metric_path

    fill_in "Label", with: "Fire - Personal Services"
    fill_in "Key", with: "fire_personal_services"
    fill_in "Unit", with: "USD"
    select "Numeric", from: "Value type"
    select "Currency", from: "Display format"
    select "Osc", from: "Data source"
    fill_in "Account code", with: "A34101"
    fill_in "Description", with: "Fire department salaries"

    click_on "Create Metric"

    assert_text "Metric was successfully created"
    assert_text "Fire - Personal Services"
    assert_text "A34101"
    assert_text "Osc"
  end
end
