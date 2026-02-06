# frozen_string_literal: true

require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "landing page headline stats are dynamically computed from the database" do
    get root_url
    assert_response :success

    assert_select ".landing-hero h1", "NY Benchmark"
    assert_select ".landing-stat", minimum: 4

    assert_select ".landing-stat" do |stats|
      stat_map = stats.each_with_object({}) do |stat, hash|
        label = stat.css(".landing-stat-label").text
        value = stat.css(".landing-stat-value").text
        hash[label] = value
      end

      assert_equal Entity.where(kind: :city).count.to_s, stat_map["Cities"]
      assert_equal Entity.school_districts.count.to_s, stat_map["School Districts"]
      assert_equal Observation.distinct.count(:fiscal_year).to_s, stat_map["Years of Data"]
      assert_equal "#{Observation.count / 1000}K+", stat_map["Data Points"]
    end
  end

  test "landing page tagline reflects broader data coverage" do
    get root_url
    assert_response :success

    # Tagline should mention local governments, not just cities
    assert_select ".landing-hero p", text: /local governments/i
  end

  test "landing page shows explore cities button" do
    get root_url
    assert_response :success

    assert_select "a[role='button']", text: "Explore Cities"
  end

  test "landing page renders rankings when data exists" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select ".rankings-grid"
    assert_select ".ranking-card", minimum: 1
    assert_select "h2", text: "City Rankings"
  end

  test "landing page works gracefully with no data" do
    get root_url
    assert_response :success
    assert_select ".landing-hero"
  end

  test "landing page shows about section" do
    get root_url
    assert_response :success

    assert_select "article", text: /Nonpartisan, evidence-based/
  end

  # ==========================================
  # YEAR SELECTION TESTS
  # ==========================================

  test "rankings use the most recent year with broad coverage, not sparse newer year" do
    expenditure_metric = metrics(:police_personal_services)
    fund_balance_metric = metrics(:unassigned_fund_balance)

    # Create 30 cities with 2024 data (broad coverage)
    30.times do |i|
      entity = Entity.create!(name: "City #{i}", kind: :city, state: "NY", slug: "city-yr-#{i}")
      doc = Document.create!(
        entity: entity, title: "OSC #{entity.name} 2024", doc_type: "osc_afr",
        fiscal_year: 2024, source_type: :bulk_data, source_url: "https://example.com/#{i}"
      )
      Observation.create!(
        entity: entity, document: doc, metric: expenditure_metric,
        fiscal_year: 2024, value_numeric: (i + 1) * 10_000_000
      )
      Observation.create!(
        entity: entity, document: doc, metric: fund_balance_metric,
        fiscal_year: 2024, value_numeric: (i + 1) * 1_000_000
      )
    end

    # Create 5 cities with 2025 data (sparse — early filers)
    5.times do |i|
      entity = Entity.find_by(slug: "city-yr-#{i}")
      doc = Document.create!(
        entity: entity, title: "OSC #{entity.name} 2025", doc_type: "osc_afr",
        fiscal_year: 2025, source_type: :bulk_data, source_url: "https://example.com/#{i}-2025"
      )
      Observation.create!(
        entity: entity, document: doc, metric: expenditure_metric,
        fiscal_year: 2025, value_numeric: (i + 1) * 10_000_000
      )
      Observation.create!(
        entity: entity, document: doc, metric: fund_balance_metric,
        fiscal_year: 2025, value_numeric: (i + 1) * 1_000_000
      )
    end

    get root_url
    assert_response :success

    # Should use FY 2024 (30 cities), not FY 2025 (5 cities)
    assert_select "p", text: /Based on FY 2024/
  end

  # ==========================================
  # RANKING TOP/BOTTOM 10 CORRECTNESS TESTS
  # ==========================================

  test "ranking cards show Top 10 and Bottom 10 toggle buttons" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select ".ranking-toggle-group", minimum: 1
    assert_select "button.ranking-toggle", text: "Top 10", minimum: 1
    assert_select "button.ranking-toggle", text: "Bottom 10", minimum: 1
  end

  test "top 10 shows highest values first (descending)" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select "tbody[data-ranking-toggle-target='topBody']" do |top_bodies|
      top_bodies.each do |body|
        values = extract_numeric_values(body)
        next if values.size < 2

        values.each_cons(2) do |a, b|
          assert a >= b,
                 "Top 10 values should be descending (best first), but #{a} < #{b}"
        end
      end
    end
  end

  test "top 10 contains at most 10 rows" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select "tbody[data-ranking-toggle-target='topBody']" do |top_bodies|
      top_bodies.each do |body|
        rows = body.css("tr")
        assert rows.size <= 10,
               "Top 10 should have at most 10 rows, got #{rows.size}"
      end
    end
  end

  test "bottom 10 shows lowest values first (ascending)" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select "tbody[data-ranking-toggle-target='bottomBody']" do |bottom_bodies|
      bottom_bodies.each do |body|
        values = extract_numeric_values(body)
        next if values.size < 2

        values.each_cons(2) do |a, b|
          assert a <= b,
                 "Bottom 10 values should be ascending (worst first), but #{a} > #{b}"
        end
      end
    end
  end

  test "bottom 10 contains at most 10 rows" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select "tbody[data-ranking-toggle-target='bottomBody']" do |bottom_bodies|
      bottom_bodies.each do |body|
        rows = body.css("tr")
        assert rows.size <= 10,
               "Bottom 10 should have at most 10 rows, got #{rows.size}"
      end
    end
  end

  test "bottom 10 rows are numbered 1 through N" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select "tbody[data-ranking-toggle-target='bottomBody']" do |bottom_bodies|
      bottom_bodies.each do |body|
        rows = body.css("tr")
        next if rows.empty?

        ranks = rows.map { |row| row.css("td").first.text.strip.to_i }
        expected = (1..rows.size).to_a
        assert_equal expected, ranks,
                     "Bottom 10 should be numbered 1..#{rows.size}, got #{ranks}"
      end
    end
  end

  test "top 10 rows are numbered 1 through N" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select "tbody[data-ranking-toggle-target='topBody']" do |top_bodies|
      top_bodies.each do |body|
        rows = body.css("tr")
        next if rows.empty?

        ranks = rows.map { |row| row.css("td").first.text.strip.to_i }
        expected = (1..rows.size).to_a
        assert_equal expected, ranks,
                     "Top 10 should be numbered 1..#{rows.size}, got #{ranks}"
      end
    end
  end

  test "with more than 20 cities, top 10 and bottom 10 have no overlap" do
    create_ranking_cities(25)
    get root_url
    assert_response :success

    assert_select "article.ranking-card" do |cards|
      cards.each do |card|
        top_body = card.css("tbody[data-ranking-toggle-target='topBody']").first
        bottom_body = card.css("tbody[data-ranking-toggle-target='bottomBody']").first
        next unless top_body && bottom_body

        top_cities = top_body.css("td:nth-child(2) a").map(&:text)
        bottom_cities = bottom_body.css("td:nth-child(2) a").map(&:text)

        overlap = top_cities & bottom_cities
        assert_empty overlap,
                     "With 25 cities, no overlap expected but found: #{overlap.join(', ')}"
      end
    end
  end

  test "bottom 10 contains the lowest-ranked city" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    # City 0 has the smallest expenditures and fund balance — should appear in bottom 10
    assert_select "tbody[data-ranking-toggle-target='bottomBody']" do |bottom_bodies|
      bottom_bodies.each do |body|
        city_names = body.css("td:nth-child(2) a").map(&:text)
        # "Ranking City 0" has the lowest expenditure-based values
        assert_includes city_names, "Ranking City 0",
                        "Bottom 10 should include the lowest-ranked city"
      end
    end
  end

  test "top 10 contains the highest-ranked city" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    # City 14 has the largest expenditures and fund balance — should appear in top 10
    assert_select "tbody[data-ranking-toggle-target='topBody']" do |top_bodies|
      top_bodies.each do |body|
        city_names = body.css("td:nth-child(2) a").map(&:text)
        assert_includes city_names, "Ranking City 14",
                        "Top 10 should include the highest-ranked city"
      end
    end
  end

  # ==========================================
  # NON-FILER CALLOUT TESTS
  # ==========================================

  test "landing page shows non-filer callout when rankings are present" do
    create_ranking_cities(15)
    get root_url
    assert_response :success

    assert_select ".non-filer-callout"
    assert_select ".non-filer-callout a[href=?]", non_filers_path
  end

  # ==========================================
  # DATA QUALITY EXCLUSION TESTS
  # ==========================================

  test "rankings exclude TC-fund and interfund transfers from per-capita spending" do
    expenditure_metric = metrics(:police_personal_services) # fund_code: A, real spending
    tc_metric = metrics(:custodial_pass_through)            # fund_code: T, pass-through
    transfer_metric = metrics(:interfund_transfer_out)      # fund_code: A, "Other Uses"
    fund_balance_metric = metrics(:unassigned_fund_balance)
    population_metric = metrics(:census_population)

    year = 2024
    base_expenditures = 100_000_000
    tc_amount = 50_000_000
    transfer_amount = 20_000_000

    30.times do |i|
      entity = Entity.create!(name: "TC City #{i}", kind: :city, state: "NY", slug: "tc-city-#{i}")
      doc = Document.create!(
        entity: entity, title: "OSC #{entity.name} #{year}", doc_type: "osc_afr",
        fiscal_year: year, source_type: :bulk_data, source_url: "https://example.com/tc/#{i}"
      )

      # Real expenditure (included)
      Observation.create!(entity: entity, document: doc, metric: expenditure_metric,
                          fiscal_year: year, value_numeric: base_expenditures)
      # TC fund pass-through (excluded)
      Observation.create!(entity: entity, document: doc, metric: tc_metric,
                          fiscal_year: year, value_numeric: tc_amount)
      # Interfund transfer (excluded)
      Observation.create!(entity: entity, document: doc, metric: transfer_metric,
                          fiscal_year: year, value_numeric: transfer_amount)
      # Fund balance
      Observation.create!(entity: entity, document: doc, metric: fund_balance_metric,
                          fiscal_year: year, value_numeric: (i + 1) * 1_000_000)
      # Population
      Observation.create!(entity: entity, document: doc, metric: population_metric,
                          fiscal_year: year, value_numeric: 50_000)
    end

    get root_url
    assert_response :success

    # Per-capita should be $100M / 50K = $2,000
    # NOT ($100M + $50M + $20M) / 50K = $3,400
    assert_select "tbody td", text: /2,000/
    assert_select "tbody td", text: /3,400/, count: 0
  end

  # ==========================================
  # SITEMAP REDIRECT TEST
  # ==========================================

  test "sitemap path redirects to DO Spaces URL" do
    get "/sitemaps/sitemap.xml.gz"
    assert_response :redirect
    assert_redirected_to "https://nybenchmark-production.nyc3.digitaloceanspaces.com/sitemaps/sitemap.xml.gz"
  end

  private

  # Create N cities each with expenditure, fund balance, and debt service data.
  # Expenditures are held constant (100M) so that the fund balance % and debt service %
  # scale linearly with index: City 0 has 1% fund balance (weakest), City N-1 has N%
  # (strongest). This produces distinct, predictable rankings.
  def create_ranking_cities(count) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    expenditure_metric = metrics(:police_personal_services) # account_type: expenditure
    fund_balance_metric = metrics(:unassigned_fund_balance) # account_code: A917
    debt_service_metric = metrics(:debt_service_interest)   # level_1_category: Debt Service

    year = 2024
    base_expenditures = 100_000_000 # constant across all cities

    count.times do |i|
      entity = Entity.create!(
        name: "Ranking City #{i}",
        kind: :city,
        state: "NY",
        slug: "ranking-city-#{i}"
      )

      doc = Document.create!(
        entity: entity,
        title: "OSC AFR #{year}",
        doc_type: "osc_afr",
        fiscal_year: year,
        source_type: :bulk_data,
        source_url: "https://example.com/osc/#{entity.slug}"
      )

      # Fund balance: City 0 = 1M (1%), City 1 = 2M (2%), ..., City N-1 = N*M (N%)
      fund_balance_value = (i + 1) * 1_000_000

      # Debt service: City 0 = 1M (1%), City 1 = 2M (2%), etc.
      debt_service_value = (i + 1) * 1_000_000

      Observation.create!(
        entity: entity, document: doc, metric: expenditure_metric,
        fiscal_year: year, value_numeric: base_expenditures
      )
      Observation.create!(
        entity: entity, document: doc, metric: fund_balance_metric,
        fiscal_year: year, value_numeric: fund_balance_value
      )
      Observation.create!(
        entity: entity, document: doc, metric: debt_service_metric,
        fiscal_year: year, value_numeric: debt_service_value
      )
    end
  end

  def extract_numeric_values(body)
    body.css("td:nth-child(3)").map do |td|
      td.text.strip.gsub(/[$,%]/, "").to_f
    end
  end
end
