# frozen_string_literal: true

require "test_helper"

class MetricTest < ActiveSupport::TestCase
  def setup
    @metric = Metric.new(
      key: "public_safety_ftes",
      label: "Public Safety Personel",
      unit: "Count",
      description: "Total police and firefighters"
    )
  end

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
end
