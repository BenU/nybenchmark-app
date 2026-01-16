# frozen_string_literal: true

require "test_helper"

class ObservationsControllerTest < ActionDispatch::IntegrationTest
  test "index renders observations with audit fields (document + page_reference)" do
    get observations_url
    assert_response :success

    assert_select "nav a", text: "Observations"
    assert_select "h1", text: "Observations"
    assert_select "table"

    # Traceability must be visible
    assert_select "tbody", text: /City of Yonkers ACFR 2024/
    assert_select "tbody", text: /p\. 45/
    assert_select "tbody", text: /City of New Rochelle ACFR 2024/
    assert_select "tbody", text: /p\. 12/
  end

  test "index filters by entity_id" do
    yonkers = entities(:yonkers)

    get observations_url(entity_id: yonkers.id)
    assert_response :success

    assert_select "tbody tr", count: 1
    assert_select 'tbody td[data-column="entity"]', text: "Yonkers"
  end

  test "index filters by metric_id" do
    revenue = metrics(:revenue)

    get observations_url(metric_id: revenue.id)
    assert_response :success

    assert_select "tbody tr", count: 1
    assert_select 'tbody td[data-column="metric"]', /Total General Fund Revenue/
    assert_select 'tbody td[data-column="metric"]', /total_revenue/
  end

  test "index filters by document_id" do
    doc = documents(:yonkers_acfr_fy2024)

    get observations_url(document_id: doc.id)
    assert_response :success

    assert_select "tbody tr", count: 1
    assert_select 'tbody td[data-column="document"]', text: "City of Yonkers ACFR 2024"
  end

  test "index filters by fiscal_year" do
    yonkers = entities(:yonkers)
    metric = metrics(:expenditures)

    doc_fy2023 = Document.create!(
      entity: yonkers,
      title: "City of Yonkers ACFR 2023",
      doc_type: "acfr",
      fiscal_year: 2023,
      source_url: "https://example.com/yonkers-acfr-2023.pdf"
    )

    Observation.create!(
      entity: yonkers,
      metric: metric,
      document: doc_fy2023,
      fiscal_year: 2023,
      value_numeric: 1.0,
      page_reference: "p. 1"
    )

    get observations_url(fiscal_year: 2023)
    assert_response :success

    assert_select "tbody tr", count: 1
    assert_select 'tbody td[data-column="fiscal-year"]', text: "2023"
  end

  test "index free-text searches entity name, metric key/label, and document title" do
    get observations_url(q: "New Rochelle")
    assert_response :success
    assert_select "tbody tr", count: 2

    get observations_url(q: "total_revenue")
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select 'tbody td[data-column="metric"]', /total_revenue/

    get observations_url(q: "Schools Budget")
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select 'tbody td[data-column="document"]', /Yonkers Public Schools Budget 2024/
  end

  test "index sorts by updated_at desc by default" do
    Time.use_zone("UTC") do
      timestamps = {
        yonkers_expenditures_numeric: Time.zone.local(2025, 1, 1, 12, 0, 0),
        new_rochelle_revenue_text: Time.zone.local(2025, 1, 3, 12, 0, 0),
        yonkers_schools_metric_one: Time.zone.local(2025, 1, 2, 12, 0, 0),
        new_rochelle_schools_text_two: Time.zone.local(2025, 1, 1, 13, 0, 0)
      }

      timestamps.each do |fixture_key, timestamp|
        observations(fixture_key).update!(updated_at: timestamp)
      end
    end

    get observations_url
    assert_response :success

    first_entity = css_select('tbody tr:first-child td[data-column="entity"]').text.strip
    assert_equal "New Rochelle", first_entity
  end

  test "index sorts by fiscal_year desc when requested" do
    yonkers = entities(:yonkers)
    metric = metrics(:expenditures)

    doc_fy2023 = Document.create!(
      entity: yonkers,
      title: "City of Yonkers ACFR 2023",
      doc_type: "acfr",
      fiscal_year: 2023,
      source_url: "https://example.com/yonkers-acfr-2023.pdf"
    )

    Observation.create!(
      entity: yonkers,
      metric: metric,
      document: doc_fy2023,
      fiscal_year: 2023,
      value_numeric: 1.0,
      page_reference: "p. 1"
    )

    get observations_url(sort: "fiscal_year_desc")
    assert_response :success

    years = css_select('tbody td[data-column="fiscal-year"]').map { |n| n.text.to_i }
    assert_equal years.sort.reverse, years
  end

  test "index sorts by entity name asc when requested" do
    get observations_url(sort: "entity_name_asc")
    assert_response :success

    names = css_select('tbody td[data-column="entity"]').map(&:text)
    assert_equal names.sort, names
  end

  test "index paginates results (50 per page)" do
    yonkers = entities(:yonkers)

    doc_fy2025 = Document.create!(
      entity: yonkers,
      title: "City of Yonkers ACFR 2025",
      doc_type: "acfr",
      fiscal_year: 2025,
      source_url: "https://example.com/yonkers-acfr-2025.pdf"
    )

    30.times do |i|
      metric = Metric.create!(key: "auto_metric_#{i}", label: "Auto Metric #{i}")
      Observation.create!(
        entity: yonkers,
        metric: metric,
        document: doc_fy2025,
        fiscal_year: 2025,
        value_numeric: i.to_f,
        page_reference: "p. 1"
      )
    end

    get observations_url
    assert_response :success
    assert_select "tbody tr", count: 20

    get observations_url(page: 2)
    assert_response :success
    assert_select "tbody tr", count: 14
  end

  test "show renders observation details with source traceability" do
    obs = observations(:yonkers_expenditures_numeric)

    get observation_url(obs)
    assert_response :success

    assert_match(/Yonkers/, @response.body)
    assert_match(/Slug:\s*yonkers/i, @response.body)
    assert_match(/Total General Fund Expenditures/, @response.body)
    assert_match(/total_expenditures/, @response.body)
    assert_match(/\bUSD\b/, @response.body)

    assert_match(/\b2024\b/, @response.body)

    # Value and traceability
    assert_match(/105000000/, @response.body)
    assert_match(/City of Yonkers ACFR 2024/, @response.body)
    assert_match(/p\. 45/, @response.body)
    assert_match(%r{https://example\.com/yonkers-acfr-2024\.pdf}, @response.body)
  end
end
