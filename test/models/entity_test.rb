# frozen_string_literal: true

require "test_helper"

class EntityTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    entity = entities(:one) # Uses fixture
    assert entity.valid?
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
    duplicate = Entity.new(name: "Clone", slug: entities(:one).slug)
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
end
