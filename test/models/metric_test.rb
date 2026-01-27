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

  # ==========================================
  # DATA_SOURCE ENUM TESTS (OSC Import)
  # ==========================================

  test "data_source defaults to manual" do
    metric = Metric.new(key: "test_default", label: "Test", display_format: "integer")
    assert metric.manual_data_source?
    assert_equal "manual", metric.data_source
  end

  test "data_source can be set to osc" do
    metric = metrics(:police_personal_services)
    assert metric.osc_data_source?
    assert_not metric.manual_data_source?
  end

  test "data_source can be set to census" do
    metric = metrics(:population)
    assert metric.census_data_source?
  end

  test "data_source can be set to rating_agency" do
    metric = metrics(:bond_rating)
    assert metric.rating_agency_data_source?
  end

  test "data_source can be set to derived" do
    metric = metrics(:police_cost_per_capita)
    assert metric.derived_data_source?
  end

  test "data_source rejects invalid values" do
    @metric.data_source = "invalid_source"
    assert_not @metric.valid?
    assert_includes @metric.errors[:data_source], "is not included in the list"
  end

  test "data_source scopes return correct metrics" do
    osc_metrics = Metric.osc_data_source
    census_metrics = Metric.census_data_source
    manual_metrics = Metric.manual_data_source

    # OSC metrics from fixtures
    assert_includes osc_metrics, metrics(:police_personal_services)
    assert_includes osc_metrics, metrics(:police_equipment)
    assert_includes osc_metrics, metrics(:sanitation_personal_services)
    assert_includes osc_metrics, metrics(:pfrs_pension)

    # Census metrics from fixtures
    assert_includes census_metrics, metrics(:population)

    # Manual metrics from fixtures
    assert_includes manual_metrics, metrics(:one)
    assert_includes manual_metrics, metrics(:two)
    assert_includes manual_metrics, metrics(:expenditures)

    # Cross-check: OSC metrics should not be in manual scope
    assert_not_includes manual_metrics, metrics(:police_personal_services)
  end

  # ==========================================
  # ACCOUNT CODE FIELDS TESTS (OSC Import)
  # ==========================================

  test "OSC metric has account_code set" do
    metric = metrics(:police_personal_services)
    assert_equal "A31201", metric.account_code
  end

  test "OSC metric has fund_code set" do
    metric = metrics(:police_personal_services)
    assert_equal "A", metric.fund_code
  end

  test "OSC metric has function_code set" do
    metric = metrics(:police_personal_services)
    assert_equal "3120", metric.function_code
  end

  test "OSC metric has object_code set" do
    metric = metrics(:police_personal_services)
    assert_equal "1", metric.object_code
  end

  test "account code fields are optional" do
    # Manual metrics don't have account codes
    metric = metrics(:one)
    assert_nil metric.account_code
    assert_nil metric.fund_code
    assert_nil metric.function_code
    assert_nil metric.object_code
    assert metric.valid?
  end

  test "can create OSC metric with full account code breakdown" do
    metric = Metric.new(
      key: "street_maintenance_personal_services",
      label: "Street Maintenance - Personal Services",
      data_source: :osc,
      account_code: "A51101",
      fund_code: "A",
      function_code: "5110",
      object_code: "1",
      value_type: :numeric,
      display_format: "currency",
      description: "Road maintenance salaries and wages"
    )

    assert metric.valid?
    assert metric.osc_data_source?
    assert_equal "A51101", metric.account_code
    assert_equal "A", metric.fund_code
    assert_equal "5110", metric.function_code
    assert_equal "1", metric.object_code
  end

  test "can query metrics by fund_code" do
    general_fund_metrics = Metric.where(fund_code: "A")

    assert general_fund_metrics.any?, "Should have metrics with fund_code A"
    assert_includes general_fund_metrics, metrics(:police_personal_services)
    assert_includes general_fund_metrics, metrics(:sanitation_personal_services)

    general_fund_metrics.each do |m|
      assert_equal "A", m.fund_code
    end
  end

  test "can query metrics by function_code for public safety" do
    # 3xxx codes are public safety
    police_metrics = Metric.where(function_code: "3120")

    assert_includes police_metrics, metrics(:police_personal_services)
    assert_includes police_metrics, metrics(:police_equipment)
    assert_not_includes police_metrics, metrics(:sanitation_personal_services)
  end

  test "different object codes distinguish expense types" do
    # .1 = Personal Services, .2 = Equipment
    personal_services = metrics(:police_personal_services)
    equipment = metrics(:police_equipment)

    assert_equal "1", personal_services.object_code
    assert_equal "2", equipment.object_code
    assert_equal personal_services.function_code, equipment.function_code # Same function (3120)
  end

  # ==========================================
  # OSC CATEGORY FIELDS TESTS
  # ==========================================

  test "OSC metric has level_1_category set" do
    metric = metrics(:police_personal_services)
    assert_equal "Public Safety", metric.level_1_category
  end

  test "OSC metric has level_2_category set" do
    metric = metrics(:police_personal_services)
    assert_equal "Police", metric.level_2_category
  end

  test "category fields are optional" do
    # Manual metrics don't have categories
    metric = metrics(:one)
    assert_nil metric.level_1_category
    assert_nil metric.level_2_category
    assert metric.valid?
  end

  test "can query metrics by level_1_category" do
    public_safety_metrics = Metric.where(level_1_category: "Public Safety")

    assert public_safety_metrics.any?, "Should have metrics with Public Safety category"
    assert_includes public_safety_metrics, metrics(:police_personal_services)
    assert_includes public_safety_metrics, metrics(:police_equipment)
    assert_not_includes public_safety_metrics, metrics(:sanitation_personal_services)
  end

  test "can query metrics by level_2_category" do
    police_metrics = Metric.where(level_2_category: "Police")

    assert_includes police_metrics, metrics(:police_personal_services)
    assert_includes police_metrics, metrics(:police_equipment)
    assert_not_includes police_metrics, metrics(:sanitation_personal_services)
  end

  test "same level_1_category groups different expense types" do
    # Both police metrics share level_1_category but have different object codes
    personal_services = metrics(:police_personal_services)
    equipment = metrics(:police_equipment)

    assert_equal personal_services.level_1_category, equipment.level_1_category
    assert_equal personal_services.level_2_category, equipment.level_2_category
    assert_not_equal personal_services.object_code, equipment.object_code
  end

  # ==========================================
  # ACCOUNT_TYPE ENUM TESTS
  # ==========================================

  test "account_type can be nil" do
    # Manual metrics don't have account_type
    metric = metrics(:one)
    assert_nil metric.account_type
    assert metric.valid?
  end

  test "account_type can be set to revenue" do
    @metric.account_type = :revenue
    assert @metric.revenue_account?
    assert_equal "revenue", @metric.account_type
    assert @metric.valid?
  end

  test "account_type can be set to expenditure" do
    @metric.account_type = :expenditure
    assert @metric.expenditure_account?
    assert_equal "expenditure", @metric.account_type
    assert @metric.valid?
  end

  test "account_type can be set to balance_sheet" do
    @metric.account_type = :balance_sheet
    assert @metric.balance_sheet_account?
    assert_equal "balance_sheet", @metric.account_type
    assert @metric.valid?
  end

  test "account_type rejects invalid values" do
    @metric.account_type = "invalid_type"
    assert_not @metric.valid?
    assert_includes @metric.errors[:account_type], "is not included in the list"
  end

  test "account_type scopes return correct metrics" do
    # Create test metrics with different account types
    revenue_metric = Metric.create!(
      key: "test_revenue",
      label: "Test Revenue",
      account_type: :revenue,
      display_format: "currency"
    )
    expenditure_metric = Metric.create!(
      key: "test_expenditure",
      label: "Test Expenditure",
      account_type: :expenditure,
      display_format: "currency"
    )

    assert_includes Metric.revenue_account, revenue_metric
    assert_not_includes Metric.expenditure_account, revenue_metric

    assert_includes Metric.expenditure_account, expenditure_metric
    assert_not_includes Metric.revenue_account, expenditure_metric
  end
end
