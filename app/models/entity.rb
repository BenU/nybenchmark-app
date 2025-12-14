# frozen_string_literal: true

class Entity < ApplicationRecord
  has_paper_trail
  has_many :documents, dependent: :destroy
  has_many :observations, dependent: :destroy
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end
