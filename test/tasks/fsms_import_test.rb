# frozen_string_literal: true

require "test_helper"
require "rake"

class FsmsImportTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fsms:import")
  end

  # ==========================================
  # METRIC DEFINITIONS TESTS
  # ==========================================

  test "metric definitions file exists and is valid YAML" do
    definitions_file = Rails.root.join("db/seeds/fsms_data/metric_definitions.yml")
    assert File.exist?(definitions_file), "Metric definitions file should exist"

    definitions = YAML.load_file(definitions_file)
    assert definitions["composite"].present?, "Should have composite section"
    assert definitions["fiscal_indicators"].present?, "Should have fiscal_indicators section"
    assert definitions["environmental_indicators"].present?, "Should have environmental_indicators section"
  end

  test "composite metric definitions have required fields" do
    definitions_file = Rails.root.join("db/seeds/fsms_data/metric_definitions.yml")
    definitions = YAML.load_file(definitions_file)

    valid_value_types = %w[numeric text]
    definitions["composite"].each do |name, defn|
      assert defn["key"].present?, "#{name} should have key"
      assert defn["label"].present?, "#{name} should have label"
      assert defn["description"].present?, "#{name} should have description"
      assert defn["value_type"].present?, "#{name} should have value_type"
      assert valid_value_types.include?(defn["value_type"]), "#{name} value_type should be numeric or text"
    end
  end

  test "fiscal indicator definitions have required fields" do
    definitions_file = Rails.root.join("db/seeds/fsms_data/metric_definitions.yml")
    definitions = YAML.load_file(definitions_file)
    valid_formats = Metric::VALID_DISPLAY_FORMATS
    entity_types = %w[munis schools]

    entity_types.each do |entity_type|
      definitions["fiscal_indicators"][entity_type].each do |ind_name, defn|
        assert defn["key"].present?, "#{entity_type}/#{ind_name} should have key"
        assert defn["label"].present?, "#{entity_type}/#{ind_name} should have label"
        assert defn["display_format"].present?, "#{entity_type}/#{ind_name} should have display_format"

        assert_includes valid_formats, defn["display_format"],
                        "#{entity_type}/#{ind_name} display_format '#{defn['display_format']}' should be valid"
      end
    end
  end

  # ==========================================
  # IMPORTER CLASS TESTS
  # ==========================================

  test "importer initializes with correct defaults" do
    importer = FsmsImporter.new(dry_run: true)

    assert_equal 0, importer.stats[:observations_created]
    assert_empty importer.errors
  end

  test "importer finds entities by osc_municipal_code" do
    importer = FsmsImporter.new(dry_run: true)

    # Yonkers has osc_municipal_code "550262000000"
    entity = importer.send(:find_entity, "550262000000", "Yonkers", :muni)
    assert_equal entities(:yonkers), entity

    # Unknown municode should return nil and cache nil
    entity = importer.send(:find_entity, "999999999999", "Nonexistent City", :muni)
    assert_nil entity
  end

  test "importer caches entity lookups" do
    importer = FsmsImporter.new(dry_run: true)

    # First lookup
    entity1 = importer.send(:find_entity, "550262000000", "Yonkers", :muni)
    # Second lookup should hit cache
    entity2 = importer.send(:find_entity, "550262000000", "Yonkers", :muni)

    assert_equal entity1, entity2
  end

  test "importer detects file type from filename" do
    importer = FsmsImporter.new(dry_run: true)

    assert_equal :muni, importer.send(:file_type, "2024-munis-all-data-worksheet.xlsx")
    assert_equal :school, importer.send(:file_type, "2024-schools-all-data-worksheet.xlsx")
    assert_equal :school, importer.send(:file_type, "2019-school-all-data-workbook.xls")
  end

  test "importer extracts year from filename" do
    importer = FsmsImporter.new(dry_run: true)

    assert_equal 2024, importer.send(:file_year, "2024-munis-all-data-worksheet.xlsx")
    assert_equal 2012, importer.send(:file_year, "2012-munis-all-data-workbook.xls")
  end

  test "find_indicator_cols matches Ind N format" do
    importer = FsmsImporter.new(dry_run: true)

    headers = ["Name", "Class", "County", "Municode", "Region", "Coter-minous",
               "Ind 1", "Ind 2", "Ind 3", "Fiscal Score", "Type of Stress"]
    cols = importer.send(:find_indicator_cols, headers)

    assert_equal({ 1 => 6, 2 => 7, 3 => 8 }, cols)
  end

  test "find_indicator_cols_from_labels matches Indicator N format" do
    importer = FsmsImporter.new(dry_run: true)

    labels = ["", "", "", "", "", "Indicator 1", "Indicator 2", "Indicator 3",
              "Environmental Condition", "Total Score"]
    cols = importer.send(:find_indicator_cols_from_labels, labels)

    assert_equal({ 1 => 5, 2 => 6, 3 => 7 }, cols)
  end

  test "numeric_value? correctly identifies numeric values" do
    importer = FsmsImporter.new(dry_run: true)

    assert importer.send(:numeric_value?, 0)
    assert importer.send(:numeric_value?, 25.5)
    assert importer.send(:numeric_value?, 0.0)
    assert_not importer.send(:numeric_value?, "Not filed")
    assert_not importer.send(:numeric_value?, nil)
    assert_not importer.send(:numeric_value?, "")
  end

  # ==========================================
  # METRIC CREATION TESTS
  # ==========================================

  test "importer creates metrics with correct attributes" do
    importer = FsmsImporter.new(dry_run: false)

    metric = importer.send(:find_or_create_metric, "fsms_fiscal_score")

    assert metric.persisted?
    assert_equal "fsms_fiscal_score", metric.key
    assert_equal "FSMS Fiscal Score", metric.label
    assert_equal "fsms", metric.data_source
    assert_equal "numeric", metric.value_type
    assert_equal "decimal", metric.display_format
  end

  test "importer creates text metrics for designations" do
    importer = FsmsImporter.new(dry_run: false)

    metric = importer.send(:find_or_create_metric, "fsms_fiscal_stress_designation")

    assert metric.persisted?
    assert_equal "text", metric.value_type
  end

  test "importer reuses existing metrics" do
    importer = FsmsImporter.new(dry_run: false)

    metric1 = importer.send(:find_or_create_metric, "fsms_fiscal_score")
    metric2 = importer.send(:find_or_create_metric, "fsms_fiscal_score")

    assert_equal metric1.id, metric2.id
  end

  test "importer creates fiscal indicator metrics" do
    importer = FsmsImporter.new(dry_run: false)

    metric = importer.send(:find_or_create_metric, "fsms_muni_fiscal_ind1_points")

    assert metric.persisted?
    assert_equal "fsms", metric.data_source
    assert_equal "numeric", metric.value_type
    assert_equal "decimal", metric.display_format
  end

  test "importer creates environmental indicator metrics" do
    importer = FsmsImporter.new(dry_run: false)

    metric = importer.send(:find_or_create_metric, "fsms_muni_env_ind1_points")

    assert metric.persisted?
    assert_equal "fsms", metric.data_source
  end

  # ==========================================
  # DOCUMENT CREATION TESTS
  # ==========================================

  test "importer creates documents with correct attributes" do
    importer = FsmsImporter.new(dry_run: false)

    document = importer.send(:find_or_create_document, entities(:yonkers), 2024)

    assert document.persisted?
    assert_equal "Yonkers FSMS Report 2024", document.title
    assert_equal "fsms_monitoring", document.doc_type
    assert_equal 2024, document.fiscal_year
    assert_equal "bulk_data", document.source_type
    assert_equal entities(:yonkers), document.entity
  end

  test "importer enforces document uniqueness" do
    importer = FsmsImporter.new(dry_run: false)

    doc1 = importer.send(:find_or_create_document, entities(:yonkers), 2024)
    doc2 = importer.send(:find_or_create_document, entities(:yonkers), 2024)

    assert_equal doc1.id, doc2.id
  end

  # ==========================================
  # OBSERVATION CREATION TESTS
  # ==========================================

  test "importer creates numeric observations" do
    importer = FsmsImporter.new(dry_run: false)

    entity = entities(:yonkers)
    document = importer.send(:find_or_create_document, entity, 2024)

    importer.send(:save_observation, entity, "fsms_fiscal_score", document, 2024, 35.0)

    assert_equal 1, importer.stats[:observations_created]

    metric = Metric.find_by(key: "fsms_fiscal_score")
    observation = Observation.find_by(entity: entity, metric: metric, fiscal_year: 2024)
    assert observation.present?
    assert_equal 35.0, observation.value_numeric
    assert_equal "verified", observation.verification_status
  end

  test "importer creates text observations for designations" do
    importer = FsmsImporter.new(dry_run: false)

    entity = entities(:yonkers)
    document = importer.send(:find_or_create_document, entity, 2024)

    importer.send(:save_text_observation, entity, "fsms_fiscal_stress_designation", document, 2024,
                  "Significant Fiscal Stress")

    assert_equal 1, importer.stats[:observations_created]

    metric = Metric.find_by(key: "fsms_fiscal_stress_designation")
    observation = Observation.find_by(entity: entity, metric: metric, fiscal_year: 2024)
    assert_equal "Significant Fiscal Stress", observation.value_text
  end

  test "importer updates observations when value changes" do
    importer = FsmsImporter.new(dry_run: false)

    entity = entities(:yonkers)
    document = importer.send(:find_or_create_document, entity, 2024)

    importer.send(:save_observation, entity, "fsms_fiscal_score", document, 2024, 35.0)
    assert_equal 1, importer.stats[:observations_created]

    importer.send(:save_observation, entity, "fsms_fiscal_score", document, 2024, 40.0)
    assert_equal 1, importer.stats[:observations_updated]

    metric = Metric.find_by(key: "fsms_fiscal_score")
    observation = Observation.find_by(entity: entity, metric: metric, fiscal_year: 2024)
    assert_equal 40.0, observation.value_numeric
  end

  test "importer skips observation when value unchanged" do
    importer = FsmsImporter.new(dry_run: false)

    entity = entities(:yonkers)
    document = importer.send(:find_or_create_document, entity, 2024)

    importer.send(:save_observation, entity, "fsms_fiscal_score", document, 2024, 35.0)
    assert_equal 1, importer.stats[:observations_created]

    importer.send(:save_observation, entity, "fsms_fiscal_score", document, 2024, 35.0)
    assert_equal 1, importer.stats[:observations_unchanged]
  end

  test "dry run does not create records" do
    importer = FsmsImporter.new(dry_run: true)

    entity = entities(:yonkers)

    initial_metrics = Metric.count
    initial_docs = Document.count
    initial_obs = Observation.count

    importer.send(:save_observation, entity, "fsms_fiscal_score", nil, 2024, 35.0)

    assert_equal initial_metrics, Metric.count
    assert_equal initial_docs, Document.count
    assert_equal initial_obs, Observation.count
    assert_equal 1, importer.stats[:observations_would_create]
  end

  # ==========================================
  # IDEMPOTENCY TESTS
  # ==========================================

  test "re-import does not duplicate metrics" do
    importer = FsmsImporter.new(dry_run: false)

    metric1 = importer.send(:find_or_create_metric, "fsms_fiscal_score")

    # Simulate re-import with fresh importer
    importer2 = FsmsImporter.new(dry_run: false)
    metric2 = importer2.send(:find_or_create_metric, "fsms_fiscal_score")

    assert_equal metric1.id, metric2.id
  end

  test "re-import does not duplicate documents" do
    importer = FsmsImporter.new(dry_run: false)
    doc1 = importer.send(:find_or_create_document, entities(:yonkers), 2024)

    importer2 = FsmsImporter.new(dry_run: false)
    doc2 = importer2.send(:find_or_create_document, entities(:yonkers), 2024)

    assert_equal doc1.id, doc2.id
  end

  # ==========================================
  # RAKE TASK TESTS
  # ==========================================

  test "fsms:import task exists" do
    assert Rake::Task.task_defined?("fsms:import"),
           "fsms:import rake task should exist"
  end

  test "fsms:import_year task exists" do
    assert Rake::Task.task_defined?("fsms:import_year"),
           "fsms:import_year rake task should exist"
  end

  test "fsms:preview task exists" do
    assert Rake::Task.task_defined?("fsms:preview"),
           "fsms:preview rake task should exist"
  end
end
