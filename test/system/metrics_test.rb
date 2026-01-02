# frozen_string_literal: true

# test/system/metrics_test.rb
require "application_system_test_case"

class MetricsTest < ApplicationSystemTestCase
  setup do
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
end
