# frozen_string_literal: true

require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    document = documents(:yonkers_acfr_fy2024)
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
    document = documents(:yonkers_acfr_fy2024)
    document.entity = nil
    assert_not document.valid?
    assert_includes document.errors[:entity], "must exist"
  end

  test "can attach a valid pdf" do
    document = documents(:yonkers_acfr_fy2024)
    document.file.attach(
      io: Rails.root.join("test/fixtures/files/sample.pdf").open,
      filename: "sample.pdf",
      content_type: "application/pdf"
    )
    assert document.valid?
    assert document.file.attached?
  end

  test "rejects non-pdf files" do
    document = documents(:yonkers_acfr_fy2024)
    document.file.attach(
      io: Rails.root.join("test/fixtures/files/sample.txt").open,
      filename: "sample.txt",
      content_type: "text/plain"
    )

    assert_not document.valid?
    assert_includes document.errors[:file], "must be a PDF"
  end

  test "rejects large files" do
    document = documents(:yonkers_acfr_fy2024)
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
    # 'yonkers_schools_budget_fy2024' is already defined in fixtures as a 2024 budget
    existing_doc = documents(:yonkers_schools_budget_fy2024)

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
    existing_doc = documents(:yonkers_schools_budget_fy2024)

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
      doc = Document.new(title: "Valid", doc_type: "budget", fiscal_year: 2024, entity: entities(:yonkers),
                         source_url: url)
      doc.validate
      assert_empty doc.errors[:source_url], "Expected #{url} to be valid"
    end

    # 2. Assert Invalid URLs fail
    invalid_urls.each do |url|
      doc = Document.new(title: "Invalid", doc_type: "budget", fiscal_year: 2024, entity: entities(:yonkers),
                         source_url: url)
      doc.validate
      assert_includes doc.errors[:source_url], "must be a valid HTTP/HTTPS URL", "Expected #{url} to fail validation"
    end
  end

  # ==========================================
  # for_entity scope - parent document inheritance
  # ==========================================

  test "for_entity returns documents for the specified entity" do
    yonkers = entities(:yonkers)
    docs = Document.for_entity(yonkers.id)

    assert_includes docs, documents(:yonkers_acfr_fy2024)
    assert_includes docs, documents(:yonkers_census_data_fy2024)
    # Should NOT include child entity documents
    assert_not_includes docs, documents(:yonkers_schools_budget_fy2024)
  end

  test "for_entity includes parent entity documents for dependent entities" do
    yonkers_schools = entities(:yonkers_schools)
    docs = Document.for_entity(yonkers_schools.id)

    # Should include own documents
    assert_includes docs, documents(:yonkers_schools_budget_fy2024)
    # Should ALSO include parent (Yonkers) documents
    assert_includes docs, documents(:yonkers_acfr_fy2024)
    assert_includes docs, documents(:yonkers_census_data_fy2024)
  end

  test "for_entity does not include parent documents for independent entities" do
    # new_rochelle_schools has no parent (independent school district)
    new_rochelle_schools = entities(:new_rochelle_schools)
    docs = Document.for_entity(new_rochelle_schools.id)

    # Should include own documents
    assert_includes docs, documents(:new_rochelle_schools_audit_fy2024)
    # Should NOT include city documents (no parent relationship)
    assert_not_includes docs, documents(:new_rochelle_acfr_fy2024)
  end

  test "for_entity returns none for nil entity_id" do
    assert_empty Document.for_entity(nil)
  end

  test "for_entity returns none for non-existent entity_id" do
    assert_empty Document.for_entity(999_999)
  end

  test "for_entity orders by fiscal_year desc then title asc" do
    yonkers_schools = entities(:yonkers_schools)
    docs = Document.for_entity(yonkers_schools.id)

    # Should be ordered by fiscal_year desc, then title asc
    fiscal_years = docs.pluck(:fiscal_year)
    assert_equal fiscal_years, fiscal_years.sort.reverse
  end

  test "can handle both url-only and url-with-pdf scenarios" do
    # Scenario 1: URL Only (e.g. Reference to a website)
    doc_url_only = Document.create!(
      title: "Website Only",
      doc_type: "budget",
      fiscal_year: 2021,
      entity: entities(:new_rochelle),
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
      entity: entities(:yonkers_schools),
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

  # ==========================================
  # SOURCE_TYPE ENUM TESTS
  # ==========================================

  test "source_type defaults to pdf" do
    doc = Document.new
    assert_equal "pdf", doc.source_type
    assert doc.pdf?
  end

  test "source_type can be set to web" do
    doc = Document.new(source_type: :web)
    assert_equal "web", doc.source_type
    assert doc.web?
  end

  test "source_type enum provides pdf? and web? helper methods" do
    pdf_doc = Document.new(source_type: :pdf)
    web_doc = Document.new(source_type: :web)

    assert pdf_doc.pdf?
    assert_not pdf_doc.web?
    assert web_doc.web?
    assert_not web_doc.pdf?
  end

  test "web source_type does not allow file attachment" do
    doc = documents(:yonkers_census_data_fy2024)
    doc.source_type = :web

    doc.file.attach(
      io: StringIO.new("fake pdf content"),
      filename: "should_not_attach.pdf",
      content_type: "application/pdf"
    )

    assert_not doc.valid?
    assert_includes doc.errors[:file], "cannot be attached to web sources"
  end

  test "pdf source_type allows file attachment" do
    doc = documents(:yonkers_acfr_fy2024)
    doc.source_type = :pdf

    doc.file.attach(
      io: Rails.root.join("test/fixtures/files/sample.pdf").open,
      filename: "valid.pdf",
      content_type: "application/pdf"
    )

    assert doc.valid?
  end

  test "web source requires source_url" do
    doc = Document.new(
      title: "Web Source",
      doc_type: "census_data",
      fiscal_year: 2024,
      entity: entities(:yonkers),
      source_type: :web,
      source_url: nil
    )

    assert_not doc.valid?
    assert_includes doc.errors[:source_url], "can't be blank"
  end

  test "Document.pdf scope returns only pdf source_type documents" do
    pdf_docs = Document.pdf
    pdf_docs.each do |doc|
      assert doc.pdf?, "Expected #{doc.title} to be pdf source_type"
    end
  end

  test "Document.web scope returns only web source_type documents" do
    web_docs = Document.web
    web_docs.each do |doc|
      assert doc.web?, "Expected #{doc.title} to be web source_type"
    end
  end

  test "for_entity includes both pdf and web source documents" do
    yonkers = entities(:yonkers)
    docs = Document.for_entity(yonkers.id)

    # Should include PDF documents
    assert_includes docs, documents(:yonkers_acfr_fy2024)
    # Should include web documents
    assert_includes docs, documents(:yonkers_census_data_fy2024)
  end
end
