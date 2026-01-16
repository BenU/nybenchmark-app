# frozen_string_literal: true

require "test_helper"

class AuthenticationBoundariesTest < ActionDispatch::IntegrationTest
  setup do
    @headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
  end

  test "unauthenticated users are redirected to sign-in for mutation endpoints" do
    # --- DOCUMENTS ---
    get new_document_path, headers: @headers
    assert_redirected_to "/sign_in"

    post documents_path,
         params: { document: { title: "ignored" } },
         headers: @headers
    assert_redirected_to "/sign_in"

    get new_entity_path, headers: @headers
    assert_redirected_to "/sign_in"

    get new_metric_path, headers: @headers
    assert_redirected_to "/sign_in"
  end

  test "authenticated users can access mutation endpoints" do
    # Create a user manually for integration test speed
    user = User.create!(
      email: "tester@example.com",
      password: "password123",
      password_confirmation: "password123",
      approved: true
    )

    sign_in user

    get new_document_path, headers: @headers
    assert_response :success

    # Verify we can POST to documents
    base_doc = Document.order(:id).first
    file = Tempfile.new(["upload", ".pdf"])
    file.binmode
    file.write("%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n")
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "application/pdf")

    post documents_path,
         params: {
           document: {
             title: "Test Upload",
             doc_type: base_doc.doc_type,
             fiscal_year: 2099, # Ensure uniqueness
             entity_id: base_doc.entity_id,
             source_url: "https://example.com/source",
             notes: "test",
             file: uploaded
           }
         },
         headers: @headers

    assert_not_equal "/users/sign_in", response.location
  ensure
    file&.close
    file&.unlink
  end
end
