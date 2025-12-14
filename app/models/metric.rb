class Metric < ApplicationRecord
  has_paper_trail
  has_many :observations
  validates :key, :label, presence: true
  validates :key, uniqueness: true
end