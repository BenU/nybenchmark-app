# frozen_string_literal: true

require "test_helper"

class MetricTest < ActiveSupport::TestCase
  def setup
    @metric = Metric.new(
      key: "public_safety_ftes",
      label: "Public Safety Personel",
      unit: "Count",
      description: "Total police and firefighters",
      value_type: :numeric,
      display_format: "integer"
    )
  end

  # --- 1. Basic Validations ---

  test "should be valid with all required attributes" do
    assert @metric.valid?
  end

  test "should be invalid without a key" do
    @metric.key = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:key], "can't be blank"
  end

  test "should be invalid without a label" do
    @metric.label = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:label], "can't be blank"
  end

  test "key should be unique" do
    @metric.save!
    duplicate_metric = @metric.dup
    assert_not duplicate_metric.valid?
    assert_includes duplicate_metric.errors[:key], "has already been taken"
  end

  test "should track changes with paper_trail" do
    @metric.save!
    assert_equal 1, @metric.versions.count
    @metric.update!(label: "Updated Label")
    assert_equal 2, @metric.versions.count
  end

  test "should not destroy metric if it has observations" do
    # Uses fixture :one which must have associated observations
    metric = metrics(:one)

    assert_no_difference "Metric.count" do
      metric.destroy
    end
    assert_includes metric.errors[:base], "Cannot delete record because dependent observations exist"
  end

  # --- 2. Value Type Enum ---

  test "value_type defaults to numeric" do
    metric = Metric.new(key: "test", label: "Test", display_format: "integer")
    assert metric.numeric?
    assert_equal "numeric", metric.value_type
  end

  test "value_type can be set to text" do
    @metric.value_type = :text
    assert @metric.text?
    assert_not @metric.numeric?
  end

  test "value_type rejects invalid values" do
    # Rails enums with validate: true add validation errors instead of raising ArgumentError
    @metric.value_type = "invalid"
    assert_not @metric.valid?
    assert_includes @metric.errors[:value_type], "is not included in the list"
  end

  # --- 3. Display Format Validation ---

  test "display_format accepts valid formats" do
    valid_formats = %w[currency currency_rounded percentage integer decimal fte rate]
    valid_formats.each do |format|
      @metric.display_format = format
      assert @metric.valid?, "Expected #{format} to be valid"
    end
  end

  test "display_format is required for numeric metrics" do
    @metric.value_type = :numeric
    @metric.display_format = nil
    assert_not @metric.valid?
    assert_includes @metric.errors[:display_format], "is required for numeric metrics"
  end

  test "display_format is optional for text metrics" do
    @metric.value_type = :text
    @metric.display_format = nil
    assert @metric.valid?
  end

  test "display_format rejects invalid values for numeric metrics" do
    @metric.value_type = :numeric
    @metric.display_format = "invalid_format"
    assert_not @metric.valid?
    assert_includes @metric.errors[:display_format], "is not a valid display format"
  end

  # --- 4. Formula (for Derived Metrics) ---

  test "formula is optional" do
    @metric.formula = nil
    assert @metric.valid?
  end

  test "derived? returns true when formula is present" do
    @metric.formula = "police_fte + fire_fte"
    assert @metric.derived?
  end

  test "derived? returns false when formula is blank" do
    @metric.formula = nil
    assert_not @metric.derived?

    @metric.formula = ""
    assert_not @metric.derived?
  end

  # --- 5. Helper Methods ---

  test "expects_numeric? returns true for numeric value_type" do
    @metric.value_type = :numeric
    assert @metric.expects_numeric?
    assert_not @metric.expects_text?
  end

  test "expects_text? returns true for text value_type" do
    @metric.value_type = :text
    assert @metric.expects_text?
    assert_not @metric.expects_numeric?
  end

  # --- 6. format_value Helper ---

  test "format_value formats currency with dollar sign and commas" do
    @metric.display_format = "currency"
    assert_equal "$1,234,567.89", @metric.format_value(1_234_567.89)
    assert_equal "$0.00", @metric.format_value(0)
    assert_equal "-$1,234.56", @metric.format_value(-1234.56)
  end

  test "format_value formats currency_rounded without decimals" do
    @metric.display_format = "currency_rounded"
    assert_equal "$1,234,568", @metric.format_value(1_234_567.89)
    assert_equal "$1,000,000", @metric.format_value(1_000_000)
  end

  test "format_value formats percentage with percent sign" do
    @metric.display_format = "percentage"
    assert_equal "12.5%", @metric.format_value(12.5)
    assert_equal "0.0%", @metric.format_value(0)
    assert_equal "100.0%", @metric.format_value(100)
  end

  test "format_value formats integer with commas, no decimals" do
    @metric.display_format = "integer"
    assert_equal "1,234,567", @metric.format_value(1_234_567)
    assert_equal "1,234,568", @metric.format_value(1_234_567.89) # rounds
  end

  test "format_value formats decimal with commas and 2 decimals" do
    @metric.display_format = "decimal"
    assert_equal "1,234.57", @metric.format_value(1234.567)
    assert_equal "0.00", @metric.format_value(0)
  end

  test "format_value formats fte with 1 decimal place" do
    @metric.display_format = "fte"
    assert_equal "3.5", @metric.format_value(3.5)
    assert_equal "150.0", @metric.format_value(150)
    assert_equal "3.5", @metric.format_value(3.54) # rounds to 1 decimal
  end

  test "format_value formats rate with 1 decimal place" do
    @metric.display_format = "rate"
    assert_equal "456.7", @metric.format_value(456.72)
    assert_equal "0.9", @metric.format_value(0.85)
  end

  test "format_value returns nil for nil input" do
    @metric.display_format = "currency"
    assert_nil @metric.format_value(nil)
  end

  test "format_value returns raw value for text metrics" do
    @metric.value_type = :text
    @metric.display_format = nil
    assert_equal "Some text", @metric.format_value("Some text")
  end
end
