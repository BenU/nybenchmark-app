# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

namespace :census do
  desc "Import Census ACS 5-year data for all cities (all years or specific year)"
  task :import, [:year] => :environment do |_t, args|
    importer = CensusImporter.new
    importer.import(year: args[:year]&.to_i)
  end

  desc "Import Census data for a single year (faster for testing)"
  task :import_year, [:year] => :environment do |_t, args|
    year = args[:year]&.to_i
    abort "Usage: rails census:import_year[2023]" unless year

    importer = CensusImporter.new
    importer.import(year: year)
  end

  desc "Preview Census import without making changes (dry run)"
  task :preview, [:year] => :environment do |_t, args|
    importer = CensusImporter.new(dry_run: true)
    importer.import(year: args[:year]&.to_i)
  end
end

# Service class for Census Bureau ACS data import
# rubocop:disable Metrics/ClassLength
class CensusImporter
  CENSUS_DATA_DIR = Rails.root.join("db/seeds/census_data")
  FIPS_MAPPING_FILE = CENSUS_DATA_DIR.join("entity_fips_mapping.yml")
  METRIC_DEFINITIONS_FILE = CENSUS_DATA_DIR.join("metric_definitions.yml")

  # Census API base URL
  CENSUS_API_BASE = "https://api.census.gov/data"

  # Suppressed/unavailable data markers from Census
  SUPPRESSED_VALUES = ["-666666666", "-999999999", "-888888888", nil, ""].freeze

  attr_reader :dry_run, :stats, :errors

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
    @errors = []
    @entity_cache = {}
    @metric_cache = {}
    @document_cache = {}

    load_mappings
  end

  def import(year: nil)
    puts "=" * 60
    puts dry_run ? "Census Import PREVIEW (dry run)" : "Census Import"
    puts "=" * 60
    puts ""

    validate_api_key!

    years = year ? [year] : available_years
    year_range = years.many? ? "#{years.first}..#{years.last}" : years.first.to_s
    puts "Importing data for #{years.count} year(s): #{year_range}"
    puts "Variables to fetch: #{variable_codes.count}"
    puts ""

    years.each do |yr|
      process_year(yr)
      sleep(0.5) unless dry_run # Rate limiting - courtesy to Census API
    end

    print_summary
  end

  private

  def load_mappings
    @fips_mapping = YAML.load_file(FIPS_MAPPING_FILE)
    @metric_definitions = YAML.load_file(METRIC_DEFINITIONS_FILE)

    # Build reverse lookup: FIPS code -> db_name
    @fips_to_entity = {}
    @fips_mapping["cities"]&.each do |db_name, fips_code|
      @fips_to_entity[fips_code] = db_name
    end
    @fips_mapping["nyc"]&.each do |db_name, fips_code|
      @fips_to_entity[fips_code] = db_name
    end
  end

  def validate_api_key!
    return if api_key.present?

    puts "ERROR: Census API key not configured."
    puts ""
    puts "To configure:"
    puts "  1. Register at https://api.census.gov/key/signup.html"
    puts "  2. Set CENSUS_API_KEY environment variable or add to Rails credentials"
    puts ""
    abort "Census API key required"
  end

  def api_key
    @api_key ||= ENV.fetch("CENSUS_API_KEY", nil) || Rails.application.credentials.dig(:census, :api_key)
  end

  def available_years
    @metric_definitions["available_years"] || (2010..2023).to_a
  end

  def variable_codes
    @metric_definitions["metrics"].keys
  end

  def process_year(year)
    puts "-" * 40
    puts "Fetching: ACS 5-Year Estimates for #{year}"

    data = fetch_census_data(year)

    if data.nil?
      puts "  ERROR: Failed to fetch data for #{year}"
      errors << "Failed to fetch data for year #{year}"
      return
    end

    # First row is headers
    headers = data.first
    rows = data[1..]

    puts "  Retrieved #{rows.count} places from Census API"

    matched = 0
    rows.each do |row|
      fips_code = row[headers.index("place")]
      entity = find_entity_by_fips(fips_code)

      next unless entity

      matched += 1
      process_place_row(entity, year, headers, row) unless dry_run
    end

    puts "  Matched #{matched} of our #{@fips_to_entity.count} tracked entities"
    puts ""
  end

  def fetch_census_data(year)
    variables = variable_codes.join(",")
    url = "#{CENSUS_API_BASE}/#{year}/acs/acs5?get=NAME,#{variables}&for=place:*&in=state:36&key=#{api_key}"

    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      puts "  HTTP Error: #{response.code} #{response.message}"
      errors << "HTTP #{response.code} for year #{year}: #{response.message}"
      return nil
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    puts "  JSON Parse Error: #{e.message}"
    errors << "JSON parse error for year #{year}: #{e.message}"
    nil
  rescue StandardError => e
    puts "  Network Error: #{e.message}"
    errors << "Network error for year #{year}: #{e.message}"
    nil
  end

  def find_entity_by_fips(fips_code)
    return @entity_cache[fips_code] if @entity_cache.key?(fips_code)

    db_name = @fips_to_entity[fips_code]
    return nil unless db_name

    entity = Entity.find_by(name: db_name, state: "NY")
    @entity_cache[fips_code] = entity
    entity
  end

  def process_place_row(entity, year, headers, row)
    # Find or create document for this entity/year
    document = find_or_create_document(entity, year, build_source_url(year))

    # Process each variable
    variable_codes.each do |var_code|
      idx = headers.index(var_code)
      next unless idx

      raw_value = row[idx]
      next if suppressed_value?(raw_value)

      metric = find_or_create_metric(var_code)
      create_observation(entity, metric, document, raw_value.to_f, year)
    end
  end

  def suppressed_value?(value)
    return true if SUPPRESSED_VALUES.include?(value)
    return true if value.to_s.start_with?("-666", "-999", "-888")

    false
  end

  def build_source_url(year)
    # Build a representative API URL for documentation purposes
    "https://api.census.gov/data/#{year}/acs/acs5"
  end

  def find_or_create_metric(var_code)
    return @metric_cache[var_code] if @metric_cache.key?(var_code)

    definition = @metric_definitions["metrics"][var_code]
    key = "census_#{var_code.downcase}"

    metric = Metric.find_or_create_by!(key: key) do |m|
      m.label = definition["label"]
      m.data_source = :census
      m.value_type = :numeric
      m.display_format = definition["display_format"]
      m.description = definition["description"]
    end

    stats[:metrics_created] += 1 if metric.previously_new_record?
    @metric_cache[var_code] = metric
    metric
  end

  def find_or_create_document(entity, year, source_url)
    cache_key = "#{entity.id}-#{year}"
    return @document_cache[cache_key] if @document_cache.key?(cache_key)

    document = Document.find_or_create_by!(
      entity: entity,
      doc_type: "us_census_acs5",
      fiscal_year: year
    ) do |d|
      d.title = "#{entity.name} Census ACS 5-Year Estimates #{year}"
      d.source_type = :bulk_data
      d.source_url = source_url
    end

    stats[:documents_created] += 1 if document.previously_new_record?
    @document_cache[cache_key] = document
    document
  end

  def create_observation(entity, metric, document, value, year)
    observation = Observation.find_or_initialize_by(
      entity: entity,
      metric: metric,
      document: document,
      fiscal_year: year
    )

    if observation.new_record?
      observation.value_numeric = value
      observation.verification_status = :verified # Census data is authoritative
      observation.save!
      stats[:observations_created] += 1
    elsif observation.value_numeric != value
      observation.update!(value_numeric: value)
      stats[:observations_updated] += 1
    else
      stats[:observations_unchanged] += 1
    end
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

    if errors.any?
      puts "ERRORS:"
      errors.each { |e| puts "  - #{e}" }
      puts ""
    end

    puts "Current totals:"
    puts "  Entities:     #{Entity.count}"
    puts "  Documents:    #{Document.count}"
    puts "  Metrics:      #{Metric.count}"
    puts "  Observations: #{Observation.count}"
  end
end
# rubocop:enable Metrics/ClassLength
