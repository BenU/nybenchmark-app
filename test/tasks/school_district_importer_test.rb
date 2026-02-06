# frozen_string_literal: true

require "test_helper"
require "rake"

class SchoolDistrictImporterTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("osc:schools:import")
  end

  test "CSV_DIR points to the correct directory" do
    assert SchoolDistrictImporter::CSV_DIR.to_s.end_with?("db/seeds/osc_school_district_data")
  end

  test "METADATA_COLUMNS matches metric creator" do
    # These columns should be skipped during import (not financial data)
    metadata = SchoolDistrictImporter::METADATA_COLUMNS

    assert_includes metadata, "Muni Code"
    assert_includes metadata, "Entity Name"
    assert_includes metadata, "County"
    assert_includes metadata, "Class Description"
    assert_includes metadata, "Fiscal Year End Date"
    assert_includes metadata, "Months in Fiscal Period"
  end

  test "extracts fiscal year from filename" do
    importer = SchoolDistrictImporter.new(dry_run: true)

    assert_equal 2024, importer.send(:extract_year_from_filename, "leveltwo24.csv")
    assert_equal 2012, importer.send(:extract_year_from_filename, "leveltwo12.csv")
    assert_equal 2019, importer.send(:extract_year_from_filename, "leveltwo19.csv")
  end

  test "builds metric key from column name" do
    importer = SchoolDistrictImporter.new(dry_run: true)

    assert_equal "school_instruction", importer.send(:metric_key_for, "Instruction")
    assert_equal "school_real_property_taxes", importer.send(:metric_key_for, "Real Property Taxes")
    assert_equal "school_state_aid_education", importer.send(:metric_key_for, "State Aid - Education")
  end

  test "parses numeric values correctly" do
    importer = SchoolDistrictImporter.new(dry_run: true)

    assert_equal BigDecimal("1234567.89"), importer.send(:parse_amount, "1234567.89")
    assert_equal BigDecimal("1000000"), importer.send(:parse_amount, "1000000")
    assert_nil importer.send(:parse_amount, "")
    assert_nil importer.send(:parse_amount, nil)
    assert_equal BigDecimal("0"), importer.send(:parse_amount, "0")
  end

  test "skips zero and empty values" do
    importer = SchoolDistrictImporter.new(dry_run: true)

    # Zero values should be skipped (returns true for should_skip?)
    assert importer.send(:should_skip_value?, "0")
    assert importer.send(:should_skip_value?, "")
    assert importer.send(:should_skip_value?, nil)

    # Non-zero values should not be skipped
    assert_not importer.send(:should_skip_value?, "1234")
    assert_not importer.send(:should_skip_value?, "0.01")
  end
end
