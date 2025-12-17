# frozen_string_literal: true

require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @entity = entities(:one)

    # 1. Define Test Credentials
    @username = "test_admin"
    @password = "test_password"

    # 2. Inject them into the Environment for this test run
    ENV["HTTP_AUTH_USER"] = @username
    ENV["HTTP_AUTH_PASSWORD"] = @password
  end

  test "should deny access to new without auth" do
    get new_document_url
    assert_response :unauthorized
  end

  test "should get new with auth" do
    auth_header = ActionController::HttpAuthentication::Basic.encode_credentials(@username, @password)
    get new_document_url, headers: { "Authorization" => auth_header }
    assert_response :success
  end

  test "should create document with file" do
    auth_header = ActionController::HttpAuthentication::Basic.encode_credentials(@username, @password)

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
           },
           headers: { "Authorization" => auth_header }
    end

    assert_redirected_to document_url
    # Verify the file is actually attached
    assert Document.last.file.attached?
  end

  test "should fail to create document with invalid file" do
    auth_header = ActionController::HttpAuthentication::Basic.encode_credentials(@username, @password)

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
           },
           headers: { "Authorization" => auth_header }
    end

    assert_response :unprocessable_entity
  end
end
