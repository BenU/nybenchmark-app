# frozen_string_literal: true

require "test_helper"

class ObservationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @observation = observations(:yonkers_expenditures_numeric)
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

  # --- Existing Tests (Preserved) ---
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

  # --- NEW: Verification Cockpit Tests ---

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
end
