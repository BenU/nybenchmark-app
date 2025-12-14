class Entity < ApplicationRecord
  has_paper_trail
  has_many :documents
  has_many :observations
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end
