# frozen_string_literal: true

require "roo"

namespace :fsms do
  desc "Import FSMS scores for all years (or specific year): rails fsms:import or fsms:import[2024]"
  task :import, [:year] => :environment do |_t, args|
    importer = FsmsImporter.new
    importer.import(year: args[:year]&.to_i)
  end

  desc "Import FSMS scores for a single year"
  task :import_year, [:year] => :environment do |_t, args|
    year = args[:year]&.to_i
    abort "Usage: rails fsms:import_year[2024]" unless year

    importer = FsmsImporter.new
    importer.import(year: year)
  end

  desc "Dry run — validate files and print stats without saving"
  task preview: :environment do
    importer = FsmsImporter.new(dry_run: true)
    importer.import
  end
end

# Imports OSC Fiscal Stress Monitoring System (FSMS) scores from Excel files.
#
# FSMS data covers all NY municipalities and school districts (2012-present).
# Two methodology eras:
#   Pre-2017: 29-point weighted system (munis), 21-point (schools), scores as fractions (0.0-1.0)
#   2017+:    100-point direct scoring, scores as point values (0-100)
#
# We import from 3 sheets per file:
#   Summary:                Fiscal/environmental scores + stress designations
#   Financial Scoring:      Individual fiscal indicator point values
#   Environmental Scoring:  Individual environmental indicator point values
#
# rubocop:disable Metrics/ClassLength
class FsmsImporter
  DATA_DIR = Rails.root.join("db/seeds/fsms_data")
  DEFINITIONS_FILE = DATA_DIR.join("metric_definitions.yml")
  FSMS_SOURCE_URL = "https://www.osc.ny.gov/local-government/fiscal-monitoring"

  # Header row is row 6 in all FSMS files (rows 1-5 are title/metadata)
  HEADER_ROW = 6

  # Pre-2017 environmental scoring uses "Indicator N" labels in row 5
  LABEL_ROW = 5

  SummaryColumns = Struct.new(:name, :municode, :fiscal_score, :env_score, :stress, :env_rating, keyword_init: true)

  attr_reader :stats, :errors

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
    @errors = []
    @entity_cache = {}
    @metric_cache = {}
    @document_cache = {}
    @definitions = YAML.load_file(DEFINITIONS_FILE)
  end

  def import(year: nil)
    puts "=" * 60
    puts "FSMS Import#{' (DRY RUN)' if @dry_run}"
    puts "=" * 60
    puts ""

    files = find_files(year)
    if files.empty?
      puts "No FSMS files found#{" for year #{year}" if year}"
      return
    end

    puts "Found #{files.count} file(s) to process"
    puts ""

    files.each { |file| process_file(file) }
    print_summary
  end

  private

  # ── File discovery ──

  def find_files(year)
    patterns = ["*-munis-all-data-*.xls*", "*-schools-all-data-*.xls*",
                "*-school-all-data-*.xls*"]
    all_files = patterns.flat_map { |p| Dir.glob(DATA_DIR.join(p)) }.sort

    if year
      all_files.select { |f| File.basename(f).start_with?(year.to_s) }
    else
      all_files
    end
  end

  def file_year(file)
    File.basename(file).match(/^(\d{4})/)[1].to_i
  end

  def file_type(file)
    basename = File.basename(file).downcase
    basename.include?("school") ? :school : :muni
  end

  # ── File processing ──

  def process_file(file)
    year = file_year(file)
    type = file_type(file)
    puts "-" * 40
    puts "Processing: #{File.basename(file)} (FY #{year}, #{type})"

    spreadsheet = open_spreadsheet(file)
    return unless spreadsheet

    import_summary(spreadsheet, year, type)
    import_financial_scoring(spreadsheet, year, type)
    import_environmental_scoring(spreadsheet, year, type)

    puts ""
  end

  def open_spreadsheet(file)
    magic = File.read(file, 4, mode: "rb")
    if magic.start_with?("PK")
      # ZIP/XLSX content — Roo::Excelx requires .xlsx extension, so use a
      # temp copy when the file has a misleading .xls extension
      if file.to_s.end_with?(".xls") && !file.to_s.end_with?(".xlsx")
        tmp = "#{file}.tmp.xlsx"
        FileUtils.cp(file, tmp)
        spreadsheet = Roo::Excelx.new(tmp)
        FileUtils.rm_f(tmp)
        spreadsheet
      else
        Roo::Excelx.new(file.to_s)
      end
    else
      require "roo-xls"
      Roo::Excel.new(file.to_s)
    end
  rescue StandardError => e
    errors << "Failed to open #{File.basename(file)}: #{e.message}"
    puts "  ERROR: #{e.message}"
    nil
  end

  # ── Summary sheet ──

  def import_summary(spreadsheet, year, type)
    return unless spreadsheet.sheets.include?("Summary")

    spreadsheet.default_sheet = "Summary"
    headers = spreadsheet.row(HEADER_ROW).map { |h| h.to_s.strip }

    cols = SummaryColumns.new(
      name: find_col(headers, "Name"),
      municode: find_col(headers, "Municode"),
      fiscal_score: find_col(headers, "Fiscal Score"),
      env_score: find_col(headers, "Environmental Score"),
      stress: find_col(headers, "Type of Stress"),
      env_rating: find_col(headers, "Environmental Rating")
    )

    unless cols.name && cols.municode
      errors << "Summary sheet missing Name/Municode columns in FY #{year}"
      return
    end

    count = 0
    ((HEADER_ROW + 1)..spreadsheet.last_row).each do |row_num|
      row = spreadsheet.row(row_num)
      municode = row[cols.municode].to_s.strip
      next if municode.blank?

      entity = find_entity(municode, row[cols.name].to_s.strip, type)
      unless entity
        stats[:entities_not_found] += 1
        next
      end

      document = find_or_create_document(entity, year)
      import_summary_row(row, cols, entity, document, year)
      count += 1
    end

    puts "  Summary: #{count} entities processed"
  end

  def import_summary_row(row, cols, entity, document, year)
    if cols.fiscal_score
      val = row[cols.fiscal_score]
      save_observation(entity, "fsms_fiscal_score", document, year, val.to_f) if numeric_value?(val)
    end

    if cols.env_score
      val = row[cols.env_score]
      save_observation(entity, "fsms_environmental_score", document, year, val.to_f) if numeric_value?(val)
    end

    if cols.stress
      val = row[cols.stress].to_s.strip
      save_text_observation(entity, "fsms_fiscal_stress_designation", document, year, val) if filing_designation?(val)
    end

    return unless cols.env_rating

    val = row[cols.env_rating].to_s.strip
    return unless filing_designation?(val)

    save_text_observation(entity, "fsms_environmental_stress_designation", document, year, val)
  end

  # ── Financial Scoring sheet ──

  def import_financial_scoring(spreadsheet, year, type)
    return unless spreadsheet.sheets.include?("Financial Scoring")

    spreadsheet.default_sheet = "Financial Scoring"
    headers = spreadsheet.row(HEADER_ROW).map { |h| h.to_s.strip.gsub(/\s+/, " ") }

    municode_col = find_col(headers, "Municode")
    name_col = find_col(headers, "Name")
    return unless municode_col && name_col

    indicator_cols = find_indicator_cols(headers)
    prefix = type == :school ? "fsms_school_fiscal" : "fsms_muni_fiscal"

    count = 0
    ((HEADER_ROW + 1)..spreadsheet.last_row).each do |row_num|
      row = spreadsheet.row(row_num)
      municode = row[municode_col].to_s.strip
      next if municode.blank?

      entity = find_entity(municode, row[name_col].to_s.strip, type)
      next unless entity

      document = find_or_create_document(entity, year)

      indicator_cols.each do |ind_num, col_idx|
        val = row[col_idx]
        next unless numeric_value?(val)

        save_observation(entity, "#{prefix}_ind#{ind_num}_points", document, year, val.to_f)
      end

      count += 1
    end

    puts "  Financial Scoring: #{count} entities processed (#{indicator_cols.size} indicators)"
  end

  # ── Environmental Scoring sheet ──

  def import_environmental_scoring(spreadsheet, year, type)
    return unless spreadsheet.sheets.include?("Environmental Scoring")

    spreadsheet.default_sheet = "Environmental Scoring"
    headers = spreadsheet.row(HEADER_ROW).map { |h| h.to_s.strip.gsub(/\s+/, " ") }

    municode_col = find_col(headers, "Municode")
    name_col = find_col(headers, "Name")
    return unless municode_col && name_col

    # Post-2017: "Ind 1", "Ind 2" in row 6. Pre-2017: "Indicator 1" etc. in row 5.
    indicator_cols = find_indicator_cols(headers)
    if indicator_cols.empty?
      label_row = spreadsheet.row(LABEL_ROW).map { |h| h.to_s.strip.gsub(/\s+/, " ") }
      indicator_cols = find_indicator_cols_from_labels(label_row)
    end

    prefix = type == :school ? "fsms_school_env" : "fsms_muni_env"

    count = 0
    ((HEADER_ROW + 1)..spreadsheet.last_row).each do |row_num|
      row = spreadsheet.row(row_num)
      municode = row[municode_col].to_s.strip
      next if municode.blank?

      entity = find_entity(municode, row[name_col].to_s.strip, type)
      next unless entity

      document = find_or_create_document(entity, year)

      indicator_cols.each do |ind_num, col_idx|
        val = row[col_idx]
        next unless numeric_value?(val)

        save_observation(entity, "#{prefix}_ind#{ind_num}_points", document, year, val.to_f)
      end

      count += 1
    end

    puts "  Environmental Scoring: #{count} entities processed (#{indicator_cols.size} indicators)"
  end

  # ── Column detection ──

  def find_col(headers, name)
    headers.index { |h| h.to_s.strip.downcase.include?(name.downcase) }
  end

  # Matches "Ind 1", "Ind 2" etc. in row 6 (post-2017 format)
  def find_indicator_cols(headers)
    cols = {}
    headers.each_with_index do |h, idx|
      match = h.to_s.match(/\AInd\s+(\d+)\z/i)
      cols[match[1].to_i] = idx if match
    end
    cols
  end

  # Matches "Indicator 1", "Indicator 2" etc. in row 5 (pre-2017 environmental)
  def find_indicator_cols_from_labels(label_row)
    cols = {}
    label_row.each_with_index do |h, idx|
      match = h.to_s.match(/\AIndicator\s+(\d+)\z/i)
      cols[match[1].to_i] = idx if match
    end
    cols
  end

  # ── Entity lookup ──

  def find_entity(municode, name, type)
    cache_key = municode
    return @entity_cache[cache_key] if @entity_cache.key?(cache_key)

    entity = Entity.find_by(osc_municipal_code: municode)

    # Fallback: match by name for school districts
    if entity.nil? && type == :school
      entity = Entity.find_by("name ILIKE ? AND kind = ?", "%#{name}%", Entity.kinds[:school_district])
    end

    @entity_cache[cache_key] = entity
    entity
  end

  # ── Document management ──

  def find_or_create_document(entity, year)
    cache_key = "#{entity.id}-#{year}"
    return @document_cache[cache_key] if @document_cache.key?(cache_key)
    return nil if @dry_run

    document = Document.find_or_create_by!(
      entity: entity,
      doc_type: "fsms_monitoring",
      fiscal_year: year
    ) do |d|
      d.title = "#{entity.name} FSMS Report #{year}"
      d.source_type = :bulk_data
      d.source_url = FSMS_SOURCE_URL
    end

    stats[:documents_created] += 1 if document.previously_new_record?
    @document_cache[cache_key] = document
    document
  end

  # ── Metric management ──

  def find_or_create_metric(key)
    return @metric_cache[key] if @metric_cache.key?(key)
    return nil if @dry_run

    definition = find_metric_definition(key)
    unless definition
      errors << "No metric definition for key: #{key}" unless @errors.include?("No metric definition for key: #{key}")
      return nil
    end

    metric = Metric.find_or_create_by!(key: key) do |m|
      m.label = definition["label"]
      m.description = definition["description"]
      m.data_source = :fsms
      m.value_type = definition["value_type"]&.to_sym || :numeric
      m.display_format = definition["display_format"] || "decimal"
    end

    stats[:metrics_created] += 1 if metric.previously_new_record?
    @metric_cache[key] = metric
    metric
  end

  def find_metric_definition(key)
    search_definitions(@definitions, key)
  end

  def search_definitions(hash, target_key)
    hash.each_value do |v|
      next unless v.is_a?(Hash)

      return v if v["key"] == target_key

      result = search_definitions(v, target_key)
      return result if result
    end
    nil
  end

  # ── Observation management ──

  def save_observation(entity, metric_key, document, year, value)
    stats[:observations_seen] += 1

    if @dry_run
      stats[:observations_would_create] += 1
      return
    end

    metric = find_or_create_metric(metric_key)
    return unless metric && document

    observation = Observation.find_or_initialize_by(
      entity: entity, metric: metric, document: document, fiscal_year: year
    )

    persist_numeric_observation(observation, value)
  end

  def save_text_observation(entity, metric_key, document, year, value)
    stats[:observations_seen] += 1

    if @dry_run
      stats[:observations_would_create] += 1
      return
    end

    metric = find_or_create_metric(metric_key)
    return unless metric && document

    observation = Observation.find_or_initialize_by(
      entity: entity, metric: metric, document: document, fiscal_year: year
    )

    persist_text_observation(observation, value)
  end

  def persist_text_observation(observation, value)
    if observation.new_record?
      observation.value_text = value
      observation.verification_status = :verified
      observation.save!
      stats[:observations_created] += 1
    elsif observation.value_text != value
      observation.update!(value_text: value)
      stats[:observations_updated] += 1
    else
      stats[:observations_unchanged] += 1
    end
  end

  def persist_numeric_observation(observation, value)
    if observation.new_record?
      observation.value_numeric = value
      observation.verification_status = :verified
      observation.save!
      stats[:observations_created] += 1
    elsif observation.value_numeric != value
      observation.update!(value_numeric: value)
      stats[:observations_updated] += 1
    else
      stats[:observations_unchanged] += 1
    end
  end

  # ── Helpers ──

  def numeric_value?(val)
    val.is_a?(Numeric)
  end

  def filing_designation?(val)
    val.present? && val != "Not filed"
  end

  def print_summary
    puts "=" * 60
    puts "IMPORT SUMMARY#{' (DRY RUN)' if @dry_run}"
    puts "=" * 60
    puts ""

    if @dry_run
      puts "Observations seen:      #{stats[:observations_seen]}"
      puts "Would create:           #{stats[:observations_would_create]}"
      puts "Entities not found:     #{stats[:entities_not_found]}"
    else
      puts "Metrics created:        #{stats[:metrics_created]}"
      puts "Documents created:      #{stats[:documents_created]}"
      puts "Observations created:   #{stats[:observations_created]}"
      puts "Observations updated:   #{stats[:observations_updated]}"
      puts "Observations unchanged: #{stats[:observations_unchanged]}"
    end

    puts ""

    if stats[:entities_not_found].positive?
      puts "Entities not found: #{stats[:entities_not_found]} (expected — towns/villages not yet imported)"
      puts ""
    end

    if errors.any?
      puts "ERRORS (first 10):"
      errors.uniq.first(10).each { |e| puts "  - #{e}" }
      puts "  ... and #{errors.uniq.count - 10} more" if errors.uniq.count > 10
      puts ""
    end

    return if @dry_run

    puts "Current totals:"
    puts "  Entities:     #{Entity.count}"
    puts "  Documents:    #{Document.count}"
    puts "  Metrics:      #{Metric.count}"
    puts "  Observations: #{Observation.count}"
  end
end
# rubocop:enable Metrics/ClassLength
