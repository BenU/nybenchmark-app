# frozen_string_literal: true

require "application_system_test_case"

class VerificationWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user

    # Start with a known provisional fixture
    @observation = observations(:new_rochelle_revenue_text)

    # Dynamically find what the database thinks is "Next"
    # This prevents the test from breaking if fixture IDs shuffle
    @expected_next = @observation.next_provisional_observation

    # Attach a simulated PDF to the document fixture so the iframe loads
    @document = @observation.document
    unless @document.file.attached?
      @document.file.attach(
        io: StringIO.new("%PDF-1.4 simulated pdf content"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
    end
  end

  test "verification cockpit layout and workflow" do
    visit verify_observation_path(@observation)

    # 1. Assert Split Screen Layout
    assert_selector "iframe#pdf-viewer"
    assert_selector "form.verification-form"
    assert_text "Verification Cockpit"
    assert_text "Provisional"

    # 2. Test Stimulus PDF Navigator (Deep Linking)
    iframe = find("iframe#pdf-viewer")

    # Fixture has pdf_page: 12
    assert_match(/#page=12$/, iframe[:src])

    # Type a new page number
    fill_in "PDF Navigator Page (Absolute Index)", with: "42"
    find("body").click # Trigger blur/change event

    # Assert the iframe src updated
    assert_match(/#page=42$/, iframe[:src])

    fill_in "Value (Text - Optional)", with: ""

    # 3. Verify & Next Workflow
    fill_in "Value (Numeric)", with: "999.99"
    select "Verified", from: "Status"

    click_button "Verify & Next"

    # 4. Assert Logic
    # Should redirect to the NEXT provisional observation found earlier
    assert_current_path verify_observation_path(@expected_next)

    assert_text "Notice: Observation verified. Find next item below..."

    # Check that the original observation was updated
    @observation.reload
    assert_equal "verified", @observation.verification_status
    assert_equal 42, @observation.pdf_page
    assert_equal 999.99, @observation.value_numeric
  end

  test "verification cockpit shows PDF Navigator only when PDF is attached" do
    visit verify_observation_path(@observation)

    # PDF is attached in setup, so PDF Navigator should be visible
    assert_selector "iframe#pdf-viewer"
    assert_field "PDF Navigator Page (Absolute Index)"
    assert_text "Type a page number to jump the viewer instantly"
  end

  test "verification cockpit hides PDF Navigator for URL-only documents" do
    # Use the URL-only fixture (no PDF attached by design)
    url_only_obs = observations(:yonkers_population_url_only)

    # Sanity check: this fixture should have no PDF
    assert_not url_only_obs.document.file.attached?, "Fixture should be URL-only"
    assert_nil url_only_obs.pdf_page, "URL-only observation should have nil pdf_page"

    visit verify_observation_path(url_only_obs)

    # Should show the URL fallback message
    assert_text "No PDF attached to document"
    assert_link "Open Source URL"

    # PDF Navigator input should NOT be visible
    assert_no_field "PDF Navigator Page (Absolute Index)"
    assert_no_text "Type a page number to jump the viewer instantly"
  end

  test "verification cockpit PDF Navigator has min validation" do
    visit verify_observation_path(@observation)

    # The number field should have min="1" attribute
    page_input = find_field("PDF Navigator Page (Absolute Index)")
    assert_equal "1", page_input[:min], "PDF page input should have min=1 validation"
  end
end
