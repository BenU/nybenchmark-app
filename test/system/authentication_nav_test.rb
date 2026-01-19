# frozen_string_literal: true

require "application_system_test_case"

class AuthenticationNavTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @provisional_obs = observations(:new_rochelle_revenue_text)

    # Attach PDF so cockpit renders properly
    unless @provisional_obs.document.file.attached?
      @provisional_obs.document.file.attach(
        io: StringIO.new("%PDF-1.4 simulated"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
    end
  end

  test "navbar shows Sign in when logged out" do
    visit root_path

    assert_link "Sign in", href: new_user_session_path
    assert_selector "a", text: "Sign in"
  end

  test "navbar does not show Verify Queue link when logged out" do
    visit root_path

    assert_no_link "Verify Queue"
  end

  test "navbar shows Verify Queue link that goes to cockpit when logged in" do
    sign_in @user
    visit root_path

    # Should have the Verify Queue link with badge showing count
    assert_link "Verify Queue"

    # Click should go to verification cockpit, not the filtered observations list
    click_link "Verify Queue"

    # Should be on the verify cockpit page
    assert_text "Verification Cockpit"
    assert_selector "iframe#pdf-viewer"
    assert_selector "form.verification-form"
  end

  test "navbar Verify Queue shows count badge when provisional observations exist" do
    sign_in @user
    visit root_path

    provisional_count = Observation.provisional.count
    assert provisional_count.positive?, "Test requires at least one provisional observation"

    # Should show the count in the badge
    within("nav") do
      assert_selector "span", text: provisional_count.to_s
    end
  end
end
