# frozen_string_literal: true

require "test_helper"

class SiteNavigationTest < ActionDispatch::IntegrationTest
  test "layout has semantic header and footer with navigation" do
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
          # Future links (Documents, Metrics) will go here
        end

        assert_select "li" do
          assert_select "a[href=?]", metrics_path, text: "Metrics"
        end
      end
    end

    # 2. Semantic Footer Check
    assert_select "body > footer.container", count: 1 do
      assert_select "small", text: /NY Benchmark/
      assert_select "small", text: /#{Time.current.year}/ # Dynamic year check
    end
  end
end
