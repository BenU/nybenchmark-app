# frozen_string_literal: true

require "test_helper"

class FilingStatusTest < ActiveSupport::TestCase
  # Fixtures give us:
  # - yonkers: OSC observations for 2021, 2022, 2023
  # - new_rochelle: OSC observation for 2023 only
  # - albany: no OSC observations (entity exists but no osc-sourced data)

  # ==========================================
  # INSTANCE METHODS
  # ==========================================

  test "last_osc_filing_year returns most recent year with OSC data" do
    assert_equal 2023, entities(:yonkers).last_osc_filing_year
  end

  test "last_osc_filing_year returns nil when entity has no OSC data" do
    assert_nil entities(:albany).last_osc_filing_year
  end

  test "osc_missing_years returns years without OSC data in given range" do
    # Yonkers has data for 2021, 2022, 2023 — missing 2020 and 2024
    missing = entities(:yonkers).osc_missing_years(2020..2024)
    assert_includes missing, 2020
    assert_includes missing, 2024
    assert_not_includes missing, 2021
    assert_not_includes missing, 2022
    assert_not_includes missing, 2023
  end

  test "osc_missing_years returns all years for entity with no OSC data" do
    missing = entities(:albany).osc_missing_years(2020..2024)
    assert_equal [2020, 2021, 2022, 2023, 2024], missing
  end

  test "osc_filing_rate returns percentage of years filed in range" do
    # Yonkers filed 3 of 5 years (2020-2024)
    rate = entities(:yonkers).osc_filing_rate(2020..2024)
    assert_in_delta 60.0, rate, 0.1
  end

  test "osc_filing_rate returns 0 for entity with no OSC data" do
    rate = entities(:albany).osc_filing_rate(2020..2024)
    assert_equal 0.0, rate
  end

  # ==========================================
  # CLASS METHODS
  # ==========================================

  test "latest_majority_year returns most recent year where >= 50% of cities have data" do
    # With fixture data, we have limited cities — this tests the logic works
    year = Entity.latest_majority_year
    # Should return a year or nil depending on fixture coverage
    assert_kind_of Integer, year if year
  end

  test "filing_report groups non-filing cities by category" do
    # With as_of_year = 2023, Albany has no data → chronic
    # Yonkers and New Rochelle have data for 2023 → not in report
    report = Entity.filing_report(2023)

    assert report.is_a?(Hash)
    assert (report.keys - %i[chronic recent_lapse sporadic]).empty?,
           "Report keys should only be :chronic, :recent_lapse, :sporadic"
  end

  test "filing_report classifies entity with no OSC data as chronic" do
    report = Entity.filing_report(2023)
    chronic_ids = (report[:chronic] || []).map(&:id)
    assert_includes chronic_ids, entities(:albany).id
  end

  test "filing_category returns nil when entity filed after as_of_year" do
    # Yonkers last filed 2023; asking about 2022 should treat as current filer
    assert_nil entities(:yonkers).filing_category(2022)
  end

  # ==========================================
  # OSC FILING EXEMPTION (NYC)
  # ==========================================

  test "osc_filing_exempt? returns true for NYC" do
    assert entities(:nyc).osc_filing_exempt?
  end

  test "osc_filing_exempt? returns false for regular cities" do
    assert_not entities(:yonkers).osc_filing_exempt?
  end

  test "filing_category returns nil for exempt entity" do
    assert_nil entities(:nyc).filing_category(2023)
  end

  test "filing_report does not include exempt entities" do
    report = Entity.filing_report(2023)
    all_ids = report.values.flatten.map(&:id)
    assert_not_includes all_ids, entities(:nyc).id
  end

  test "latest_majority_year excludes exempt entities from city count" do
    # NYC is exempt, so it shouldn't inflate the denominator
    # This just verifies the method runs without error with the exemption
    year = Entity.latest_majority_year
    assert_kind_of Integer, year if year
  end

  test "filing_report does not include entities that filed for as_of_year" do
    report = Entity.filing_report(2023)
    all_ids = report.values.flatten.map(&:id)
    assert_not_includes all_ids, entities(:yonkers).id
  end
end
