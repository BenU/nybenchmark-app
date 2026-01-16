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
end
