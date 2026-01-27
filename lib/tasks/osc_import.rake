# frozen_string_literal: true

require "csv"

namespace :osc do
  desc "Import OSC financial data for cities (all years or specific year)"
  task :import, [:year] => :environment do |_t, args|
    importer = OscImporter.new
    importer.import(year: args[:year]&.to_i)
  end

  desc "Import OSC data for a single year (faster for testing)"
  task :import_year, [:year] => :environment do |_t, args|
    year = args[:year]&.to_i
    abort "Usage: rails osc:import_year[2023]" unless year

    importer = OscImporter.new
    importer.import(year: year)
  end

  desc "Preview OSC import without making changes (dry run)"
  task :preview, [:year] => :environment do |_t, args|
    importer = OscImporter.new(dry_run: true)
    importer.import(year: args[:year]&.to_i)
  end

  desc "Update osc_municipal_code on entities from mapping file"
  task update_municipal_codes: :environment do
    mapping_file = Rails.root.join("db/seeds/osc_data/entity_mapping.yml")
    mapping = YAML.load_file(mapping_file)

    puts "Updating OSC municipal codes from entity_mapping.yml..."
    puts "=" * 60

    updated = 0
    not_found = []

    mapping["cities"].each do |municipal_code, data|
      entity = Entity.find_by(name: data["db_name"], kind: :city, state: "NY")

      if entity
        entity.update!(osc_municipal_code: municipal_code)
        puts "  Updated: #{entity.name} -> #{municipal_code}"
        updated += 1
      else
        puts "  NOT FOUND: #{data['db_name']}"
        not_found << data["db_name"]
      end
    end

    puts "=" * 60
    puts "Updated #{updated} entities"
    puts "Not found: #{not_found.count}" if not_found.any?
    not_found.each { |name| puts "  - #{name}" }
  end
end

