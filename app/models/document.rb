class Document < ApplicationRecord
  has_paper_trail
  belongs_to :entity
  has_many :observations
  validates :title, :doc_type, :fiscal_year, :source_url, presence: true
end
