# frozen_string_literal: true

require "test_helper"

class UserApprovalTest < ActionDispatch::IntegrationTest
  test "approved user can sign in" do
    user = users(:one)

    post user_session_path, params: { user: { email: user.email, password: "password" } }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    assert_includes response.body, "Signed in successfully."
  end

  test "pending user cannot sign in" do
    user = users(:pending)

    post user_session_path, params: { user: { email: user.email, password: "password" } }

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_response :success

    expected = "Your account is pending approval."
    assert_includes response.body, expected
  end

  test "newly registered user sees pending approval message" do
    post user_registration_path, params: {
      user: {
        email: "new_pending_user@example.com",
        password: "password",
        password_confirmation: "password"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    expected = "Thanks for signing up. Your account is pending approval."
    assert_includes response.body, expected
  end
end
