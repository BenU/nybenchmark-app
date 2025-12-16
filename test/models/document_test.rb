# frozen_string_literal: true

require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    document = documents(:nyc_budget)
    assert document.valid?
  end

  test "should require key fields" do
    document = Document.new
    assert_not document.valid?
    %i[title doc_type fiscal_year source_url].each do |field|
      assert_includes document.errors[field], "can't be blank"
    end
  end

  test "should belong to an entity" do
    document = documents(:nyc_budget)
    document.entity = nil
    assert_not document.valid?
    assert_includes document.errors[:entity], "must exist"
  end
end
