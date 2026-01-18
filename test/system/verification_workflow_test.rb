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
end
