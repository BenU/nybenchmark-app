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
end
