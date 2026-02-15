# frozen_string_literal: true

require "test_helper"

class SiteNavigationTest < ActionDispatch::IntegrationTest
  test "layout has semantic header and footer with navigation (signed out)" do
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

        # Public menu links
        assert_select "a[href=?]", entities_path, text: "Entities"
        assert_select "a[href=?]", entities_path(kind: "school_district"), text: "School Districts"
        assert_select "a[href=?]", school_districts_compare_path, text: "Compare Districts"
        assert_select "a[href=?]", counties_compare_path, text: "Compare Counties"
        assert_select "a[href=?]", non_filers_path, text: "Non-Filers"
        assert_select "a[href=?]", methodology_path, text: "Methodology"
        assert_select "a[href='https://nybenchmark.org'][target='_blank'][rel='noopener']", text: "Blog"

        # Admin links should NOT be visible when signed out
        assert_select "a", text: "Documents", count: 0
        assert_select "a", text: "Metrics", count: 0

        # Auth links should NOT be visible when signed out
        assert_select "a", text: "Sign in", count: 0
        assert_select "a", text: "Sign up", count: 0
        assert_select "button", text: "Sign out", count: 0
      end
    end

    # 2. Semantic Footer Check
    assert_select "body > footer.container", count: 1 do
      assert_select "small", text: /NY Benchmark/
      assert_select "small", text: /#{Time.current.year}/
      # Footer should contain admin navigation links
      assert_select "a[href=?]", observations_path, text: "Observations"
      assert_select "a[href=?]", documents_path, text: "Documents"
      assert_select "a[href=?]", metrics_path, text: "Metrics"
      assert_select "a[href=?]", methodology_path, text: "Methodology"
      # Footer should NOT link to source code (repo is private)
      assert_select "a", text: "Source Code", count: 0
      assert_select "a[href*='github.com/BenU/nybenchmark-app']", count: 0
    end
  end

  test "navbar shows admin links + sign out when signed in" do
    sign_in users(:one)

    get entities_url
    assert_response :success

    assert_select "body > header.container nav" do
      # Admin links visible when signed in
      assert_select "a[href=?]", documents_path, text: "Documents"
      assert_select "a[href=?]", metrics_path, text: "Metrics"

      assert_select "span.secondary", text: users(:one).email

      assert_select "form[action=?]", destroy_user_session_path do
        assert_select "button", text: "Sign out"
      end

      assert_select "a", text: "Sign in", count: 0
      assert_select "a", text: "Sign up", count: 0
    end
  end
end
