# frozen_string_literal: true

require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  setup do
    @original_admin_email = Rails.application.config.x.admin_email
    Rails.application.config.x.admin_email = "admin@example.com"
  end

  teardown do
    Rails.application.config.x.admin_email = @original_admin_email
  end

  test "new_user_waiting_for_approval" do
    user = User.new(email: "pending_signup@example.com")

    email = AdminMailer.with(user: user).new_user_waiting_for_approval

    assert_equal ["admin@example.com"], email.to
    assert_match(/pending approval/i, email.subject)
    assert_includes email.body.encoded, "pending_signup@example.com"
  end
end
