# frozen_string_literal: true

require "test_helper"

class ObservationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include PdfTestHelper

  setup do
    @user = users(:one)
    @observation = observations(:yonkers_expenditures_numeric) # verified
    @provisional_obs = observations(:new_rochelle_bond_rating_text) # provisional
    @entity = entities(:yonkers)
    @metric = metrics(:expenditures)
    @document = documents(:yonkers_acfr_fy2024)

    # Attach a real PDF so the PDF.js viewer can render
    attach_sample_pdf(@document)
  end

  test "index renders observations" do
    get observations_url
    assert_response :success
    assert_select "h1", text: "Observations"
  end

  test "index filters by entity_id" do
    get observations_url(entity_id: @entity.id)
    assert_response :success
    assert_select "tbody tr", count: 1
  end

  # ==========================================
  # GUEST RESTRICTIONS & VIEW LOGIC
  # ==========================================

  test "guest index sees ONLY verified observations" do
    get observations_url
    assert_response :success

    # Should see the verified one (formatted as currency)
    assert_select "td", text: "$105,000,000.00"

    # Should NOT see the provisional one (bond rating "Aa2")
    assert_select "td", text: "Aa2", count: 0
  end

  test "guest denies access to edit" do
    get edit_observation_url(@observation)
    assert_redirected_to new_user_session_url
  end

  test "guest denies access to verify cockpit" do
    get verify_observation_url(@observation)
    assert_redirected_to new_user_session_url
  end

  # ==========================================
  # USER ACCESS
  # ==========================================

  test "user index sees ALL observations (verified and provisional)" do
    sign_in @user
    get observations_url
    assert_response :success

    # Should see verified (formatted as currency)
    assert_select "td", text: "$105,000,000.00"
    # Should ALSO see provisional (bond rating "Aa2")
    assert_select "td", text: "Aa2"
  end

  test "user can access edit" do
    sign_in @user
    get edit_observation_url(@observation)
    assert_response :success
  end

  test "verify requires authentication" do
    get verify_observation_url(@observation)
    assert_redirected_to new_user_session_url
  end

  test "verify renders cockpit for authenticated user" do
    sign_in @user
    get verify_observation_url(@observation)

    assert_response :success
    # PDF.js continuous scroll viewer with pagesContainer
    assert_select "[data-pdf-navigator-target='pagesContainer']"
    assert_select "form.verification-form"
  end

  test "verify renders PDF.js toolbar controls" do
    sign_in @user
    get verify_observation_url(@observation)

    assert_response :success
    # Toolbar navigation buttons
    assert_select "button[data-action='pdf-navigator#previousPage']"
    assert_select "button[data-action='pdf-navigator#nextPage']"
    # Zoom dropdown
    assert_select "[data-pdf-navigator-target='zoomSelect']"
    # Capture button
    assert_select "button[data-action='pdf-navigator#captureCurrentPage']"
  end

  test "verify sets correct PDF.js data attributes" do
    sign_in @user
    get verify_observation_url(@observation)

    assert_response :success
    # Check data attributes are set on the controller element
    assert_select "[data-controller='pdf-navigator'][data-pdf-navigator-initial-page-value='#{@observation.pdf_page}']"
    assert_select "[data-controller='pdf-navigator'][data-pdf-navigator-url-value]"
  end

  test "create redirects DIRECTLY to verification cockpit" do
    sign_in @user

    assert_difference("Observation.count") do
      post observations_url, params: {
        observation: {
          entity_id: @entity.id,
          metric_id: @metric.id,
          document_id: @document.id,
          fiscal_year: 2024,
          value_numeric: 500,
          page_reference: "p. 99" # FIX for Failure A: Added required field
        }
      }
    end

    new_obs = Observation.order(created_at: :desc).first
    assert_redirected_to verify_observation_url(new_obs)
  end

  test "update with 'Verify & Next' redirects to next provisional item" do
    sign_in @user

    # Setup: Use a provisional item that has a 'next' item in the queue
    # bond_rating is a text metric, so update with value_text
    current_obs = observations(:new_rochelle_bond_rating_text)
    next_obs = current_obs.next_provisional_observation

    # Ensure current_obs document also has a file attached (for robustness)
    attach_sample_pdf(current_obs.document)

    patch observation_url(current_obs), params: {
      commit_action: "verify_next",
      observation: {
        verification_status: "verified",
        value_text: "Aa1",
        value_numeric: nil
      }
    }

    # 1. Assert Data Update
    current_obs.reload
    assert_equal "verified", current_obs.verification_status
    assert_equal "Aa1", current_obs.value_text
    assert_nil current_obs.value_numeric

    # 2. Assert Redirect to Next
    assert_redirected_to verify_observation_url(next_obs)
  end

  # ==========================================
  # PDF PAGE DISPLAY
  # ==========================================

  test "index displays pdf_page when present" do
    sign_in @user
    get observations_url

    assert_response :success
    # The yonkers_expenditures_numeric fixture has pdf_page: 45
    assert_select "th", text: "PDF Page"
    assert_select "td", text: "45"
  end

  test "show displays pdf_page when document has PDF attached" do
    sign_in @user
    get observation_url(@observation)

    assert_response :success
    # Should show PDF Page section (label includes "Absolute Index")
    assert_select "strong", text: "PDF Page (Absolute Index)"
    # The yonkers_expenditures_numeric fixture has pdf_page: 45
    assert_select "p", text: "45"
  end

  test "show does not display pdf_page section for URL-only documents" do
    # Use the URL-only fixture (no PDF attached by design)
    url_only_obs = observations(:yonkers_population_url_only)

    sign_in @user
    get observation_url(url_only_obs)

    assert_response :success
    # Should NOT show PDF Page section for URL-only documents
    assert_select "strong", text: "PDF Page (Absolute Index)", count: 0
  end

  test "show displays verify link for provisional observations when logged in" do
    sign_in @user
    get observation_url(@provisional_obs)

    assert_response :success
    # Look for verify link with correct href and text
    assert_select "a[href=?]", verify_observation_path(@provisional_obs), text: /Verify this observation/i
  end

  test "show does not display verify link for verified observations" do
    sign_in @user
    get observation_url(@observation) # @observation is verified

    assert_response :success
    # Should not have "Verify this observation" link for verified observations
    assert_select "a", text: /Verify this observation/i, count: 0
  end

  test "show does not display verify link for guests" do
    # Guest viewing a verified observation (guests can't see provisional)
    get observation_url(@observation)

    assert_response :success
    # Guests should not see "Verify this observation" link
    assert_select "a", text: /Verify this observation/i, count: 0
  end

  # ==========================================
  # PDF PAGE IN SHOW/EDIT
  # ==========================================

  test "show displays pdf_page with label when document has PDF attached" do
    sign_in @user
    get observation_url(@observation)

    assert_response :success
    assert_select "strong", text: "PDF Page (Absolute Index)"
  end

  test "show displays dash when pdf_page is nil" do
    sign_in @user
    # Create observation without pdf_page
    @observation.update!(pdf_page: nil)
    get observation_url(@observation)

    assert_response :success
    assert_select "strong", text: "PDF Page (Absolute Index)"
    # Should show em-dash for nil value
    assert_select "p", text: "—"
  end

  test "edit form shows pdf_page field when document has PDF attached" do
    sign_in @user
    get edit_observation_url(@observation)

    assert_response :success
    assert_select "label", text: "PDF Page (Absolute Index)"
    assert_select "input[name='observation[pdf_page]']"
  end

  test "edit form hides pdf_page field for URL-only documents" do
    url_only_obs = observations(:yonkers_population_url_only)

    sign_in @user
    get edit_observation_url(url_only_obs)

    assert_response :success
    assert_select "label", text: "PDF Page (Absolute Index)", count: 0
    assert_select "input[name='observation[pdf_page]']", count: 0
  end

  # ==========================================
  # SKIP & NEXT FUNCTIONALITY
  # ==========================================

  test "verify cockpit shows Skip & Next button" do
    sign_in @user
    get verify_observation_url(@observation)

    assert_response :success
    assert_select "button[value='skip_next']", text: "Skip"
  end

  test "update with 'Skip & Next' saves and redirects to next provisional without verifying" do
    sign_in @user

    # bond_rating is a text metric, so update with value_text
    current_obs = observations(:new_rochelle_bond_rating_text)
    next_obs = current_obs.next_provisional_observation
    attach_sample_pdf(current_obs.document)

    # Current status is provisional
    assert_equal "provisional", current_obs.verification_status

    patch observation_url(current_obs), params: {
      commit_action: "skip_next",
      observation: {
        pdf_page: 99,
        value_text: "Baa1",
        value_numeric: nil
      }
    }

    # 1. Assert Data Update but status unchanged
    current_obs.reload
    assert_equal "provisional", current_obs.verification_status, "Skip should NOT change verification status"
    assert_equal 99, current_obs.pdf_page
    assert_equal "Baa1", current_obs.value_text

    # 2. Assert Redirect to Next
    assert_redirected_to verify_observation_url(next_obs)
    follow_redirect!
    assert_match(/Saved. Skipped to next item/, flash[:notice])
  end

  test "update with 'Skip & Next' redirects to index when queue empty" do
    sign_in @user

    # Use the last provisional observation
    last_provisional = Observation.provisional.order(:id).last
    attach_sample_pdf(last_provisional.document)

    # Verify all other provisional observations first (respecting metric value types)
    Observation.provisional.where.not(id: last_provisional.id).find_each do |obs|
      if obs.metric.expects_numeric?
        obs.update!(verification_status: :verified, value_numeric: 1, value_text: nil)
      else
        obs.update!(verification_status: :verified, value_text: "verified", value_numeric: nil)
      end
    end

    # Update with correct value type for last provisional's metric
    if last_provisional.metric.expects_numeric?
      patch observation_url(last_provisional), params: {
        commit_action: "skip_next",
        observation: { value_numeric: 1, value_text: nil }
      }
    else
      patch observation_url(last_provisional), params: {
        commit_action: "skip_next",
        observation: { value_text: "skipped", value_numeric: nil }
      }
    end

    assert_redirected_to observations_path
    follow_redirect!
    assert_match(/No more provisional observations/, flash[:notice])
  end

  # ==========================================
  # VERIFY COCKPIT UI REFINEMENTS
  # ==========================================

  test "verify cockpit renders source URL input field" do
    sign_in @user
    get verify_observation_url(@observation)

    assert_response :success
    assert_select "input[name='observation[document_attributes][source_url]']"
    assert_select "label", text: /Source URL/
  end

  test "verify cockpit header shows metric and entity" do
    sign_in @user
    get verify_observation_url(@observation)

    assert_response :success
    # Header should show "Verify: {metric} for {entity}"
    assert_select ".verify-header-title", text: /Verify:.*for/
  end

  test "update saves document source_url via nested attributes" do
    sign_in @user

    new_url = "https://updated-source.example.com/new-document.pdf"
    original_url = @observation.document.source_url

    patch observation_url(@observation), params: {
      observation: {
        value_numeric: @observation.value_numeric,
        document_attributes: {
          id: @observation.document.id,
          source_url: new_url
        }
      }
    }

    assert_redirected_to observation_url(@observation)

    @observation.reload
    assert_equal new_url, @observation.document.source_url, "Document source_url should be updated"
    assert_not_equal original_url, @observation.document.source_url
  end
end
