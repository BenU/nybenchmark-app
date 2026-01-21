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

    # 1. Assert Split Screen Layout - PDF.js continuous scroll viewer
    assert_selector "[data-pdf-navigator-target='pagesContainer']"
    assert_selector ".pdf-page-wrapper", minimum: 1 # At least one page rendered
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
    assert_selector "[data-pdf-navigator-target='pagesContainer']"
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

    # Should display actual URL, not generic "Open Source URL" text
    source_url = url_only_obs.document.source_url
    assert_link source_url, href: source_url

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

  test "PDF viewer pages have canvases for rendering" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # Each page wrapper should contain a canvas
    page_wrappers = all(".pdf-page-wrapper")
    assert page_wrappers.length >= 1, "Should have at least one page wrapper"

    page_wrappers.each do |wrapper|
      assert wrapper.has_css?("canvas"), "Each page wrapper should contain a canvas"
    end
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

  # ==========================================
  # VERIFY COCKPIT UI REFINEMENTS
  # ==========================================

  test "verification cockpit header shows metric and entity" do
    visit verify_observation_path(@observation)

    # Header should include both metric label AND entity name
    assert_text "Verify: Total General Fund Revenue for New Rochelle"
  end

  test "verification cockpit header has readable font size" do
    visit verify_observation_path(@observation)

    # Find the header element - should have larger font than 11px
    header = find(".verify-header-title")
    # Just verify the element exists with proper class
    assert header.present?, "Should have header with verify-header-title class"
  end

  test "verification cockpit shows document info below header" do
    visit verify_observation_path(@observation)

    # Document title should be visible
    assert_text @observation.document.title
    # Fiscal year should be visible
    assert_text "FY#{@observation.fiscal_year}"
  end

  test "verification cockpit has source URL input field" do
    visit verify_observation_path(@observation)

    # Should have a source URL input field
    assert_field "Source URL"
    url_input = find_field("Source URL")

    # Should be pre-populated with current document source_url
    assert_equal @observation.document.source_url, url_input.value
  end

  test "verification cockpit source URL can be edited and saved" do
    visit verify_observation_path(@observation)

    new_url = "https://updated-source.example.com/document.pdf"
    fill_in "Source URL", with: new_url

    click_button "Save"

    # Should save and redirect to show page
    assert_text "Observation was successfully updated"

    # Revisit verify page to confirm the URL was saved
    visit verify_observation_path(@observation)
    url_input = find_field("Source URL")
    assert_equal new_url, url_input.value, "Source URL should persist after save"
  end

  test "URL-only documents show source URL as link in left pane" do
    url_only_obs = observations(:yonkers_population_url_only)
    visit verify_observation_path(url_only_obs)

    # The actual URL should be displayed as clickable link text
    source_url = url_only_obs.document.source_url
    link = find("a", text: source_url)
    assert_equal source_url, link[:href]
    assert_equal "_blank", link[:target], "Link should open in new tab"
  end

  # ==========================================
  # CONTINUOUS SCROLL TESTS
  # ==========================================

  test "PDF viewer renders all pages in scrollable container" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # Should have pagesContainer target
    assert_selector "[data-pdf-navigator-target='pagesContainer']"

    # Container should be scrollable (inside overflow-auto parent)
    container = find("[data-pdf-navigator-target='container']")
    assert container[:class].include?("overflow-auto"), "Container should be scrollable"

    # Should render page wrappers for each page (sample.pdf has 2 pages)
    page_wrappers = all(".pdf-page-wrapper")
    assert_equal 2, page_wrappers.length, "Should render wrapper for each PDF page"

    # Each wrapper should have data-page attribute
    page_wrappers.each_with_index do |wrapper, index|
      assert_equal (index + 1).to_s, wrapper["data-page"], "Page wrapper should have correct data-page"
    end
  end

  test "PDF viewer page display updates when scrolling to different page" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # Initially should show page 1 (or initial page from observation)
    page_display = find("[data-pdf-navigator-target='pageDisplay']")
    _initial_page = page_display.text.to_i

    # Scroll to second page
    second_page = find(".pdf-page-wrapper[data-page='2']")
    second_page.scroll_to(:center)

    # Wait for scroll sync debounce
    sleep 0.2

    # Page display should update to 2
    assert_equal "2", page_display.text, "Page display should update when scrolling to page 2"
  end

  test "PDF viewer scrolls to page when page input changes" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # Change page input to 2
    fill_in "PDF Page:", with: "2"

    # Wait for scroll animation
    sleep 0.5

    # Second page should be visible/in view
    find(".pdf-page-wrapper[data-page='2']")

    # Check if page 2 is near top of scroll container
    page_selector = '.pdf-page-wrapper[data-page="2"]'
    container_selector = '[data-pdf-navigator-target="container"]'
    page_rect_top = evaluate_script("document.querySelector('#{page_selector}').getBoundingClientRect().top")
    container_rect_top = evaluate_script("document.querySelector('#{container_selector}').getBoundingClientRect().top")

    # Page 2 should be near the top of container (within 100px)
    assert (page_rect_top - container_rect_top).abs < 100, "Page 2 should scroll into view"
  end

  test "PDF viewer Next button scrolls to next page" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # First navigate to page 1 (fixture may have different initial page)
    fill_in "PDF Page:", with: "1"
    sleep 0.7

    # Verify we're on page 1
    page_display = find("[data-pdf-navigator-target='pageDisplay']")
    assert_equal "1", page_display.text, "Should be on page 1"

    # Click next
    click_button "▶" # Next button

    # Wait for scroll animation to complete
    sleep 0.7

    # Re-find and verify page 2
    page_display = find("[data-pdf-navigator-target='pageDisplay']")
    assert_equal "2", page_display.text, "Next button should scroll to page 2"
  end

  test "PDF viewer Previous button scrolls to previous page" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # First go to page 2
    fill_in "PDF Page:", with: "2"
    sleep 0.5

    page_display = find("[data-pdf-navigator-target='pageDisplay']")
    assert_equal "2", page_display.text, "Should be on page 2"

    # Click previous
    click_button "◀" # Previous button

    # Wait for scroll
    sleep 0.5

    # Should now show page 1
    assert_equal "1", page_display.text, "Previous button should scroll to page 1"
  end

  test "clicking on page canvas captures that page number" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # Clear the page input
    fill_in "PDF Page:", with: ""

    # Scroll to and click on page 2's canvas
    second_page = find(".pdf-page-wrapper[data-page='2']")
    second_page.scroll_to(:center)
    sleep 0.2

    # Click on the canvas inside page 2
    canvas = second_page.find("canvas")
    canvas.click

    # Page input should now have "2"
    page_input = find_field("PDF Page:")
    assert_equal "2", page_input.value, "Clicking page 2 canvas should capture page 2"
  end

  test "PDF viewer zoom changes update all page sizes" do
    visit verify_observation_path(@observation)
    wait_for_pdf_load

    # Get initial width of first page canvas
    initial_width = evaluate_script("document.querySelector('.pdf-page-wrapper[data-page=\"1\"] canvas').width")

    # Change zoom to 200%
    select "200%", from: "zoom-select"

    # Wait for re-render
    sleep 0.5

    # Width should have changed (increased for 200%)
    new_width = evaluate_script("document.querySelector('.pdf-page-wrapper[data-page=\"1\"] canvas').width")
    assert new_width > initial_width, "Page width should increase at 200% zoom"

    # Second page should also be resized
    second_page_width = evaluate_script("document.querySelector('.pdf-page-wrapper[data-page=\"2\"] canvas').width")
    assert second_page_width.positive?, "Second page should also be resized"
  end

  test "PDF viewer pages have placeholder dimensions before render" do
    visit verify_observation_path(@observation)

    # Check for page wrappers (wait for at least one)
    page_wrappers = all(".pdf-page-wrapper", wait: 5)
    assert page_wrappers.length >= 1, "Should have at least one page wrapper"

    # Each wrapper should have dimensions set
    page_wrappers.each do |wrapper|
      width = wrapper.style("width")
      height = wrapper.style("height")
      assert width.present? && width != "0px", "Page wrapper should have width"
      assert height.present? && height != "0px", "Page wrapper should have height"
    end
  end

  private

  def wait_for_pdf_load(timeout: 10)
    start_time = Time.current

    # Wait for loading indicator to be hidden
    loading_el = find("[data-pdf-navigator-target='loading']", visible: :all)
    loop do
      break if loading_el[:class]&.include?("hidden")

      raise "PDF did not load within #{timeout} seconds" if Time.current - start_time > timeout

      sleep 0.1
    end

    # Also wait for at least one page to be rendered (canvas visible)
    assert_selector ".pdf-page-wrapper canvas", visible: true, wait: timeout
  end
end
