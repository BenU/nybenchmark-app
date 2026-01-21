# frozen_string_literal: true

require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
    @entity = entities(:yonkers)
  end

  test "visiting the index" do
    visit documents_path
    assert_selector "h1", text: "Documents"
  end

  test "navigation: creating a new document from index" do
    visit documents_path

    assert_selector "h1", text: "Documents"

    assert_link "New document"
    click_on "New document"

    assert_selector "h1", text: "New Document"
    assert_current_path new_document_path
  end

  test "uploading a new Document" do
    visit new_document_path

    # Form Filling
    fill_in "Title", with: "Yonkers 2025 Budget"
    select "Yonkers", from: "Entity"
    select "Budget", from: "Document Type" # Assuming we titleize the options
    fill_in "Fiscal year", with: "2025"
    fill_in "Source URL", with: "https://example.com/budget.pdf"

    # File Upload (relies on a dummy file existing in fixtures/files)
    # Rails usually provides a 'files' directory in fixtures.
    # We will create a dummy file on the fly if needed, but system tests
    # look in test/fixtures/files/ by default.
    attach_file "Upload PDF", Rails.root.join("test/fixtures/files/sample.pdf")

    click_on "Create Document"

    assert_text "Document uploaded successfully"
    assert_text "Yonkers 2025 Budget"

    # Verify the link to the file exists (ActiveStorage)
    assert_selector "a", text: "Download PDF"
  end

  test "editing a Document" do
    document = documents(:yonkers_acfr_fy2024)
    visit document_path(document)

    click_on "Update Document"

    fill_in "Notes", with: "Updated notes about this audit."
    click_on "Update Document"

    assert_text "Document was successfully updated"
    assert_text "Updated notes about this audit."
  end

  test "show page sanitizes unsafe javascript links" do
    # Using the existing test logic you had
    document = documents(:yonkers_acfr_fy2024)

    # Bypass validation to simulate compromised data
    # rubocop:disable Rails/SkipsModelValidations
    document.update_columns(source_url: "javascript:alert('XSS')")
    # rubocop:enable Rails/SkipsModelValidations

    visit document_path(document)
    assert_no_selector "a[href^='javascript:']"
    # ASSERT: The text might still be visible (optional, based on view logic)
    assert_text "(Link disabled for security)"
  end

  # ==========================================
  # AUTHORIZATION: EDIT LINK VISIBILITY
  # ==========================================

  test "signed in user sees edit links on document index" do
    # User is already signed in from setup
    visit documents_path

    # Should see Edit links
    assert_link "Edit"
    assert_link "New document"
  end

  test "guest does not see edit links on document index" do
    sign_out @user
    visit documents_path

    # Should NOT see Edit links
    assert_no_link "Edit"
    assert_no_link "New document"

    # But should still see View links
    assert_link "View"
  end
end
