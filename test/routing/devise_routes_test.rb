# frozen_string_literal: true

require "test_helper"

class DeviseRoutesTest < ActionDispatch::IntegrationTest
  test "devise URL helpers are unscoped (no /users prefix)" do
    assert_equal "/sign_in", new_user_session_path
    assert_equal "/sign_up", new_user_registration_path
    assert_equal "/sign_out", destroy_user_session_path

    # A representative “non-session” Devise route to ensure *all* Devise routes are unscoped
    assert_equal "/password/new", new_user_password_path

    # Old paths should not be recognized anymore
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/users/sign_in", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/users/sign_up", method: :get)
    end
  end

  test "no Devise controller routes start with /users" do
    devise_routes = Rails.application.routes.routes.select do |route|
      route.defaults[:controller]&.start_with?("devise/")
    end

    assert devise_routes.any?, "Expected to find Devise routes, found none"

    offending = devise_routes
                .map { |r| r.path.spec.to_s }
                .select { |path| path.start_with?("/users") }

    assert_empty offending, "Expected no Devise routes to start with /users, found:\n#{offending.join("\n")}"
  end
end
