# frozen_string_literal: true

require "csv"

namespace :osc do
  namespace :counties do
    desc "Create county entities from first CSV file"
    task create_entities: :environment do
      creator = CountyEntityCreator.new
      creator.run
    end

    desc "Import county OSC financial data (all years or specific year)"
    task :import, [:year] => :environment do |_t, args|
      importer = CountyOscImporter.new
      importer.import(year: args[:year]&.to_i)
    end

    desc "Import county OSC data for a single year"
    task :import_year, [:year] => :environment do |_t, args|
      year = args[:year]&.to_i
      abort "Usage: rails osc:counties:import_year[2023]" unless year

      importer = CountyOscImporter.new
      importer.import(year: year)
    end
  end
end

# Creates county entities from OSC CSV data.
# Reads the first available CSV to extract unique municipal codes and names.
class CountyEntityCreator
  CSV_DIR = Rails.root.join("db/seeds/osc_data/county_all_years")

  def run
    puts "=" * 60
    puts "Creating County Entities from OSC CSV"
    puts "=" * 60
    puts ""

    # Pick the newest CSV that actually has data rows (not just a header)
    file = Dir.glob(CSV_DIR.join("*_County.csv"))
              .sort_by { |f| File.basename(f).to_i }
              .reverse
              .find { |f| File.size(f) > 500 }
    abort "ERROR: No county CSV files with data found in #{CSV_DIR}" unless file

    counties = extract_counties(file)
    puts "Found #{counties.size} counties in #{File.basename(file)}"
    puts ""

    created = 0
    skipped = 0

    counties.each do |municipal_code, osc_name|
      name = normalize_county_name(osc_name)
      slug = name.parameterize

      entity = Entity.find_or_initialize_by(osc_municipal_code: municipal_code)
      if entity.new_record?
        entity.assign_attributes(name: name, kind: :county, state: "NY", slug: slug)
        entity.save!
        puts "  Created: #{name} (#{municipal_code})"
        created += 1
      else
        skipped += 1
      end
    end

    puts ""
    puts "Created: #{created}, Already existed: #{skipped}"
  end

  private

  def extract_counties(file)
    counties = {}
    CSV.foreach(file, headers: true) do |row|
      code = row["MUNICIPAL_CODE"]
      next if code.blank? || counties.key?(code)

      counties[code] = row["ENTITY_NAME"]
    end
    counties
  end

  # "County of Albany" → "Albany County"
  def normalize_county_name(osc_name)
    "#{osc_name.sub(/^County of\s+/i, '').strip} County"
  end
end

# Imports county financial data from OSC CSV files.
# Follows the same pattern as OscImporter for cities.
# rubocop:disable Metrics/ClassLength
class CountyOscImporter
  CSV_DIR = Rails.root.join("db/seeds/osc_data/county_all_years")
  OSC_SOURCE_URL = "https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm"

  attr_reader :stats, :errors

  def initialize
    @stats = Hash.new(0)
    @errors = []
    @entity_cache = {}
    @metric_cache = {}
    @document_cache = {}
  end

  def import(year: nil)
    puts "=" * 60
    puts "County OSC Import"
    puts "=" * 60
    puts ""

    files = csv_files(year)
    if files.empty?
      puts "No CSV files found#{" for year #{year}" if year}"
      return
    end

    puts "Found #{files.count} CSV file(s) to process"
    puts ""

    files.each { |file| process_file(file) }
    print_summary
  end

  private

  def csv_files(year)
    if year
      file = CSV_DIR.join("#{year}_County.csv")
      File.exist?(file) ? [file] : []
    else
      Dir.glob(CSV_DIR.join("*_County.csv"))
    end
  end

  def process_file(file)
    year = File.basename(file, "_County.csv").to_i
    puts "-" * 40
    puts "Processing: #{File.basename(file)} (FY #{year})"

    row_count = 0
    skipped_empty = 0

    CSV.foreach(file, headers: true) do |row|
      row_count += 1

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

    entity = find_entity(municipal_code, row["ENTITY_NAME"])
    unless entity
      stats[:entities_not_found] += 1
      errors << "Entity not found: #{row['ENTITY_NAME']} (#{municipal_code})"
      return
    end

    metric = find_or_create_metric(row)
    document = find_or_create_document(entity, year)
    create_observation(entity, metric, document, parse_amount(row["AMOUNT"]), year)
  end

  def find_entity(municipal_code, osc_name)
    return @entity_cache[municipal_code] if @entity_cache.key?(municipal_code)

    entity = Entity.find_by(osc_municipal_code: municipal_code)

    unless entity
      name = "#{osc_name.sub(/^County of\s+/i, '').strip} County"
      entity = Entity.find_by(name: name, kind: :county, state: "NY")
    end

    @entity_cache[municipal_code] = entity
    entity
  end

  def find_or_create_metric(row)
    account_code = row["ACCOUNT_CODE"]
    return @metric_cache[account_code] if @metric_cache.key?(account_code)

    fund_code = account_code[0]
    function_code = account_code[1..-2]
    object_code = account_code[-1]

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
      m.account_type = parse_account_type(row)
      m.level_1_category = row["LEVEL_1_CATEGORY"]&.titleize
      m.level_2_category = row["LEVEL_2_CATEGORY"]&.titleize
    end

    stats[:metrics_created] += 1 if metric.previously_new_record?
    @metric_cache[account_code] = metric
    metric
  end

  def parse_account_type(row)
    raw_section = row["ACCOUNT_CODE_SECTION"] || row["FINANCIAL_STATEMENT"]
    return nil if raw_section.blank?

    case raw_section.upcase
    when "REVENUE", "STATEMENT OF REVENUES AND OTHER SOURCES"
      :revenue
    when "EXPENDITURE", "STATEMENT OF EXPENDITURES AND OTHER USES"
      :expenditure
    when "GL", "FBNP", "BALANCE SHEET", "CHANGE IN EQUITY"
      :balance_sheet
    end
  end

  def build_metric_label(row)
    level2 = row["LEVEL_2_CATEGORY"]&.titleize
    object = row["OBJECT_OF_EXPENDITURE"]&.titleize

    if object.present? && object != level2
      "#{level2} - #{object}"
    else
      level2 || row["ACCOUNT_CODE_NARRATIVE"]&.titleize || row["ACCOUNT_CODE"]
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
      doc_type: "osc_county_afr",
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
    observation = Observation.find_or_initialize_by(
      entity: entity,
      metric: metric,
      document: document,
      fiscal_year: year
    )

    if observation.new_record?
      observation.value_numeric = amount
      observation.verification_status = :verified
      observation.save!
      stats[:observations_created] += 1
    elsif observation.value_numeric != amount
      observation.update!(value_numeric: amount)
      stats[:observations_updated] += 1
    else
      stats[:observations_unchanged] += 1
    end
  end

  def parse_amount(amount_str)
    return nil if amount_str.blank?

    BigDecimal(amount_str.to_s.delete(","))
  rescue ArgumentError
    nil
  end

  def print_summary
    puts "=" * 60
    puts "IMPORT SUMMARY"
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