# Service class for OSC import logic
# rubocop:disable Metrics/ClassLength
class OscImporter
  OSC_DATA_DIR = Rails.root.join("db/seeds/osc_data/city_all_years")
  OSC_SOURCE_URL = "https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm"

  attr_reader :dry_run, :stats, :errors

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
    @errors = []
    @entity_cache = {}
    @metric_cache = {}
    @document_cache = {}
  end

  def import(year: nil)
    puts "=" * 60
    puts dry_run ? "OSC Import PREVIEW (dry run)" : "OSC Import"
    puts "=" * 60
    puts ""

    files = csv_files(year)
    if files.empty?
      puts "No CSV files found#{" for year #{year}" if year}"
      return
    end

    puts "Found #{files.count} CSV file(s) to process"
    puts ""

    files.each do |file|
      process_file(file)
    end

    print_summary
  end

  private

  def csv_files(year)
    if year
      file = OSC_DATA_DIR.join("#{year}_City.csv")
      File.exist?(file) ? [file] : []
    else
      Dir.glob(OSC_DATA_DIR.join("*_City.csv"))
    end
  end

  def process_file(file)
    year = File.basename(file, "_City.csv").to_i
    puts "-" * 40
    puts "Processing: #{File.basename(file)} (FY #{year})"

    row_count = 0
    skipped_empty = 0

    CSV.foreach(file, headers: true) do |row|
      row_count += 1

      # Skip rows with zero or empty amounts
      amount = parse_amount(row["AMOUNT"])
      if amount.nil? || amount.zero?
        skipped_empty += 1
        next
      end

      process_row(row, year)
    end

    puts "  Rows processed: #{row_count}, Skipped (zero/empty): #{skipped_empty}"
    puts ""
  end

  def process_row(row, year)
    municipal_code = row["MUNICIPAL_CODE"]
    amount = parse_amount(row["AMOUNT"])

    # Find entity
    entity = find_entity(municipal_code, row["ENTITY_NAME"])
    unless entity
      stats[:entities_not_found] += 1
      errors << "Entity not found: #{row['ENTITY_NAME']} (#{municipal_code})"
      return
    end

    return if dry_run

    # Find or create metric
    metric = find_or_create_metric(row)

    # Find or create document
    document = find_or_create_document(entity, year)

    # Create observation
    create_observation(entity, metric, document, amount, year)
  end

  def find_entity(municipal_code, osc_name)
    # Check cache first
    return @entity_cache[municipal_code] if @entity_cache.key?(municipal_code)

    # Try to find by municipal code
    entity = Entity.find_by(osc_municipal_code: municipal_code)

    # Fallback: try to match by name
    unless entity
      db_name = osc_name.sub(/^City of /, "")
      entity = Entity.find_by(name: db_name, kind: :city, state: "NY")
    end

    @entity_cache[municipal_code] = entity
    entity
  end

  def find_or_create_metric(row)
    account_code = row["ACCOUNT_CODE"]
    return @metric_cache[account_code] if @metric_cache.key?(account_code)

    # Parse account code structure
    fund_code = account_code[0] # First character (A, F, G, etc.)
    function_code = account_code[1..-2] # Middle characters (e.g., "3120" from "A31201")
    object_code = account_code[-1] # Last character (1, 2, 4, 8)

    metric = Metric.find_or_create_by!(account_code: account_code) do |m|
      m.key = account_code.downcase
      m.label = build_metric_label(row)
      m.data_source = :osc
      m.fund_code = fund_code
      m.function_code = function_code
      m.object_code = object_code
      m.value_type = :numeric
      m.display_format = "currency_rounded"
      m.description = build_metric_description(row)
      m.level_1_category = row["LEVEL_1_CATEGORY"].presence
      m.level_2_category = row["LEVEL_2_CATEGORY"].presence
    end

    stats[:metrics_created] += 1 if metric.previously_new_record?
    @metric_cache[account_code] = metric
    metric
  end

  def build_metric_label(row)
    # Build label from OSC data: "Level 2 Category - Object"
    # e.g., "Police - Personal Services"
    level2 = row["LEVEL_2_CATEGORY"]
    object = row["OBJECT_OF_EXPENDITURE"]

    if object.present? && object != level2
      "#{level2} - #{object}"
    else
      level2 || row["ACCOUNT_CODE_NARRATIVE"] || row["ACCOUNT_CODE"]
    end
  end

  def build_metric_description(row)
    parts = []
    parts << "Section: #{row['ACCOUNT_CODE_SECTION']}" if row["ACCOUNT_CODE_SECTION"].present?
    parts << "Category: #{row['LEVEL_1_CATEGORY']}" if row["LEVEL_1_CATEGORY"].present?
    parts << "OSC Account: #{row['ACCOUNT_CODE']}"
    parts.join(". ")
  end

  def find_or_create_document(entity, year)
    cache_key = "#{entity.id}-#{year}"
    return @document_cache[cache_key] if @document_cache.key?(cache_key)

    document = Document.find_or_create_by!(
      entity: entity,
      doc_type: "osc_afr",
      fiscal_year: year
    ) do |d|
      d.title = "#{entity.name} OSC Annual Financial Report #{year}"
      d.source_type = :bulk_data
      d.source_url = OSC_SOURCE_URL
    end

    stats[:documents_created] += 1 if document.previously_new_record?
    @document_cache[cache_key] = document
    document
  end

  def create_observation(entity, metric, document, amount, year)
    # Use find_or_create to handle duplicates gracefully
    observation = Observation.find_or_initialize_by(
      entity: entity,
      metric: metric,
      document: document,
      fiscal_year: year
    )

    if observation.new_record?
      observation.value_numeric = amount
      observation.verification_status = :verified # OSC data is authoritative
      observation.save!
      stats[:observations_created] += 1
    elsif observation.value_numeric != amount
      # Update existing observation if amount changed
      observation.update!(value_numeric: amount)
      stats[:observations_updated] += 1
    else
      stats[:observations_unchanged] += 1
    end
  end

  def parse_amount(amount_str)
    return nil if amount_str.blank?

    # Handle amounts with decimals (e.g., "3619538.81")
    BigDecimal(amount_str.to_s.delete(","))
  rescue ArgumentError
    nil
  end

  def print_summary
    puts "=" * 60
    puts dry_run ? "PREVIEW SUMMARY (no changes made)" : "IMPORT SUMMARY"
    puts "=" * 60
    puts ""
    puts "Metrics created:        #{stats[:metrics_created]}"
    puts "Documents created:      #{stats[:documents_created]}"
    puts "Observations created:   #{stats[:observations_created]}"
    puts "Observations updated:   #{stats[:observations_updated]}"
    puts "Observations unchanged: #{stats[:observations_unchanged]}"
    puts ""

    if stats[:entities_not_found].positive?
      puts "WARNINGS:"
      puts "  Entities not found: #{stats[:entities_not_found]}"
      puts ""
    end

    if errors.any?
      puts "ERRORS (first 10):"
      errors.first(10).each { |e| puts "  - #{e}" }
      puts "  ... and #{errors.count - 10} more" if errors.count > 10
    end

    puts ""
    puts "Current totals:"
    puts "  Entities:     #{Entity.count}"
    puts "  Documents:    #{Document.count}"
    puts "  Metrics:      #{Metric.count}"
    puts "  Observations: #{Observation.count}"
  end
end
# rubocop:enable Metrics/ClassLength
