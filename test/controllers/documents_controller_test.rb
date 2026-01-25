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

  # ==========================================
  # FILTER TESTS
  # ==========================================

  test "index renders filter form" do
    get documents_url
    assert_response :success
    assert_select "form[method='get'][action='#{documents_path}']"
    assert_select "fieldset legend", text: "Filters"
  end

  test "index filters by doc_type" do
    get documents_url(doc_type: "acfr")
    assert_response :success
    # Check for link with document title (td contains title + Source Link)
    assert_select "td a", text: @document.title
  end

  test "index filters by fiscal_year" do
    get documents_url(fiscal_year: 2024)
    assert_response :success
    assert_select "tbody tr", minimum: 1
  end

  test "index filters by entity_id" do
    get documents_url(entity_id: @entity.id)
    assert_response :success
    # Should see Yonkers documents - check for link with document title
    assert_select "td a", text: @document.title
  end

  test "index filter preserves sort params" do
    get documents_url(doc_type: "acfr", sort: "title", direction: "desc")
    assert_response :success
    assert_select "input[type='hidden'][name='sort'][value='title']"
    assert_select "input[type='hidden'][name='direction'][value='desc']"
  end

  test "index filter form has Clear before Apply" do
    get documents_url
    assert_response :success
    assert_match(/Clear.*Apply/m, response.body)
  end

  # ==========================================
  # CUSTOM DOC_TYPE INPUT TESTS
  # ==========================================

  test "new form shows text input with datalist for doc_type" do
    sign_in @user
    get new_document_url
    assert_response :success
    assert_select "input[name='document[doc_type]'][list='doc_type_suggestions']"
    assert_select "datalist#doc_type_suggestions option", minimum: 1
  end

  test "edit form shows text input with datalist for doc_type" do
    sign_in @user
    get edit_document_url(@document)
    assert_response :success
    assert_select "input[name='document[doc_type]'][list='doc_type_suggestions']"
  end

  test "create accepts custom doc_type value" do
    sign_in @user

    assert_difference("Document.count") do
      post documents_url, params: {
        document: {
          title: "Custom Type Doc",
          doc_type: "quarterly_report",
          fiscal_year: 2025,
          entity_id: @entity.id,
          source_url: "https://example.com/report.pdf"
        }
      }
    end

    assert_equal "quarterly_report", Document.last.doc_type
  end

  # ==========================================
  # SOURCE_TYPE TESTS
  # ==========================================

  test "new form shows source_type select" do
    sign_in @user
    get new_document_url
    assert_response :success
    assert_select "select[name='document[source_type]']"
    assert_select "select[name='document[source_type]'] option[value='pdf']"
    assert_select "select[name='document[source_type]'] option[value='web']"
  end

  test "edit form shows source_type select with current value" do
    sign_in @user
    get edit_document_url(@document)
    assert_response :success
    assert_select "select[name='document[source_type]']"
  end

  test "create pdf document with source_type" do
    sign_in @user

    assert_difference("Document.count") do
      post documents_url, params: {
        document: {
          title: "PDF Source Doc",
          doc_type: "acfr",
          source_type: "pdf",
          fiscal_year: 2025,
          entity_id: @entity.id,
          source_url: "https://example.com/doc.pdf",
          file: fixture_file_upload("sample.pdf", "application/pdf")
        }
      }
    end

    new_doc = Document.last
    assert_equal "pdf", new_doc.source_type
    assert new_doc.file.attached?
  end

  test "create web document with source_type" do
    sign_in @user

    assert_difference("Document.count") do
      post documents_url, params: {
        document: {
          title: "Web Source Doc",
          doc_type: "census_data",
          source_type: "web",
          fiscal_year: 2025,
          entity_id: @entity.id,
          source_url: "https://data.census.gov/some-data"
        }
      }
    end

    new_doc = Document.last
    assert_equal "web", new_doc.source_type
    assert_not new_doc.file.attached?
  end

  test "create web document fails if file is attached" do
    sign_in @user

    assert_no_difference("Document.count") do
      post documents_url, params: {
        document: {
          title: "Invalid Web Doc",
          doc_type: "census_data",
          source_type: "web",
          fiscal_year: 2025,
          entity_id: @entity.id,
          source_url: "https://example.com/data",
          file: fixture_file_upload("sample.pdf", "application/pdf")
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "index filters by source_type" do
    get documents_url(source_type: "web")
    assert_response :success
    # Should see web documents (census)
    assert_select "td a", text: documents(:yonkers_census_data_fy2024).title
  end

  test "index filter includes source_type dropdown" do
    get documents_url
    assert_response :success
    assert_select "select[name='source_type']"
  end

  test "show displays source_type badge for pdf document" do
    get document_url(@document)
    assert_response :success
    assert_select ".source-type-badge", text: /PDF/i
  end

  test "show displays source_type badge for web document" do
    web_doc = documents(:yonkers_census_data_fy2024)
    get document_url(web_doc)
    assert_response :success
    assert_select ".source-type-badge", text: /Web/i
  end

  # ==========================================
  # DELETE TESTS
  # ==========================================

  test "should deny access to destroy without auth" do
    assert_no_difference("Document.count") do
      delete document_url(@document)
    end
    assert_redirected_to new_user_session_url
  end

  test "should destroy document with auth" do
    sign_in @user

    assert_difference("Document.count", -1) do
      delete document_url(@document)
    end

    assert_redirected_to documents_url
    follow_redirect!
    assert_select ".flash--notice", /deleted/i
  end

  test "show page has delete button when signed in" do
    sign_in @user
    get document_url(@document)
    assert_response :success
    assert_select "button", text: /Delete/i
  end

  test "show page does not have delete button when signed out" do
    get document_url(@document)
    assert_response :success
    assert_select "button", text: /Delete/i, count: 0
  end
end
