# frozen_string_literal: true

require "test_helper"

class ObservationTest < ActiveSupport::TestCase
  # --- 1. Happy Paths (The Valid States) ---

  test "valid with ONLY numeric value" do
    obs = observations(:yonkers_expenditures_numeric)
    assert obs.valid?
    assert_not_nil obs.value_numeric
    assert_nil obs.value_text
  end

  test "valid with ONLY text value" do
    obs = observations(:new_rochelle_bond_rating_text)
    assert obs.valid?
    assert_nil obs.value_numeric
    assert_not_nil obs.value_text
  end

  # --- 2. The "Inclusive OR" Failure (Both) ---

  test "invalid if BOTH values are present" do
    obs = observations(:yonkers_expenditures_numeric)
    obs.value_text = "Now I have text too"
    assert_not obs.valid?
    assert_includes obs.errors[:base], "Cannot have both a numeric and text value"
  end

  # --- 3. The "Neither" Failure (Ghost Record) ---

  test "invalid if NEITHER value is present" do
    obs = observations(:yonkers_expenditures_numeric)
    obs.value_numeric = nil
    obs.value_text = nil
    assert_not obs.valid?
    assert_includes obs.errors[:base], "Must have either a numeric value or a text value"
  end

  # --- 4. Zero Handling (Edge Case) ---

  test "valid with numeric zero" do
    obs = observations(:yonkers_expenditures_numeric)
    obs.value_numeric = 0.0
    obs.value_text = nil
    assert obs.valid?
  end

  # --- 5. Data Integrity Checks ---

  test "fixtures should be valid" do
    assert observations(:yonkers_expenditures_numeric).valid?
    assert observations(:new_rochelle_bond_rating_text).valid?
  end

  # REPLACED TEST: Now checking for Auto-Correction instead of Invalidity
  test "should auto-correct fiscal_year to match document before validation" do
    obs = observations(:yonkers_expenditures_numeric)
    correct_year = obs.document.fiscal_year
    wrong_year = correct_year - 1

    # 1. Set incorrect year
    obs.fiscal_year = wrong_year

    # 2. Trigger validation (which triggers the before_validation callback)
    assert obs.valid? # Should be valid now because it auto-fixed itself!

    # 3. Assert the correction happened
    assert_equal correct_year, obs.fiscal_year
    assert_not_equal wrong_year, obs.fiscal_year
  end

  # --- 6. Verification Cockpit Logic (NEW) ---

  test "defaults to provisional status" do
    obs = Observation.new
    assert obs.provisional?
    assert_equal "provisional", obs.verification_status
  end

  test "pdf_page must be a positive integer" do
    obs = observations(:yonkers_expenditures_numeric)

    obs.pdf_page = 0
    assert_not obs.valid?

    obs.pdf_page = -1
    assert_not obs.valid?

    obs.pdf_page = 1.5
    assert_not obs.valid?

    obs.pdf_page = 42
    assert obs.valid?
  end

  test "queue logic cycles through provisional items" do
    # 1. Get the actual provisional items from DB, sorted by ID
    # We use this instead of hardcoding fixtures because Fixture IDs are random.
    queue = Observation.provisional.order(:id).to_a

    assert_equal 3, queue.size, "Fixtures should have exactly 3 provisional items"

    first_item = queue[0]
    second_item = queue[1]
    third_item = queue[2]

    # 2. Verify the chain: first -> second -> third -> first (wrap)
    assert_equal second_item, first_item.next_provisional_observation
    assert_equal third_item, second_item.next_provisional_observation

    # Calling 'next' on the last should wrap around to the first
    assert_equal first_item, third_item.next_provisional_observation

    # 3. Verify skipping
    # Calling 'next' on a VERIFIED item should jump into the provisional queue
    verified_obs = observations(:yonkers_expenditures_numeric)
    next_from_verified = verified_obs.next_provisional_observation

    assert next_from_verified.provisional?
    # It must be ONE of the items in our queue (depending on where the ID lands)
    assert_includes queue, next_from_verified
  end

  # --- 7. Value Type Matches Metric Validation ---

  test "valid when numeric metric has numeric value" do
    obs = observations(:yonkers_expenditures_numeric)
    # Fixture uses :expenditures metric which is numeric (value_type: numeric)
    assert obs.metric.expects_numeric?
    assert_not_nil obs.value_numeric
    assert_nil obs.value_text
    assert obs.valid?
  end

  test "valid when text metric has text value" do
    obs = observations(:new_rochelle_bond_rating_text)
    # Fixture uses :bond_rating metric which is text (value_type: text)
    assert obs.metric.expects_text?
    assert_nil obs.value_numeric
    assert_not_nil obs.value_text
    assert obs.valid?
  end

  test "invalid when numeric metric has only text value" do
    obs = observations(:yonkers_expenditures_numeric)
    assert obs.metric.expects_numeric?

    obs.value_numeric = nil
    obs.value_text = "Some text instead"

    assert_not obs.valid?
    assert_includes obs.errors[:value_numeric], "is required for this metric"
  end

  test "invalid when text metric has only numeric value" do
    obs = observations(:new_rochelle_bond_rating_text)
    assert obs.metric.expects_text?

    obs.value_numeric = 12_345.00
    obs.value_text = nil

    assert_not obs.valid?
    assert_includes obs.errors[:value_text], "is required for this metric"
  end

  test "valid when numeric metric has value of zero" do
    obs = observations(:yonkers_expenditures_numeric)
    assert obs.metric.expects_numeric?

    obs.value_numeric = 0
    obs.value_text = nil

    assert obs.valid?, "Zero should be a valid numeric value"
  end

  test "valid when numeric metric has negative value" do
    obs = observations(:yonkers_expenditures_numeric)
    assert obs.metric.expects_numeric?

    obs.value_numeric = -1000.50
    obs.value_text = nil

    assert obs.valid?, "Negative numbers should be valid numeric values"
  end
end
