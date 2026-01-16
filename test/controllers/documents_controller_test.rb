# frozen_string_literal: true

require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Fixtures
    @entity = entities(:yonkers)
    @document = documents(:yonkers_acfr_fy2024)
    @user = users(:one) # 1. Define the user from fixtures

    # 1. SETUP FOR READ TESTS: Attach a fake PDF to the fixture
    # This ensures the "View PDF" button appears in the 'show' test.
    @document.file.attach(
      io: StringIO.new("%PDF-1.4 fake content"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
  end

  # ==========================================
  # PUBLIC ACTIONS (Index, Show)
  # No Authentication Required
  # ==========================================

  test "should get index without auth" do
    get documents_url
    assert_response :success

    assert_select "h1", "Documents"
    assert_select "table"
    # Ensure the document we setup is listed
    assert_select "td a", text: @document.title
  end

  test "should show document hub with pdf link" do
    get document_url(@document)
    assert_response :success

    # Metadata Check
    assert_select "h1", @document.title
    assert_select "a[href=?]", @document.source_url

    # VERIFY PDF ACCESS:
    # Checks that a link to the ActiveStorage blob exists
    assert_select "a[target='_blank']", text: "Download PDF"
  end

  # ==========================================
  # ADMIN ACTIONS (New, Create)
  # Authentication Required
  # ==========================================

  test "should deny access to new without auth" do
    get new_document_url
    assert_redirected_to new_user_session_url
  end

  test "should get new with auth" do
    sign_in @user # CHANGE: Use helper
    get new_document_url
    assert_response :success
  end

  test "should create document with file" do
    sign_in @user

    assert_difference("Document.count") do
      post documents_url,
           params: {
             document: {
               title: "Test Budget",
               doc_type: "budget",
               fiscal_year: 2025,
               entity_id: @entity.id,
               source_url: "http://example.com",
               # fixture_file_upload looks for files in test/fixtures/files/
               file: fixture_file_upload("sample.pdf", "application/pdf")
             }
           }
    end

    assert_redirected_to document_url(Document.last)
    # Verify the file is actually attached
    assert Document.last.file.attached?
  end

  test "should fail to create document with invalid file" do
    sign_in @user

    assert_no_difference("Document.count") do
      post documents_url,
           params: {
             document: {
               title: "Bad File Test",
               doc_type: "budget",
               fiscal_year: 2025,
               entity_id: @entity.id,
               file: fixture_file_upload("sample.txt", "text/plain")
             }
           }
    end

    assert_response :unprocessable_entity
  end
end
