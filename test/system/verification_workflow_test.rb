# frozen_string_literal: true

require "application_system_test_case"

class VerificationWorkflowTest < ApplicationSystemTestCase
  include PdfTestHelper

  setup do
    @user = users(:one)
    sign_in @user

    # Start with a known provisional fixture
    @observation = observations(:new_rochelle_revenue_text)

    # Dynamically find what the database thinks is "Next"
    # This prevents the test from breaking if fixture IDs shuffle
    @expected_next = @observation.next_provisional_observation

    # Attach a PDF to the document fixture so the viewer loads
    @document = @observation.document
    attach_sample_pdf(@document)
  end

  test "verification cockpit layout and workflow" do
    visit verify_observation_path(@observation)

    # 1. Assert Split Screen Layout - PDF.js canvas-based viewer
    assert_selector "[data-pdf-navigator-target='canvas']"
    assert_selector "form.verification-form"
    assert_text "Verify:"
    assert_text "Provisional"

    # 2. Assert PDF.js toolbar elements
    assert_selector "[data-pdf-navigator-target='pageDisplay']"
    assert_selector "[data-pdf-navigator-target='totalPages']"
    assert_selector "[data-pdf-navigator-target='zoomSelect']"
    assert_button "Capture"

    # 3. Verify & Next Workflow
    fill_in "Text", with: ""
    fill_in "Numeric", with: "999.99"
    fill_in "PDF Page:", with: "42"
    select "Verified", from: "Status"

    click_button "Verify & Next"

    # 4. Assert Logic
    # Should redirect to the NEXT provisional observation found earlier
    assert_current_path verify_observation_path(@expected_next)

    assert_text "Observation verified. Find next item below..."

    # Check that the original observation was updated
    @observation.reload
    assert_equal "verified", @observation.verification_status
    assert_equal 42, @observation.pdf_page
    assert_equal 999.99, @observation.value_numeric
  end

  test "verification cockpit shows PDF viewer and navigator only when PDF is attached" do
    visit verify_observation_path(@observation)

    # PDF is attached in setup, so PDF.js viewer should be visible
    assert_selector "[data-pdf-navigator-target='canvas']"
    assert_field "PDF Page:"
    assert_text "Click PDF or Capture"
  end

  test "verification cockpit hides PDF viewer for URL-only documents" do
    # Use the URL-only fixture (no PDF attached by design)
    url_only_obs = observations(:yonkers_population_url_only)

    # Sanity check: this fixture should have no PDF
    assert_not url_only_obs.document.file.attached?, "Fixture should be URL-only"
    assert_nil url_only_obs.pdf_page, "URL-only observation should have nil pdf_page"

    visit verify_observation_path(url_only_obs)

    # Should show the URL fallback message
    assert_text "No PDF attached"
    assert_link "Open Source URL"

    # PDF Navigator input should NOT be visible
    assert_no_field "PDF Page:"
    assert_no_text "Type to navigate PDF"
  end

  test "verification cockpit PDF Navigator has min validation" do
    visit verify_observation_path(@observation)

    # The number field should have min="1" attribute
    page_input = find_field("PDF Page:")
    assert_equal "1", page_input[:min], "PDF page input should have min=1 validation"
  end

  # ==========================================
  # PDF.js VIEWER TESTS
  # ==========================================

  test "PDF viewer toolbar has navigation buttons" do
    visit verify_observation_path(@observation)

    # Check prev/next buttons exist with correct actions
    assert_selector "button[data-action='pdf-navigator#previousPage']"
    assert_selector "button[data-action='pdf-navigator#nextPage']"
  end

  test "PDF viewer toolbar has zoom dropdown with correct options" do
    visit verify_observation_path(@observation)

    zoom_select = find("[data-pdf-navigator-target='zoomSelect']")

    # Check zoom options are present
    assert zoom_select.has_css?("option[value='fit-width']")
    assert zoom_select.has_css?("option[value='fit-page']")
    assert zoom_select.has_css?("option[value='0.5']")
    assert zoom_select.has_css?("option[value='1']")
    assert zoom_select.has_css?("option[value='2']")
  end

  test "Capture Page button populates form field" do
    visit verify_observation_path(@observation)

    # Wait for PDF to load (loading indicator should get hidden class)
    wait_for_pdf_load

    # Clear the existing page value
    fill_in "PDF Page:", with: ""

    # Click the Capture Page button
    click_button "Capture"

    # The page input should now have the current page value
    page_input = find_field("PDF Page:")
    assert_not_empty page_input.value, "Capture Page should populate the form field"
  end

  test "PDF viewer has correct data attributes from observation" do
    visit verify_observation_path(@observation)

    # Find the controller element
    controller_element = find("[data-controller='pdf-navigator']")

    # Check the initial page value is set from the observation
    assert_equal @observation.pdf_page.to_s, controller_element["data-pdf-navigator-initial-page-value"]

    # Check the URL value is present (we can't check exact URL as it's signed)
    assert controller_element["data-pdf-navigator-url-value"].present?
  end

  test "PDF viewer canvas has click-to-capture action" do
    visit verify_observation_path(@observation)

    canvas = find("[data-pdf-navigator-target='canvas']")

    # Verify canvas has the click action wired up
    assert_equal "click->pdf-navigator#canvasClicked", canvas["data-action"]
  end

  test "PDF viewer has loading indicator" do
    visit verify_observation_path(@observation)

    # Loading indicator should exist (may or may not be visible depending on timing)
    assert_selector "[data-pdf-navigator-target='loading']", visible: :all
  end

  test "PDF viewer has error display element" do
    visit verify_observation_path(@observation)

    # Error element should exist (hidden by default, so use visible: :all)
    assert_selector "[data-pdf-navigator-target='error']", visible: :all
  end

  # ==========================================
  # SKIP & NEXT WORKFLOW
  # ==========================================

  test "verification cockpit has Skip & Next button" do
    visit verify_observation_path(@observation)

    assert_button "Skip"
  end

  test "Skip & Next saves changes and moves to next without verifying" do
    visit verify_observation_path(@observation)

    # Make some changes
    fill_in "Text", with: ""
    fill_in "Numeric", with: "555.55"
    fill_in "PDF Page:", with: "77"

    # Click Skip & Next (don't change status)
    click_button "Skip"

    # Should redirect to next provisional observation
    assert_current_path verify_observation_path(@expected_next)
    assert_text "Saved. Skipped to next item"

    # Verify the original observation was saved but NOT verified
    @observation.reload
    assert_equal "provisional", @observation.verification_status, "Status should remain provisional"
    assert_equal 77, @observation.pdf_page
    assert_equal 555.55, @observation.value_numeric
  end

  private

  def wait_for_pdf_load(timeout: 10)
    start_time = Time.current
    loading_el = find("[data-pdf-navigator-target='loading']", visible: :all)

    loop do
      break if loading_el[:class]&.include?("hidden")

      raise "PDF did not load within #{timeout} seconds" if Time.current - start_time > timeout

      sleep 0.1
    end
  end
end
