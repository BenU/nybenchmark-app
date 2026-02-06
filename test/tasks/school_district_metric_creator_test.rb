# frozen_string_literal: true

require "test_helper"
require "rake"

class SchoolDistrictMetricCreatorTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("osc:schools:create_metrics")
  end

  test "METADATA_COLUMNS contains the columns to skip" do
    # These are CSV column headers that are metadata, not financial metrics
    metadata = SchoolDistrictMetricCreator::METADATA_COLUMNS

    assert_includes metadata, "Muni Code"
    assert_includes metadata, "Entity Name"
    assert_includes metadata, "County"
    assert_includes metadata, "Class Description"
    assert_includes metadata, "Fiscal Year End Date"
    assert_includes metadata, "Months in Fiscal Period"
  end

  test "classifies revenue columns correctly" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    # Property taxes and fees
    assert_equal :revenue, creator.send(:infer_account_type, "Real Property Taxes")
    assert_equal :revenue, creator.send(:infer_account_type, "Education Fees")
    assert_equal :revenue, creator.send(:infer_account_type, "Interest and Earnings")

    # State and Federal Aid
    assert_equal :revenue, creator.send(:infer_account_type, "State Aid - Education")
    assert_equal :revenue, creator.send(:infer_account_type, "Federal Aid - Education")
    assert_equal :revenue, creator.send(:infer_account_type, "Unrestricted State Aid")

    # Other revenue sources
    assert_equal :revenue, creator.send(:infer_account_type, "Sale of Obligations")
    assert_equal :revenue, creator.send(:infer_account_type, "Transfers")
    assert_equal :revenue, creator.send(:infer_account_type, "Miscellaneous Other Sources")
  end

  test "classifies expenditure columns correctly" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    # Education expenditures
    assert_equal :expenditure, creator.send(:infer_account_type, "Instruction")
    assert_equal :expenditure, creator.send(:infer_account_type, "Instructional Support")
    assert_equal :expenditure, creator.send(:infer_account_type, "Pupil Services")

    # Employee benefits
    assert_equal :expenditure, creator.send(:infer_account_type, "Retirement - Teacher")
    assert_equal :expenditure, creator.send(:infer_account_type, "Medical Insurance")

    # Debt service
    assert_equal :expenditure, creator.send(:infer_account_type, "Debt Principal")
    assert_equal :expenditure, creator.send(:infer_account_type, "Interest on Debt")

    # Totals
    assert_equal :expenditure, creator.send(:infer_account_type, "Total Expenditures")
    assert_equal :expenditure, creator.send(:infer_account_type, "Total Expenditures and Other Uses")
  end

  test "classifies balance sheet columns correctly" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    assert_equal :balance_sheet, creator.send(:infer_account_type, "Debt Outstanding")
    assert_equal :balance_sheet, creator.send(:infer_account_type, "Full Value")
  end

  test "classifies special columns correctly" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    # Enrollment is special - not financial
    assert_nil creator.send(:infer_account_type, "Enrollment")
  end

  test "infers level_1_category for education expenditures" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    assert_equal "Education", creator.send(:infer_level_1_category, "Instruction")
    assert_equal "Education", creator.send(:infer_level_1_category, "Instructional Support")
    assert_equal "Education", creator.send(:infer_level_1_category, "Pupil Services")
    assert_equal "Education", creator.send(:infer_level_1_category, "Education - Transportation")
    assert_equal "Education", creator.send(:infer_level_1_category, "Student Activities")
  end

  test "infers level_1_category for employee benefits" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    assert_equal "Employee Benefits", creator.send(:infer_level_1_category, "Retirement - Teacher")
    assert_equal "Employee Benefits", creator.send(:infer_level_1_category, "Medical Insurance")
    assert_equal "Employee Benefits", creator.send(:infer_level_1_category, "Social Security")
  end

  test "infers level_1_category for debt service" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    assert_equal "Debt Service", creator.send(:infer_level_1_category, "Debt Principal")
    assert_equal "Debt Service", creator.send(:infer_level_1_category, "Interest on Debt")
  end

  test "infers level_1_category for state and federal aid" do
    creator = SchoolDistrictMetricCreator.new(dry_run: true)

    assert_equal "State Aid", creator.send(:infer_level_1_category, "State Aid - Education")
    assert_equal "State Aid", creator.send(:infer_level_1_category, "Unrestricted State Aid")
    assert_equal "Federal Aid", creator.send(:infer_level_1_category, "Federal Aid - Education")
  end
end
