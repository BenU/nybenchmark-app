# frozen_string_literal: true

require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  setup do
    # 1. Save the current environment value so we can restore it later
    @original_admin_email = ENV.fetch("ADMIN_EMAIL", nil)

    # 2. Force the specific email we want to test against
    ENV["ADMIN_EMAIL"] = "admin@example.com"
  end

  teardown do
    # 3. Restore the original value to avoid breaking other tests
    ENV["ADMIN_EMAIL"] = @original_admin_email
  end

  test "new_user_waiting_for_approval" do
    user = User.new(email: "pending_signup@example.com")

    email = AdminMailer.with(user: user).new_user_waiting_for_approval

    assert_equal ["admin@example.com"], email.to
    assert_match(/pending approval/i, email.subject)
    assert_includes email.body.encoded, "pending_signup@example.com"
  end
end
