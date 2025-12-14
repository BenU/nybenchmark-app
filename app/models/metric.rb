# frozen_string_literal: true

class Metric < ApplicationRecord
  has_paper_trail
  has_many :observations, dependent: :restrict_with_error
  validates :key, :label, presence: true
  validates :key, uniqueness: true
end
