# frozen_string_literal: true

# Fixture names contain fiscal years (e.g., _2024) which trigger this cop
# rubocop:disable Naming/VariableNumber

require "test_helper"
require "rake"

class CountyEntityCreatorTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("osc:counties:create_entities")
  end

  test "normalize_county_name converts 'County of Albany' to 'Albany County'" do
    creator = CountyEntityCreator.new
    assert_equal "Albany County", creator.send(:normalize_county_name, "County of Albany")
  end

  test "normalize_county_name handles 'County of St. Lawrence'" do
    creator = CountyEntityCreator.new
    assert_equal "St. Lawrence County", creator.send(:normalize_county_name, "County of St. Lawrence")
  end

  # Integration tests - only run when county CSV files are available
  test "county entities exist in database with correct counts" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :county).count >= 57

    assert_equal 57, Entity.where(kind: :county).count
  end

  test "all county entities have osc_municipal_code" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :county).count >= 57

    without_code = Entity.where(kind: :county)
                         .where(osc_municipal_code: [nil, ""])
                         .count

    assert_equal 0, without_code, "All counties should have OSC municipal code"
  end
end

class CountyOscImporterTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("osc:counties:import")
  end

  test "county fixtures have correct kind" do
    assert entities(:albany_county).county_kind?
    assert entities(:allegany_county).county_kind?
    assert entities(:tompkins_county).county_kind?
  end

  test "county fixtures have osc_municipal_code" do
    assert_equal "010100000000", entities(:albany_county).osc_municipal_code
    assert_equal "020100000000", entities(:allegany_county).osc_municipal_code
    assert_equal "540100000000", entities(:tompkins_county).osc_municipal_code
  end

  test "county fixture documents use osc_county_afr doc_type" do
    assert_equal "osc_county_afr", documents(:albany_county_osc_afr_fy2024).doc_type
    assert_equal "osc_county_afr", documents(:allegany_county_osc_afr_fy2024).doc_type
    assert_equal "osc_county_afr", documents(:tompkins_county_osc_afr_fy2024).doc_type
  end

  test "county fixtures have fund balance observations" do
    obs = observations(:albany_county_fund_balance_2024)
    assert_equal entities(:albany_county), obs.entity
    assert_equal metrics(:unassigned_fund_balance), obs.metric
    assert_equal 2024, obs.fiscal_year
    assert_equal 45_000_000, obs.value_numeric
  end

  test "county fixtures have expenditure observations" do
    obs = observations(:allegany_county_police_2024)
    assert_equal entities(:allegany_county), obs.entity
    assert_equal 2024, obs.fiscal_year
    assert_equal 50_000_000, obs.value_numeric
  end

  test "county fixtures have debt service observations" do
    obs = observations(:tompkins_county_debt_2024)
    assert_equal entities(:tompkins_county), obs.entity
    assert_equal metrics(:debt_service_interest), obs.metric
    assert_equal 6_000_000, obs.value_numeric
  end

  # Integration test - only runs when county data has been imported
  test "county observations imported with correct doc_type" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :county).count >= 57

    county_docs = Document.where(doc_type: "osc_county_afr")
    assert county_docs.any?, "Should have county AFR documents"

    county_ids = Entity.where(kind: :county).pluck(:id)
    county_doc_entities = county_docs.pluck(:entity_id).uniq
    assert (county_doc_entities - county_ids).empty?, "All county docs should belong to county entities"
  end
end
# rubocop:enable Naming/VariableNumber
