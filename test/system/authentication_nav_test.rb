# frozen_string_literal: true

require "application_system_test_case"

class AuthenticationNavTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "navbar does not show Sign in or Sign up when logged out" do
    visit root_path

    within "header nav" do
      assert_no_link "Sign in"
      assert_no_link "Sign up"
    end
  end

  test "navbar shows Entities and Methodology links when logged out" do
    visit root_path

    within "header nav" do
      assert_link "Entities", href: entities_path
      assert_link "Methodology", href: methodology_path
      assert_no_link "Documents"
      assert_no_link "Metrics"
    end
  end

  test "navbar shows Compare Districts link" do
    visit root_path

    within "header nav" do
      assert_link "Compare Districts", href: school_districts_compare_path
    end
  end

  test "navbar shows admin links when signed in" do
    sign_in @user
    visit root_path

    assert_link "Documents", href: documents_path
    assert_link "Metrics", href: metrics_path
  end

  test "Verify Queue is not shown in navbar" do
    sign_in @user
    visit root_path

    assert_no_link "Verify Queue"
  end
end
