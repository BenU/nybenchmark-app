# frozen_string_literal: true

require "test_helper"

class EntitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Using 'yonkers' (NYC) from your uploaded entities.yml
    @entity = entities(:yonkers)
  end

  test "should get index" do
    get entities_url
    assert_response :success

    # Pico.css Semantic Check: Main container presence
    assert_select "main.container"

    # Content Check: Should list entities
    assert_select "h1", "New York Entities"

    # Verify the table lists the entity name
    assert_select "table" do
      assert_select "tr", minimum: 1
      assert_select "td", text: @entity.name
    end
  end

  test "should show entity hub" do
    # Routing via Slug (e.g., /entities/nyc)
    get entity_url(@entity.slug)
    assert_response :success

    # Header Check
    assert_select "hgroup" do
      assert_select "h1", @entity.name
      # Checks for state or subtitle
      assert_select "p", text: /New York/
    end

    # Hub Requirements: Verify Sections exist for the related data
    assert_select "section#documents" do
      assert_select "h2", "Financial Documents"
    end

    assert_select "section#observations" do
      assert_select "h2", "Recent Data"
    end
  end

  test "update accepts icma_recognition_year" do
    sign_in users(:one)

    patch entity_url(@entity.slug), params: {
      entity: { icma_recognition_year: 1975 }
    }

    assert_redirected_to entity_url(@entity.slug)
    @entity.reload
    assert_equal 1975, @entity.icma_recognition_year
  end

  # ==========================================
  # FILTER TESTS
  # ==========================================

  test "index filter form has Clear button before Apply button" do
    get entities_url
    assert_response :success
    assert_match(/Clear.*Apply/m, response.body)
  end
end
