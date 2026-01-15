# frozen_string_literal: true

require "test_helper"

class AdminSignupNotificationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    # 1. Mock ENV["ADMIN_EMAIL"] instead of config.x
    @original_admin_email = ENV.fetch("ADMIN_EMAIL", nil)
    ENV["ADMIN_EMAIL"] = "admin@example.com"

    ActionMailer::Base.deliveries.clear
  end

  teardown do
    # 2. Restore original ENV value
    ENV["ADMIN_EMAIL"] = @original_admin_email
  end

  test "signing up sends an admin notification email" do
    assert_emails 1 do
      post user_registration_path, params: {
        user: {
          email: "notify_admin_on_signup@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    email = ActionMailer::Base.deliveries.last
    assert_not_nil email

    assert_equal ["admin@example.com"], email.to
    assert_match(/pending approval/i, email.subject)
    assert_includes email.body.encoded, "notify_admin_on_signup@example.com"
  end
end
