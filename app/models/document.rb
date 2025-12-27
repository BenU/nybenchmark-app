# frozen_string_literal: true

class Document < ApplicationRecord
  has_paper_trail
  belongs_to :entity
  has_many :observations, dependent: :destroy
  has_one_attached :file

  validates :title, :doc_type, :fiscal_year, :source_url, presence: true

  normalizes :source_url, with: ->(url) { url.strip }
  validate :source_url_must_be_valid_http

  # Enforces that an entity can only have one document of a specific type per year.
  validates :doc_type, uniqueness: {
    scope: %i[entity_id fiscal_year],
    message: "already exists for this entity and year"
  }

  # Custom Security Validations
  validate :correct_file_type
  validate :correct_file_size

  private

  def correct_file_type
    return unless file.attached? && !file.content_type.in?(%w[application/pdf])

    errors.add(:file, "must be a PDF")
  end

  def correct_file_size
    return unless file.attached? && file.byte_size > 20.megabytes

    errors.add(:file, "must be under 20MB")
  end

  def source_url_must_be_valid_http
    # Allow blank if you want to support documents without online links yet
    return if source_url.blank?

    uri = URI.parse(source_url)

    # Check 1: Is it a generic URI?
    # Check 2: Is it specifically HTTP or HTTPS?
    # Check 3: Does it have a host (e.g. "google.com")?
    errors.add(:source_url, "must be a valid HTTP/HTTPS URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    # This catches "http:example" or characters not allowed in URLs
    errors.add(:source_url, "must be a valid HTTP/HTTPS URL")
  end
end
