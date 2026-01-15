# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "newly initialized user is not approved by default" do
    user = User.new
    assert_not user.approved?, "Expected new user to have approved: false"
  end

  test "fixtures have correct approval status" do
    assert users(:one).approved?
    assert_not users(:pending).approved?
  end

  test "approved users are active for authentication" do
    assert users(:one).active_for_authentication?
  end

  test "unapproved users are inactive for authentication" do
    assert_not users(:pending).active_for_authentication?
  end
end
