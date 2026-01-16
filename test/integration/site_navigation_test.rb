# frozen_string_literal: true

require "test_helper"

class SiteNavigationTest < ActionDispatch::IntegrationTest
  test "layout has semantic header and footer with navigation (signed out)" do
    # specific target doesn't matter, provided it renders the application layout
    get entities_url
    assert_response :success

    # 1. Semantic Header Check (Pico.css structure)
    assert_select "body > header.container", count: 1 do
      assert_select "nav" do
        # Brand / Home Link
        assert_select "ul" do
          assert_select "li strong" do
            assert_select "a[href=?]", root_path, text: "NY Benchmark"
          end
        end

        # Menu Links
        assert_select "ul" do
          assert_select "li" do
            assert_select "a[href=?]", entities_path, text: "Entities"
          end
        end

        assert_select "li" do
          assert_select "a[href=?]", documents_path, text: "Documents"
        end

        assert_select "li" do
          assert_select "a[href=?]", metrics_path, text: "Metrics"
        end

        # Auth links (signed out)
        assert_select "a[href=?]", new_user_session_path, text: "Sign in"
        assert_select "a[href=?]", new_user_registration_path, text: "Sign up"
        assert_select "button", text: "Sign out", count: 0
      end
    end

    # 2. Semantic Footer Check
    assert_select "body > footer.container", count: 1 do
      assert_select "small", text: /NY Benchmark/
      assert_select "small", text: /#{Time.current.year}/ # Dynamic year check
    end
  end

  test "navbar shows sign out + email when signed in" do
    sign_in users(:one)

    get entities_url
    assert_response :success

    assert_select "body > header.container nav" do
      assert_select "span.secondary", text: users(:one).email

      assert_select "form[action=?]", destroy_user_session_path do
        assert_select "button", text: "Sign out"
      end

      assert_select "a", text: "Sign in", count: 0
      assert_select "a", text: "Sign up", count: 0
    end
  end
end
