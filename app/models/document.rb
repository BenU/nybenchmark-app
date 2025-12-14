# frozen_string_literal: true

class Document < ApplicationRecord
  has_paper_trail
  belongs_to :entity
  has_many :observations, dependent: :destroy
  validates :title, :doc_type, :fiscal_year, :source_url, presence: true
end
