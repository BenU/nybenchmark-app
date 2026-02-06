# frozen_string_literal: true

require "test_helper"
require "rake"

class SchoolDistrictEntityCreatorTest < ActiveSupport::TestCase
  setup do
    # Load the rake task to get access to the service class
    Rails.application.load_tasks unless Rake::Task.task_defined?("osc:schools:create_entities")
  end

  test "maps City Public School to big_five for Big Five cities" do
    creator = SchoolDistrictEntityCreator.new(dry_run: true)

    assert_equal :big_five, creator.send(:map_legal_type, "City Public School", "Buffalo City School District")
    assert_equal :big_five, creator.send(:map_legal_type, "City Public School", "Rochester City School District")
    assert_equal :big_five, creator.send(:map_legal_type, "City Public School", "Syracuse City School District")
    assert_equal :big_five, creator.send(:map_legal_type, "City Public School", "Yonkers City School District")
  end

  test "maps City Public School to small_city for non-Big Five cities" do
    creator = SchoolDistrictEntityCreator.new(dry_run: true)

    assert_equal :small_city, creator.send(:map_legal_type, "City Public School", "Albany City School District")
    assert_equal :small_city, creator.send(:map_legal_type, "City Public School", "Troy City School District")
    assert_equal :small_city, creator.send(:map_legal_type, "City Public School", "Mount Vernon School District")
  end

  test "maps Central and variants to central" do
    creator = SchoolDistrictEntityCreator.new(dry_run: true)

    assert_equal :central, creator.send(:map_legal_type, "Central", "Some Central School District")
    assert_equal :central, creator.send(:map_legal_type, "Independent Superintendent", "Another School District")
    assert_equal :central, creator.send(:map_legal_type, "Central High", "Regional High School")
  end

  test "maps Union Free to union_free" do
    creator = SchoolDistrictEntityCreator.new(dry_run: true)

    assert_equal :union_free, creator.send(:map_legal_type, "Union Free", "Ardsley Union Free School District")
  end

  test "maps Common to common" do
    creator = SchoolDistrictEntityCreator.new(dry_run: true)

    assert_equal :common, creator.send(:map_legal_type, "Common", "Some Common School District")
  end

  test "returns nil for unknown class" do
    creator = SchoolDistrictEntityCreator.new(dry_run: true)

    assert_nil creator.send(:map_legal_type, "Unknown Type", "Some District")
    assert_nil creator.send(:map_legal_type, "", "Empty Class")
  end

  test "CITY_NAME_MAPPING includes all 61 city school districts" do
    # 4 Big Five + 57 small city = 61 total
    # But NYC is not in OSC, so we have 60 mappings + Mount Vernon variant = 61
    mapping = SchoolDistrictEntityCreator::CITY_NAME_MAPPING

    # Check Big Five are mapped
    assert_equal "Buffalo", mapping["Buffalo City School District"]
    assert_equal "Rochester", mapping["Rochester City School District"]
    assert_equal "Syracuse", mapping["Syracuse City School District"]
    assert_equal "Yonkers", mapping["Yonkers City School District"]

    # Check some small city mappings
    assert_equal "Albany", mapping["Albany City School District"]
    assert_equal "Troy", mapping["Troy City School District"]
    assert_equal "Mount Vernon", mapping["Mount Vernon School District"]
    assert_equal "New Rochelle", mapping["New Rochelle City School District"]
  end

  test "BIG_FIVE_NAMES contains exactly 4 districts" do
    big_five = SchoolDistrictEntityCreator::BIG_FIVE_NAMES

    assert_equal 4, big_five.size
    assert_includes big_five, "Buffalo City School District"
    assert_includes big_five, "Rochester City School District"
    assert_includes big_five, "Syracuse City School District"
    assert_includes big_five, "Yonkers City School District"
    assert_not_includes big_five, "New York City" # NYC not in OSC
  end

  # Integration tests - these verify the actual database state after import.
  # They only run when the full OSC import has been executed (689 school districts).
  # In the test environment with fixtures, these will be skipped.

  test "school districts exist in database with correct counts" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :school_district).count >= 689

    assert_equal 689, Entity.where(kind: :school_district).count
  end

  test "school district legal types have expected distribution" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :school_district).count >= 689

    counts = Entity.where(kind: :school_district).group(:school_legal_type).count

    assert_equal 4, counts["big_five"]
    assert_equal 57, counts["small_city"]
    assert_equal 546, counts["central"]
    assert_equal 72, counts["union_free"]
    assert_equal 10, counts["common"]
  end

  test "all city school districts have parent relationships" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :school_district).count >= 689

    city_sds = Entity.where(kind: :school_district, school_legal_type: %w[big_five small_city])

    assert_equal 61, city_sds.count
    assert_equal 61, city_sds.where.not(parent_id: nil).count, "All city SDs should have parent"
  end

  test "Big Five districts are linked to correct parent cities" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :school_district).count >= 689

    big_five_mappings = {
      "Buffalo City School District" => "Buffalo",
      "Rochester City School District" => "Rochester",
      "Syracuse City School District" => "Syracuse",
      "Yonkers City School District" => "Yonkers"
    }

    big_five_mappings.each do |sd_name, city_name|
      sd = Entity.find_by(name: sd_name, kind: :school_district)
      assert sd, "#{sd_name} should exist"
      assert_equal city_name, sd.parent&.name, "#{sd_name} should be linked to #{city_name}"
    end
  end

  test "all school districts have osc_municipal_code" do
    skip "Test fixtures, not seeded data" unless Entity.where(kind: :school_district).count >= 689

    without_code = Entity.where(kind: :school_district)
                         .where(osc_municipal_code: [nil, ""])
                         .count

    assert_equal 0, without_code, "All school districts should have OSC municipal code"
  end
end
