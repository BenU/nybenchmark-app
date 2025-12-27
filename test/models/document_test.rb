# frozen_string_literal: true

require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    document = documents(:nyc_budget)
    assert document.valid?
  end

  test "should require key fields" do
    document = Document.new
    assert_not document.valid?
    %i[title doc_type fiscal_year source_url].each do |field|
      assert_includes document.errors[field], "can't be blank"
    end
  end

  test "should belong to an entity" do
    document = documents(:nyc_budget)
    document.entity = nil
    assert_not document.valid?
    assert_includes document.errors[:entity], "must exist"
  end

  test "can attach a valid pdf" do
    document = documents(:nyc_budget)
    document.file.attach(
      io: Rails.root.join("test/fixtures/files/sample.pdf").open,
      filename: "sample.pdf",
      content_type: "application/pdf"
    )
    assert document.valid?
    assert document.file.attached?
  end

  test "rejects non-pdf files" do
    document = documents(:nyc_budget)
    document.file.attach(
      io: Rails.root.join("test/fixtures/files/sample.txt").open,
      filename: "sample.txt",
      content_type: "text/plain"
    )

    assert_not document.valid?
    assert_includes document.errors[:file], "must be a PDF"
  end

  test "rejects large files" do
    document = documents(:nyc_budget)
    document.file.attach(
      io: Rails.root.join("test/fixtures/files/sample.pdf").open,
      filename: "sample.pdf",
      content_type: "application/pdf"
    )

    # Simulate a 25MB file
    document.file.blob.byte_size = 25.megabytes

    assert_not document.valid?
    assert_includes document.errors[:file], "must be under 20MB"
  end

  test "should enforce uniqueness of doc_type per entity and fiscal_year" do
    # 'one' is already defined in fixtures as a 2024 budget
    existing_doc = documents(:one)

    # Try to build a duplicate (Same Entity + Same Year + Same Type)
    duplicate_doc = Document.new(
      entity: existing_doc.entity,
      title: "Duplicate Upload",
      doc_type: existing_doc.doc_type,
      fiscal_year: existing_doc.fiscal_year,
      source_url: "http://different-url.com"
    )

    # Should be invalid
    assert_not duplicate_doc.valid?
    assert_includes duplicate_doc.errors[:doc_type], "already exists for this entity and year"
  end

  test "should allow same doc_type for different years" do
    existing_doc = documents(:one)

    # Same Entity + Same Type + DIFFERENT Year
    new_year_doc = Document.new(
      entity: existing_doc.entity,
      title: "Next Year Budget",
      doc_type: existing_doc.doc_type,
      fiscal_year: existing_doc.fiscal_year + 1,
      source_url: "http://example.com/2025.pdf"
    )

    # Should be valid
    assert new_year_doc.valid?
  end

  test "should strictly validate source_url format" do
    valid_urls = [
      "http://example.com",
      "https://www.yonkersny.gov/file.pdf",
      "https://subdomain.example.co.uk/path?query=param",
      "https://127.0.0.1/document",
      " https://google.com "
    ]

    invalid_urls = [
      "Local PDF Import",      # Plain text
      "www.example.com",       # Missing protocol (http://)
      "ftp://example.com",     # Wrong protocol
      "http:example.com",      # Malformed
      "javascript:alert(1)",   # XSS vector
      "http://" # Missing host
    ]

    # 1. Assert Valid URLs pass
    valid_urls.each do |url|
      doc = Document.new(title: "Valid", doc_type: "budget", fiscal_year: 2024, entity: entities(:one), source_url: url)
      doc.validate
      assert_empty doc.errors[:source_url], "Expected #{url} to be valid"
    end

    # 2. Assert Invalid URLs fail
    invalid_urls.each do |url|
      doc = Document.new(title: "Invalid", doc_type: "budget", fiscal_year: 2024, entity: entities(:one),
                         source_url: url)
      doc.validate
      assert_includes doc.errors[:source_url], "must be a valid HTTP/HTTPS URL", "Expected #{url} to fail validation"
    end
  end

  test "can handle both url-only and url-with-pdf scenarios" do
    # Scenario 1: URL Only (e.g. Reference to a website)
    doc_url_only = Document.create!(
      title: "Website Only",
      doc_type: "budget",
      fiscal_year: 2021,
      entity: entities(:three),
      source_url: "https://example.com"
    )

    assert doc_url_only.persisted?
    assert_equal "https://example.com", doc_url_only.source_url
    assert_not doc_url_only.file.attached? # No PDF, perfectly valid

    # Scenario 2: URL + PDF (e.g. Audited File)
    doc_with_pdf = Document.new(
      title: "With PDF",
      doc_type: "acfr",
      fiscal_year: 2024,
      entity: entities(:two),
      source_url: "https://example.com/download"
    )

    # Attach the file (Simulating the seed script)
    doc_with_pdf.file.attach(
      io: StringIO.new("fake pdf content"),
      filename: "audit.pdf",
      content_type: "application/pdf"
    )
    doc_with_pdf.save!

    assert doc_with_pdf.persisted?
    assert doc_with_pdf.file.attached? # Has PDF
    assert_equal "audit.pdf", doc_with_pdf.file.filename.to_s # Filename stored in ActiveStorage
  end
end
