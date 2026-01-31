# frozen_string_literal: true

require "test_helper"

class TrendChartHelperTest < ActionView::TestCase
  test "extends data to target year with nil fill" do
    data = { 2018 => 100, 2019 => 200, 2020 => 300 }
    result = extend_chart_data_to_year(data, 2024)

    assert_equal "2018", result.keys.first
    assert_equal "2024", result.keys.last
    assert_equal 7, result.size # 2018..2024
    assert_nil result["2021"]
    assert_nil result["2024"]
    assert_equal 300, result["2020"]
  end

  test "fills internal gaps within existing range" do
    data = { 2018 => 100, 2020 => 300 }
    result = extend_chart_data_to_year(data, 2024)

    assert_nil result["2019"]
    assert_equal "2018", result.keys.first
    assert_equal "2024", result.keys.last
  end

  test "does not shrink data if target year is before max" do
    data = { 2018 => 100, 2025 => 200 }
    result = extend_chart_data_to_year(data, 2024)

    assert_equal "2025", result.keys.last
  end

  test "returns string keys sorted for Chart.js category scale" do
    data = { 2020 => 300, 2018 => 100, 2019 => 200 }
    result = extend_chart_data_to_year(data, 2024)

    result.each_key { |k| assert_kind_of String, k, "Keys must be strings for Chart.js category scale" }
    assert_equal result.keys, result.keys.sort
  end

  test "first_year and last_year return the year range boundaries" do
    data = { 2018 => 100, 2019 => 200, 2020 => 300 }
    result = extend_chart_data_to_year(data, 2024)

    assert_equal "2018", chart_year_range(result).first
    assert_equal "2024", chart_year_range(result).last
  end

  test "chart_year_range returns nil pair for empty data" do
    result = chart_year_range({})
    assert_nil result.first
    assert_nil result.last
  end

  test "returns empty hash for empty data" do
    assert_equal({}, extend_chart_data_to_year({}, 2024))
  end

  test "returns original data unchanged when target year is nil" do
    data = { 2018 => 100, 2020 => 300 }
    result = extend_chart_data_to_year(data, nil)

    # Without a target year, just converts keys to strings and sorts
    assert_equal({ "2018" => 100, "2020" => 300 }, result)
  end
end
