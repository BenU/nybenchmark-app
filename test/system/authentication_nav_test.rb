# frozen_string_literal: true

require "application_system_test_case"

class AuthenticationNavTest < ApplicationSystemTestCase
  test "navbar shows Sign in when logged out" do
    visit root_path

    assert_link "Sign in", href: new_user_session_path
    assert_selector "a", text: "Sign in"
  end
end
