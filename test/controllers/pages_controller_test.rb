# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  # ==========================================
  # METHODOLOGY PAGE
  # ==========================================

  test "methodology page loads successfully" do
    get methodology_url
    assert_response :success
  end

  test "methodology page is indexable (no noindex meta tag)" do
    get methodology_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "methodology page mentions OSC data source" do
    get methodology_url
    assert_response :success
    assert_select "main", text: /NYS Comptroller/
  end

  test "methodology page mentions Census data source" do
    get methodology_url
    assert_response :success
    assert_select "main", text: /Census Bureau/
  end

  # ==========================================
  # NON-FILERS PAGE
  # ==========================================

  test "non-filers page loads successfully" do
    get non_filers_url
    assert_response :success
  end

  test "non-filers page is indexable (no noindex meta tag)" do
    get non_filers_url
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]', count: 0
  end

  test "non-filers page explains why filing matters" do
    get non_filers_url
    assert_response :success
    assert_select "main", text: /filing/i
  end

  test "non-filers page links to methodology" do
    get non_filers_url
    assert_response :success
    assert_select "a[href=?]", methodology_path
  end

  test "non-filers page does not list NYC" do
    get non_filers_url
    assert_response :success
    assert_select "td", text: "New York City", count: 0
  end
end
