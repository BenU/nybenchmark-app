# frozen_string_literal: true

require "test_helper"

class ObservationTest < ActiveSupport::TestCase
  test "valid with numeric value" do
    obs = observations(:nyc_expenditures)
    assert obs.valid?
  end

  test "valid with text value" do
    obs = observations(:albany_revenue_text)
    assert obs.valid?
  end

  test "invalid without any value" do
    obs = observations(:nyc_expenditures)
    obs.value_numeric = nil
    obs.value_text = nil
    assert_not obs.valid?
    # Validating your custom method "value_must_be_present"
    assert_includes obs.errors[:base], "Either numeric value or text value must be present"
  end

  test "requires page reference" do
    obs = observations(:nyc_expenditures)
    obs.page_reference = nil
    assert_not obs.valid?
    assert_includes obs.errors[:page_reference], "can't be blank"
  end
end
