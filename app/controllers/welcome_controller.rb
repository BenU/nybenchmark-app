# frozen_string_literal: true

class WelcomeController < ApplicationController
  include CityRankings

  def index
    load_city_rankings
  end

  def for_llms
    render plain: render_to_string(template: "welcome/for_llms", formats: [:text])
  end
end
