# frozen_string_literal: true

class Entity < ApplicationRecord
  has_paper_trail
  has_many :documents, dependent: :destroy
  has_many :observations, dependent: :destroy
  validates :name, presence: true
  validates :name, uniqueness: {
    scope: %i[state kind],
    message: "already exists for this type of entity in this state"
  }
  validates :slug, presence: true, uniqueness: true
end
