# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Auditing: Track who is responsible for changes
  before_action :set_paper_trail_whodunnit

  # Safety rail: any non-GET/HEAD request (i.e., anything that can mutate) requires authentication.
  # Keeps browsing public by default.
  before_action :authenticate_user!, if: :authentication_required_for_mutation?

  private

  def authentication_required_for_mutation?
    return false if devise_controller?
    return false if request.get? || request.head?

    true
  end
end
