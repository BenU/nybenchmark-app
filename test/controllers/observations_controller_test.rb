# frozen_string_literal: true

require "test_helper"

class ObservationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @observation = observations(:yonkers_expenditures_numeric) # verified
    @provisional_obs = observations(:new_rochelle_revenue_text) # provisional
    @entity = entities(:yonkers)
    @metric = metrics(:expenditures)
    @document = documents(:yonkers_acfr_fy2024)

    # FIX for Failure C: Attach a fake PDF so the View renders the Iframe
    unless @document.file.attached?
      @document.file.attach(
        io: StringIO.new("%PDF-1.4 simulated content"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
    end
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

    # Should see the verified one
    assert_select "td", text: "105,000,000.0"

    # Should NOT see the provisional one
    assert_select "td", text: "Pending Audit", count: 0
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

    # Should see verified
    assert_select "td", text: "105,000,000.0"
    # Should ALSO see provisional
    assert_select "td", text: "Pending Audit"
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
    # This assertion now passes because we attached the file in setup
    assert_select "iframe#pdf-viewer"
    assert_select "form.verification-form"
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
    current_obs = observations(:new_rochelle_revenue_text)
    next_obs = current_obs.next_provisional_observation

    # Ensure current_obs document also has a file attached (for robustness)
    unless current_obs.document.file.attached?
      current_obs.document.file.attach(io: StringIO.new("pdf"), filename: "test.pdf", content_type: "application/pdf")
    end

    patch observation_url(current_obs), params: {
      commit_action: "verify_next",
      observation: {
        verification_status: "verified",
        value_numeric: 999,
        value_text: nil # FIX for Failure B: Explicitly clear text to pass Model Validation
      }
    }

    # 1. Assert Data Update
    current_obs.reload
    assert_equal "verified", current_obs.verification_status
    assert_equal 999, current_obs.value_numeric
    assert_nil current_obs.value_text

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
    # Should show PDF Page section
    assert_select "strong", text: "PDF Page"
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
    assert_select "strong", text: "PDF Page", count: 0
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
end
