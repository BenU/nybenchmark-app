# frozen_string_literal: true

require "test_helper"

class ObservationTest < ActiveSupport::TestCase
  # --- 1. Happy Paths (The Valid States) ---

  test "valid with ONLY numeric value" do
    obs = observations(:yonkers_expenditures_numeric) # Fixture 'yonkers_expenditures_numeric' is numeric-only
    assert obs.valid?
    assert_not_nil obs.value_numeric
    assert_nil obs.value_text
  end

  test "valid with ONLY text value" do
    obs = observations(:new_rochelle_revenue_text) # Fixture 'new_rochelle_revenue_text' is text-only
    assert obs.valid?
    assert_nil obs.value_numeric
    assert_not_nil obs.value_text
  end

  # --- 2. The "Inclusive OR" Failure (Both) ---

  test "invalid if BOTH values are present" do
    obs = observations(:yonkers_expenditures_numeric) # Starts numeric
    obs.value_text = "Now I have text too" # Add text

    assert_not obs.valid?
    assert_includes obs.errors[:base], "Cannot have both a numeric and text value"
  end

  # --- 3. The "Neither" Failure (Ghost Record) ---

  test "invalid if NEITHER value is present" do
    obs = observations(:yonkers_expenditures_numeric) # Starts numeric
    obs.value_numeric = nil  # Remove numeric
    obs.value_text = nil     # Ensure text is nil

    assert_not obs.valid?
    assert_includes obs.errors[:base], "Must have either a numeric value or a text value"
  end

  # --- 4. Zero Handling (Edge Case) ---

  test "valid with numeric zero" do
    # Zero is a valid number, not "nil"
    obs = observations(:yonkers_expenditures_numeric)
    obs.value_numeric = 0.0
    obs.value_text = nil

    assert obs.valid?, "Zero should be considered a valid numeric value"
  end

  # --- 5. Data Integrity Checks ---

  test "fixtures should be valid" do
    assert observations(:yonkers_expenditures_numeric).valid?
    assert observations(:new_rochelle_revenue_text).valid?
    assert observations(:yonkers_schools_metric_one).valid?
    assert observations(:new_rochelle_schools_text_two).valid?
  end

  test "should be invalid if fiscal_year does not match document year" do
    obs = observations(:yonkers_expenditures_numeric)
    obs.fiscal_year = obs.document.fiscal_year - 1
    assert_not obs.valid?
    assert_match(/must match the document's fiscal year/, obs.errors[:fiscal_year].join)
  end
end
