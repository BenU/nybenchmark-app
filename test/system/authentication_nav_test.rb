# frozen_string_literal: true

require "application_system_test_case"

class AuthenticationNavTest < ApplicationSystemTestCase
  include PdfTestHelper

  setup do
    @user = users(:one)

    # Attach PDF to a provisional observation with a PDF-type document
    # The verify queue may show PDF or URL-only documents, so we ensure
    # at least one PDF-type observation has its file attached for testing
    @pdf_provisional = Observation.provisional
                                  .joins(:document)
                                  .where(documents: { source_type: :pdf })
                                  .order(:id)
                                  .first
    attach_sample_pdf(@pdf_provisional.document) if @pdf_provisional
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

    # Should be on the verify cockpit page - always shows verification form
    # Wait for the page to fully load - use visible: :all since layout may vary
    assert_selector "form.verification-form", visible: :all

    # The cockpit shows either PDF viewer (for PDF documents) or URL fallback (for web sources)
    # Check that one of these is present
    has_pdf_viewer = page.has_selector?("[data-pdf-navigator-target='pagesContainer']", visible: :all, wait: 1)
    has_url_fallback = page.has_content?("No PDF attached.")
    assert has_pdf_viewer || has_url_fallback,
           "Expected either PDF viewer or URL-only fallback, but found neither"
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
