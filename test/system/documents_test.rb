# frozen_string_literal: true

# test/system/documents_test.rb
require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  setup do
    @document = documents(:yonkers_acfr_fy2024) # Using fixture from sources.csv logic
  end

  test "show page sanitizes unsafe javascript links" do
    # ARRANGE: Bypass model validation to simulate a compromised DB record
    @document.source_url = "javascript:alert('XSS')"
    @document.save!(validate: false)

    # ACT
    visit document_path(@document)

    # ASSERT
    # We want to ensure the dangerous link is NOT clickable
    assert_no_selector "a[href^='javascript:']"

    # Optional: Check that the text is still visible (but not linked)
    assert_text "javascript:alert('XSS')"
  end
end
