# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# Helper module for attaching test PDFs to documents
module PdfTestHelper
  SAMPLE_PDF_PATH = Rails.root.join("test/fixtures/files/sample.pdf")

  def attach_sample_pdf(document)
    return if document.file.attached?

    document.file.attach(
      io: SAMPLE_PDF_PATH.open,
      filename: "test.pdf",
      content_type: "application/pdf"
    )
  end
end

module ActionDispatch
  class IntegrationTest
    # Make `sign_in` and `sign_out` available in controller/integration tests
    include Devise::Test::IntegrationHelpers
  end
end
