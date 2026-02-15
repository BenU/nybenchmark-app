# frozen_string_literal: true

require "test_helper"

class EntityTest < ActiveSupport::TestCase
  test "fixture entities are valid" do
    assert entities(:yonkers).valid?
    assert entities(:yonkers_schools).valid?
    assert entities(:new_rochelle).valid?
    assert entities(:new_rochelle_schools).valid?
  end

  test "should require a name" do
    entity = Entity.new(slug: "test")
    assert_not entity.valid?
    assert_includes entity.errors[:name], "can't be blank"
  end

  test "should require a slug" do
    entity = Entity.new(name: "Test")
    assert_not entity.valid?
    assert_includes entity.errors[:slug], "can't be blank"
  end

  test "slug should be unique" do
    # Try to create a duplicate of entity :one
    duplicate = Entity.new(name: "Clone", slug: entities(:yonkers).slug)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "name must be unique within scope of state and kind" do
    # 1. Setup: Create the first "Rye" (City)
    # Using 'create!' to ensure it persists to DB
    Entity.create!(
      name: "Rye",
      kind: "city",
      state: "NY",
      slug: "rye-city-existing" # Slugs must be unique too
    )

    # 2. Sad Path: Try to create a DUPLICATE "Rye" (City)
    duplicate_city = Entity.new(
      name: "Rye",
      kind: "city",
      state: "NY",
      slug: "rye-city-duplicate"
    )

    assert_not duplicate_city.valid?, "Entity should be invalid if name/kind/state are identical"
    assert_includes duplicate_city.errors[:name], "already exists for this type of entity in this state"

    # 3. Happy Path: Try to create a "Rye" (Town) - Same name, different kind
    rye_town = Entity.new(
      name: "Rye",
      kind: "town", # Different kind
      state: "NY",
      slug: "rye-town"
    )

    assert rye_town.valid?, "Entity should be valid if name is same but kind is different"
  end

  test "self-referential hierarchy rolls up fiscally" do
    yonkers = entities(:yonkers)
    yonkers_schools = entities(:yonkers_schools)

    assert_equal yonkers, yonkers_schools.parent
    assert_includes yonkers.children, yonkers_schools
  end

  test "enum predicate methods exist for governance fields" do
    yonkers = entities(:yonkers)
    nr = entities(:new_rochelle)
    yonkers_schools = entities(:yonkers_schools)
    nr_schools = entities(:new_rochelle_schools)

    assert yonkers.strong_mayor_government_structure?
    assert nr.council_manager_government_structure?

    assert yonkers_schools.big_five_school_legal_type?
    assert nr_schools.small_city_school_legal_type?

    assert yonkers_schools.dependent_fiscal_autonomy?
    assert nr_schools.independent_fiscal_autonomy?
  end

  test "school_districts scope returns only school district entities" do
    school_slugs = Entity.school_districts.order(:slug).pluck(:slug)
    assert_equal %w[new_rochelle_schools yonkers_schools], school_slugs
  end

  test "conditional validation: school_legal_type must be present for school districts" do
    entity = Entity.new(
      name: "Test Schools",
      slug: "test_schools",
      kind: "school_district",
      state: "NY",
      fiscal_autonomy: "independent"
    )

    assert_not entity.valid?
    assert_includes entity.errors[:school_legal_type], "can't be blank"
  end

  test "conditional validation: school_legal_type must be blank for non-school entities" do
    entity = Entity.new(
      name: "Test City",
      slug: "test_city",
      kind: "city",
      state: "NY",
      school_legal_type: "big_five"
    )

    assert_not entity.valid?
    assert_includes entity.errors[:school_legal_type], "must be blank unless kind is school_district"
  end

  test "entity can have icma_recognition_year" do
    entity = entities(:new_rochelle)
    entity.icma_recognition_year = 1932

    assert entity.valid?
    assert_equal 1932, entity.icma_recognition_year
  end

  test "icma_recognition_year can be nil" do
    entity = entities(:albany)
    assert_nil entity.icma_recognition_year
    assert entity.valid?
  end

  # ==========================================
  # OSC MUNICIPAL CODE TESTS
  # ==========================================

  test "entity can have osc_municipal_code" do
    entity = entities(:yonkers)
    assert_equal "550262000000", entity.osc_municipal_code
  end

  test "osc_municipal_code is optional" do
    # NYC and other special cases won't have OSC codes
    entity = Entity.new(
      name: "Test City",
      kind: :city,
      state: "NY",
      slug: "test_city"
      # osc_municipal_code intentionally omitted
    )
    assert_nil entity.osc_municipal_code
    assert entity.valid?
  end

  # ==========================================
  # WIKIPEDIA SEARCH URL TESTS
  # ==========================================

  test "wikipedia_search_url for city includes name and New York" do
    yonkers = entities(:yonkers)
    assert_equal "https://en.wikipedia.org/w/index.php?search=Yonkers+New+York+city", yonkers.wikipedia_search_url
  end

  test "wikipedia_search_url for city with spaces encodes correctly" do
    nr = entities(:new_rochelle)
    assert_equal "https://en.wikipedia.org/w/index.php?search=New+Rochelle+New+York+city", nr.wikipedia_search_url
  end

  test "wikipedia_search_url for county includes County in search" do
    county = entities(:albany_county)
    assert_equal "https://en.wikipedia.org/w/index.php?search=Albany+County+New+York", county.wikipedia_search_url
  end

  test "wikipedia_search_url returns nil for school districts" do
    assert_nil entities(:yonkers_schools).wikipedia_search_url
  end

  test "fixture cities have osc_municipal_code from entity_mapping" do
    # Verify fixtures match the OSC entity mapping
    assert_equal "550262000000", entities(:yonkers).osc_municipal_code
    assert_equal "550233000000", entities(:new_rochelle).osc_municipal_code
  end
end
