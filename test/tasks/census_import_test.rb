# frozen_string_literal: true

require "test_helper"
require "rake"

class CensusImportTest < ActiveSupport::TestCase
  setup do
    # Load rake tasks if not already loaded
    Rails.application.load_tasks unless Rake::Task.task_defined?("census:import")

    # Set test API key
    ENV["CENSUS_API_KEY"] = "test_api_key_12345"
  end

  teardown do
    ENV.delete("CENSUS_API_KEY")
  end

  # ==========================================
  # MAPPING FILE TESTS
  # ==========================================

  test "FIPS mapping file exists and is valid YAML" do
    fips_file = Rails.root.join("db/seeds/census_data/entity_fips_mapping.yml")
    assert File.exist?(fips_file), "FIPS mapping file should exist"

    mapping = YAML.load_file(fips_file)
    assert mapping["cities"].present?, "Should have cities section"
    assert mapping["nyc"].present?, "Should have nyc section"
  end

  test "FIPS mapping includes all fixture entities" do
    fips_file = Rails.root.join("db/seeds/census_data/entity_fips_mapping.yml")
    mapping = YAML.load_file(fips_file)

    # Check that our fixture entities are in the mapping
    assert mapping["cities"]["Yonkers"].present?, "Yonkers should be in FIPS mapping"
    assert mapping["cities"]["New Rochelle"].present?, "New Rochelle should be in FIPS mapping"
    assert mapping["cities"]["Albany"].present?, "Albany should be in FIPS mapping"
  end

  test "FIPS codes are 5-digit strings" do
    fips_file = Rails.root.join("db/seeds/census_data/entity_fips_mapping.yml")
    mapping = YAML.load_file(fips_file)

    mapping["cities"].each do |city, fips|
      assert_match(/^\d{5}$/, fips, "FIPS code for #{city} should be 5 digits: #{fips}")
    end

    mapping["nyc"].each do |city, fips|
      assert_match(/^\d{5}$/, fips, "FIPS code for #{city} should be 5 digits: #{fips}")
    end
  end

  # ==========================================
  # METRIC DEFINITIONS TESTS
  # ==========================================

  test "metric definitions file exists and is valid YAML" do
    metrics_file = Rails.root.join("db/seeds/census_data/metric_definitions.yml")
    assert File.exist?(metrics_file), "Metric definitions file should exist"

    definitions = YAML.load_file(metrics_file)
    assert definitions["metrics"].present?, "Should have metrics section"
    assert definitions["available_years"].present?, "Should have available_years section"
  end

  test "metric definitions have required fields" do
    metrics_file = Rails.root.join("db/seeds/census_data/metric_definitions.yml")
    definitions = YAML.load_file(metrics_file)

    definitions["metrics"].each do |var_code, definition|
      assert definition["label"].present?, "#{var_code} should have label"
      assert definition["description"].present?, "#{var_code} should have description"
      assert definition["display_format"].present?, "#{var_code} should have display_format"
      assert definition["category"].present?, "#{var_code} should have category"

      # Validate display_format is valid
      valid_formats = Metric::VALID_DISPLAY_FORMATS
      assert_includes valid_formats, definition["display_format"],
                      "#{var_code} display_format '#{definition['display_format']}' should be valid"
    end
  end

  test "available years are reasonable" do
    metrics_file = Rails.root.join("db/seeds/census_data/metric_definitions.yml")
    definitions = YAML.load_file(metrics_file)

    years = definitions["available_years"]
    assert years.is_a?(Array), "available_years should be an array"
    assert years.all? { |y| y.is_a?(Integer) && y >= 2010 && y <= 2030 },
           "Years should be integers in reasonable range"
  end

  # ==========================================
  # IMPORTER CLASS TESTS
  # ==========================================

  test "importer initializes with mapping data" do
    importer = CensusImporter.new(dry_run: true)

    assert importer.dry_run
    assert_equal 0, importer.stats[:observations_created]
    assert_empty importer.errors
  end

  test "importer validates API key presence" do
    ENV.delete("CENSUS_API_KEY")

    importer = CensusImporter.new(dry_run: true)

    # Should abort when trying to import without API key
    assert_raises(SystemExit) do
      capture_io { importer.import(year: 2023) }
    end
  end

  test "importer finds entities by FIPS code" do
    importer = CensusImporter.new(dry_run: true)

    # Use reflection to test the private method
    yonkers = importer.send(:find_entity_by_fips, "84000")
    assert_equal entities(:yonkers), yonkers

    new_rochelle = importer.send(:find_entity_by_fips, "50617")
    assert_equal entities(:new_rochelle), new_rochelle

    # Unknown FIPS should return nil
    unknown = importer.send(:find_entity_by_fips, "99999")
    assert_nil unknown
  end

  test "importer identifies suppressed values" do
    importer = CensusImporter.new(dry_run: true)

    # Suppressed values should be identified
    assert importer.send(:suppressed_value?, "-666666666")
    assert importer.send(:suppressed_value?, "-999999999")
    assert importer.send(:suppressed_value?, "-888888888")
    assert importer.send(:suppressed_value?, nil)
    assert importer.send(:suppressed_value?, "")

    # Valid values should not be suppressed
    assert_not importer.send(:suppressed_value?, "12345")
    assert_not importer.send(:suppressed_value?, "0")
    assert_not importer.send(:suppressed_value?, "209827.5")
  end

  # ==========================================
  # METRIC CREATION TESTS
  # ==========================================

  test "importer creates metrics with correct attributes" do
    importer = CensusImporter.new(dry_run: false)

    # Create a metric
    metric = importer.send(:find_or_create_metric, "B01003_001E")

    assert metric.persisted?
    assert_equal "census_b01003_001e", metric.key
    assert_equal "Total Population", metric.label
    assert_equal "census", metric.data_source
    assert_equal "numeric", metric.value_type
    assert_equal "integer", metric.display_format
  end

  test "importer reuses existing metrics" do
    importer = CensusImporter.new(dry_run: false)

    # Create metric first time
    metric1 = importer.send(:find_or_create_metric, "B01003_001E")

    # Create again - should return same metric
    metric2 = importer.send(:find_or_create_metric, "B01003_001E")

    assert_equal metric1.id, metric2.id
  end

  # ==========================================
  # DOCUMENT CREATION TESTS
  # ==========================================

  test "importer creates documents with correct attributes" do
    importer = CensusImporter.new(dry_run: false)

    document = importer.send(:find_or_create_document, entities(:yonkers), 2023,
                             "https://api.census.gov/data/2023/acs/acs5")

    assert document.persisted?
    assert_equal "Yonkers Census ACS 5-Year Estimates 2023", document.title
    assert_equal "us_census_acs5", document.doc_type
    assert_equal 2023, document.fiscal_year
    assert_equal "bulk_data", document.source_type
    assert_equal entities(:yonkers), document.entity
  end

  test "importer enforces document uniqueness" do
    importer = CensusImporter.new(dry_run: false)

    # Create document first time
    doc1 = importer.send(:find_or_create_document, entities(:yonkers), 2023,
                         "https://api.census.gov/data/2023/acs/acs5")

    # Create again - should return same document
    doc2 = importer.send(:find_or_create_document, entities(:yonkers), 2023,
                         "https://api.census.gov/data/2023/acs/acs5")

    assert_equal doc1.id, doc2.id
  end

  # ==========================================
  # OBSERVATION CREATION TESTS
  # ==========================================

  test "importer creates observations with correct attributes" do
    importer = CensusImporter.new(dry_run: false)

    entity = entities(:yonkers)
    metric = importer.send(:find_or_create_metric, "B01003_001E")
    document = importer.send(:find_or_create_document, entity, 2023,
                             "https://api.census.gov/data/2023/acs/acs5")

    # Create observation
    importer.send(:create_observation, entity, metric, document, 209_827.0, 2023)

    observation = Observation.find_by(entity: entity, metric: metric, fiscal_year: 2023)
    assert observation.present?
    assert_equal 209_827.0, observation.value_numeric
    assert_equal "verified", observation.verification_status
    assert_equal document, observation.document
  end

  test "importer updates observations when value changes" do
    importer = CensusImporter.new(dry_run: false)

    entity = entities(:yonkers)
    metric = importer.send(:find_or_create_metric, "B01003_001E")
    document = importer.send(:find_or_create_document, entity, 2023,
                             "https://api.census.gov/data/2023/acs/acs5")

    # Create observation
    importer.send(:create_observation, entity, metric, document, 209_827.0, 2023)
    assert_equal 1, importer.stats[:observations_created]

    # Update with new value
    importer.send(:create_observation, entity, metric, document, 210_000.0, 2023)
    assert_equal 1, importer.stats[:observations_updated]

    # Verify value changed
    observation = Observation.find_by(entity: entity, metric: metric, fiscal_year: 2023)
    assert_equal 210_000.0, observation.value_numeric
  end

  test "importer skips observation when value unchanged" do
    importer = CensusImporter.new(dry_run: false)

    entity = entities(:yonkers)
    metric = importer.send(:find_or_create_metric, "B01003_001E")
    document = importer.send(:find_or_create_document, entity, 2023,
                             "https://api.census.gov/data/2023/acs/acs5")

    # Create observation
    importer.send(:create_observation, entity, metric, document, 209_827.0, 2023)
    assert_equal 1, importer.stats[:observations_created]

    # Try to create again with same value
    importer.send(:create_observation, entity, metric, document, 209_827.0, 2023)
    assert_equal 1, importer.stats[:observations_unchanged]
  end

  # ==========================================
  # RAKE TASK TESTS
  # ==========================================

  test "census:preview task exists" do
    assert Rake::Task.task_defined?("census:preview"),
           "census:preview rake task should exist"
  end

  test "census:import task exists" do
    assert Rake::Task.task_defined?("census:import"),
           "census:import rake task should exist"
  end

  test "census:import_year task exists" do
    assert Rake::Task.task_defined?("census:import_year"),
           "census:import_year rake task should exist"
  end
end
