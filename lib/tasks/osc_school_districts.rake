# frozen_string_literal: true

require "csv"

namespace :osc do
  namespace :schools do
    desc "Create school district entities from OSC data"
    task create_entities: :environment do
      creator = SchoolDistrictEntityCreator.new
      creator.run
    end

    desc "Preview school district entity creation (dry run)"
    task preview_entities: :environment do
      creator = SchoolDistrictEntityCreator.new(dry_run: true)
      creator.run
    end

    desc "Create metrics for school district data from CSV headers"
    task create_metrics: :environment do
      creator = SchoolDistrictMetricCreator.new
      creator.run
    end

    desc "Preview metric creation (dry run)"
    task preview_metrics: :environment do
      creator = SchoolDistrictMetricCreator.new(dry_run: true)
      creator.run
    end

    desc "Import school district financial data from OSC CSV files"
    task import: :environment do
      importer = SchoolDistrictImporter.new
      importer.run
    end

    desc "Import a single year of school district data"
    task :import_year, [:year] => :environment do |_t, args|
      year = args[:year]&.to_i
      abort "Usage: rails osc:schools:import_year[2024]" unless year

      importer = SchoolDistrictImporter.new
      importer.run(year: year)
    end

    desc "Preview import (dry run)"
    task preview_import: :environment do
      importer = SchoolDistrictImporter.new(dry_run: true)
      importer.run
    end

    desc "Calculate derived metrics (per-pupil spending, admin overhead %, state aid dependency %)"
    task derive_metrics: :environment do
      calculator = SchoolDistrictDerivedMetrics.new
      calculator.run
    end

    desc "Preview derived metrics calculation (dry run)"
    task preview_derive_metrics: :environment do
      calculator = SchoolDistrictDerivedMetrics.new(dry_run: true)
      calculator.run
    end
  end
end

# Service class for creating school district entities
# rubocop:disable Metrics/ClassLength
class SchoolDistrictEntityCreator
  CSV_FILE = Rails.root.join("db/seeds/osc_school_district_data/leveltwo24.csv")

  BIG_FIVE_NAMES = [
    "Buffalo City School District",
    "Rochester City School District",
    "Syracuse City School District",
    "Yonkers City School District"
    # NYC excluded - not in OSC data
  ].freeze

  # Map city school district name to parent city entity name
  CITY_NAME_MAPPING = {
    # Big Five
    "Buffalo City School District" => "Buffalo",
    "Rochester City School District" => "Rochester",
    "Syracuse City School District" => "Syracuse",
    "Yonkers City School District" => "Yonkers",
    # Small city school districts - OSC name to our entity name
    "Albany City School District" => "Albany",
    "Amsterdam City School District" => "Amsterdam",
    "Auburn City School District" => "Auburn",
    "Batavia City School District" => "Batavia",
    "Beacon City School District" => "Beacon",
    "Binghamton City School District" => "Binghamton",
    "Canandaigua City School District" => "Canandaigua",
    "Cohoes City School District" => "Cohoes",
    "Corning City School District" => "Corning",
    "Cortland City School District" => "Cortland",
    "Dunkirk City School District" => "Dunkirk",
    "Elmira City School District" => "Elmira",
    "Fulton City School District" => "Fulton",
    "Geneva City School District" => "Geneva",
    "Glen Cove City School District" => "Glen Cove",
    "Glens Falls City School District" => "Glens Falls",
    "Gloversville City School District" => "Gloversville",
    "Hornell City School District" => "Hornell",
    "Hudson City School District" => "Hudson",
    "Ithaca City School District" => "Ithaca",
    "Jamestown City School District" => "Jamestown",
    "Johnstown City School District" => "Johnstown",
    "Kingston City School District" => "Kingston",
    "Lackawanna City School District" => "Lackawanna",
    "Little Falls City School District" => "Little Falls",
    "Lockport City School District" => "Lockport",
    "Long Beach City School District" => "Long Beach",
    "Mechanicville City School District" => "Mechanicville",
    "Middletown City School District" => "Middletown",
    "Mount Vernon City School District" => "Mount Vernon",
    "Mount Vernon School District" => "Mount Vernon", # OSC uses this variant
    "New Rochelle City School District" => "New Rochelle",
    "Newburgh City School District" => "Newburgh",
    "Niagara Falls City School District" => "Niagara Falls",
    "North Tonawanda City School District" => "North Tonawanda",
    "Norwich City School District" => "Norwich",
    "Ogdensburg City School District" => "Ogdensburg",
    "Olean City School District" => "Olean",
    "Oneida City School District" => "Oneida",
    "Oneonta City School District" => "Oneonta",
    "Oswego City School District" => "Oswego",
    "Peekskill City School District" => "Peekskill",
    "Plattsburgh City School District" => "Plattsburgh",
    "Port Jervis City School District" => "Port Jervis",
    "Poughkeepsie City School District" => "Poughkeepsie",
    "Rensselaer City School District" => "Rensselaer",
    "Rome City School District" => "Rome",
    "Rye City School District" => "Rye",
    "Salamanca City School District" => "Salamanca",
    "Saratoga Springs City School District" => "Saratoga Springs",
    "Schenectady City School District" => "Schenectady",
    "Sherrill City School District" => "Sherrill",
    "Tonawanda City School District" => "Tonawanda",
    "Troy City School District" => "Troy",
    "Utica City School District" => "Utica",
    "Watertown City School District" => "Watertown",
    "Watervliet City School District" => "Watervliet",
    "White Plains City School District" => "White Plains"
  }.freeze

  attr_reader :dry_run, :stats

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
    @city_cache = {}
  end

  def run
    puts "=" * 70
    puts dry_run ? "School District Entity Creation PREVIEW (dry run)" : "School District Entity Creation"
    puts "=" * 70
    puts ""

    abort "ERROR: CSV file not found: #{CSV_FILE}" unless File.exist?(CSV_FILE)

    # Load city entities for parent linking
    load_city_cache

    # Process CSV
    process_csv

    # Print summary
    print_summary
  end

  private

  def load_city_cache
    puts "Loading city entities for parent linking..."
    Entity.where(kind: :city, state: "NY").find_each do |city|
      @city_cache[city.name] = city
    end
    puts "  Found #{@city_cache.size} cities"
    puts ""
  end

  def process_csv
    puts "Processing #{File.basename(CSV_FILE)}..."
    puts ""

    CSV.foreach(CSV_FILE, headers: true) do |row|
      process_row(row)
    end
  end

  def process_row(row)
    osc_class = row["Class Description"]
    name = row["Entity Name"]
    muni_code = row["Muni Code"]
    county = row["County"]

    # Determine school_legal_type
    legal_type = map_legal_type(osc_class, name)

    unless legal_type
      puts "  SKIP: Unknown class '#{osc_class}' for #{name}"
      stats[:skipped] += 1
      return
    end

    # Generate slug
    slug = name.parameterize

    # Find parent city for city school districts (needed before update check)
    parent = nil
    if %i[big_five small_city].include?(legal_type)
      city_name = CITY_NAME_MAPPING[name]
      if city_name
        parent = @city_cache[city_name]
        unless parent
          puts "  WARNING: Parent city not found for #{name} (expected: #{city_name})"
          stats[:parent_not_found] += 1
        end
      else
        puts "  WARNING: No city mapping for #{name}"
        stats[:parent_not_found] += 1
      end
    end

    # Check if already exists (by muni code or name)
    existing = Entity.find_by(osc_municipal_code: muni_code)
    existing ||= Entity.find_by(name: name, kind: :school_district, state: "NY")

    if existing
      # Update existing entity with OSC municipal code if missing
      if existing.osc_municipal_code.blank?
        if dry_run
          puts "  Would update existing: #{existing.name} with muni code #{muni_code}"
        else
          existing.update!(
            osc_municipal_code: muni_code,
            school_legal_type: legal_type,
            slug: slug,
            parent: parent || existing.parent
          )
          puts "  Updated existing: #{existing.name}"
        end
        stats[:updated] += 1
      else
        stats[:already_exists] += 1
      end
      return
    end

    if dry_run
      puts "  Would create: #{name}"
      puts "    slug: #{slug}"
      puts "    school_legal_type: #{legal_type}"
      puts "    osc_municipal_code: #{muni_code}"
      puts "    parent: #{parent&.name || 'none'}"
      puts ""
      stats[:would_create] += 1
    else
      entity = Entity.create!(
        name: name,
        slug: slug,
        kind: :school_district,
        school_legal_type: legal_type,
        state: "NY",
        osc_municipal_code: muni_code,
        parent: parent,
        organization_note: "County: #{county}"
      )
      stats[:created] += 1

      puts "  Created: #{entity.name} (#{legal_type})" if stats[:created] <= 5 || (stats[:created] % 100).zero?
    end
  end

  def map_legal_type(osc_class, name)
    case osc_class
    when "City Public School"
      BIG_FIVE_NAMES.include?(name) ? :big_five : :small_city
    when "Central", "Independent Superintendent", "Central High"
      :central
    when "Union Free"
      :union_free
    when "Common"
      :common
    end
  end

  def print_summary
    puts ""
    puts "=" * 70
    puts dry_run ? "PREVIEW SUMMARY (no changes made)" : "CREATION SUMMARY"
    puts "=" * 70
    puts ""

    if dry_run
      puts "Would create:       #{stats[:would_create]}"
      puts "Would update:       #{stats[:updated]}"
    else
      puts "Created:            #{stats[:created]}"
      puts "Updated:            #{stats[:updated]}"
    end
    puts "Already exists:     #{stats[:already_exists]}"
    puts "Skipped (unknown):  #{stats[:skipped]}"
    puts "Parent not found:   #{stats[:parent_not_found]}"
    puts ""

    unless dry_run
      puts "Distribution by school_legal_type:"
      Entity.where(kind: :school_district).group(:school_legal_type).count.each do |type, count|
        puts "  #{type}: #{count}"
      end
      puts ""

      puts "City school districts with parents:"
      Entity.where(kind: :school_district)
            .where.not(parent_id: nil)
            .includes(:parent)
            .order(:name)
            .each do |sd|
              puts "  #{sd.name} -> #{sd.parent.name}"
      end
      puts ""
    end

    puts "Current totals:"
    puts "  Cities:           #{Entity.where(kind: :city).count}"
    puts "  School Districts: #{Entity.where(kind: :school_district).count}"
    puts "  Total Entities:   #{Entity.count}"
  end
end
# rubocop:enable Metrics/ClassLength

# Service class for creating school district metrics
# rubocop:disable Metrics/ClassLength
class SchoolDistrictMetricCreator
  CSV_FILE = Rails.root.join("db/seeds/osc_school_district_data/leveltwo24.csv")

  # Columns to skip (metadata, not financial data)
  METADATA_COLUMNS = [
    "Muni Code",
    "Entity Name",
    "County",
    "Class Description",
    "Fiscal Year End Date",
    "Months in Fiscal Period"
  ].freeze

  # Revenue column patterns (order matters for matching)
  REVENUE_PATTERNS = [
    /tax/i,
    /assessment/i,
    /star payment/i,
    /payment.*lieu/i,
    /interest.*penalties/i,
    /fee/i,
    /charge/i,
    /earning/i,
    /rental/i,
    /sale of property/i,
    /fine/i,
    /forfeit/i,
    /compensation/i,
    /grant/i,
    /gift/i,
    /contribution/i,
    /miscellaneous revenue/i,
    /state aid/i,
    /federal aid/i,
    /mortgage tax/i,
    /sale of obligations/i,
    /bans redeemed/i,
    /debt proceeds/i,
    /transfer/i,
    /other source/i
  ].freeze

  # Balance sheet patterns
  BALANCE_SHEET_PATTERNS = [
    /debt outstanding/i,
    /full value/i
  ].freeze

  attr_reader :dry_run, :stats

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
  end

  def run
    puts "=" * 70
    puts dry_run ? "School District Metric Creation PREVIEW (dry run)" : "School District Metric Creation"
    puts "=" * 70
    puts ""

    abort "ERROR: CSV file not found: #{CSV_FILE}" unless File.exist?(CSV_FILE)

    process_headers
    print_summary
  end

  private

  def process_headers
    headers = CSV.read(CSV_FILE, headers: true).headers

    puts "Processing #{headers.size} columns from CSV..."
    puts ""

    headers.each do |col|
      next if col.blank?
      next if METADATA_COLUMNS.include?(col)

      process_column(col)
    end
  end

  def process_column(col)
    account_type = infer_account_type(col)
    level_1 = infer_level_1_category(col) # rubocop:disable Naming/VariableNumber

    # Check if metric already exists (by key, since label might not be unique)
    metric_key = "school_#{col.parameterize.underscore}"
    existing = Metric.find_by(key: metric_key)
    if existing
      stats[:already_exists] += 1
      return
    end

    if dry_run
      puts "  Would create: #{col}"
      puts "    key: #{metric_key}"
      puts "    account_type: #{account_type || 'nil'}"
      puts "    level_1_category: #{level_1 || 'nil'}"
      puts ""
      stats[:would_create] += 1
    else
      metric = Metric.create!(
        key: metric_key,
        label: col,
        data_source: :osc,
        value_type: :numeric,
        display_format: col == "Enrollment" ? "integer" : "currency_rounded",
        account_type: account_type,
        level_1_category: level_1,
        description: "School district #{account_type || 'metric'}: #{col}"
      )
      stats[:created] += 1

      puts "  Created: #{metric.label} (#{account_type})" if stats[:created] <= 10 || (stats[:created] % 50).zero?
    end
  end

  def infer_account_type(col)
    # Special cases
    return nil if col == "Enrollment"
    return :balance_sheet if BALANCE_SHEET_PATTERNS.any? { |p| col.match?(p) }
    return :revenue if REVENUE_PATTERNS.any? { |p| col.match?(p) }

    # Everything else is expenditure (operations, admin, education, benefits, debt service, totals)
    :expenditure
  end

  def infer_level_1_category(col)
    case col
    # Revenue categories
    when /real property tax/i, /special assessment/i, /star payment/i, /payment.*lieu/i,
         /interest.*penalties/i, /miscellaneous tax/i
      "Real Property Taxes"
    when /sales tax/i, /utilities.*tax/i, /franchise/i, /emergency telephone/i,
         /city income tax/i, /non-property tax/i
      "Non-Property Taxes"
    when /fee/i
      "Fees"
    when /charge/i
      "Charges"
    when /state aid/i, /unrestricted state aid/i, /miscellaneous state aid/i
      "State Aid"
    when /federal aid/i, /miscellaneous federal aid/i
      "Federal Aid"
    when /sale of obligations/i, /bans redeemed/i, /debt proceeds/i
      "Debt Proceeds"
    when /transfer/i, /other source/i
      "Other Sources"

    # Expenditure categories
    when /instruction/i, /pupil service/i, /student activit/i, /education.*transport/i,
         /community college/i, /miscellaneous education/i
      "Education"
    when /operation/i, /administration/i, /general government/i, /zoning/i, /judgement/i
      "General Government"
    when /police/i, /fire/i, /public safety/i, /emergency/i, /correctional/i,
         /disaster/i, /homeland/i
      "Public Safety"
    when /health/i, /mental health/i, /environmental/i
      "Public Health"
    when /highway/i, /bus service/i, /airport/i, /rail/i, /waterway/i,
         /transportation/i
      "Transportation"
    when /social service/i, /financial assistance/i, /medicaid/i, /housing/i,
         /employment service/i, /youth service/i
      "Social Services"
    when /economic development/i, /promotion/i, /infrastructure/i
      "Economic Development"
    when /recreation/i, /library/i, /cultural/i, /constituent/i, /elder/i,
         /natural resource/i, /community service/i, /student census/i
      "Culture And Recreation"
    when /water(?!way)/i, /electric/i, /natural gas/i, /steam/i, /sewer/i,
         /refuse/i, /garbage/i, /landfill/i, /drainage/i, /sanitation/i
      "Utilities"
    when /retirement/i, /social security/i, /insurance/i, /worker.*comp/i,
         /unemployment/i, /losap/i, /benefit/i
      "Employee Benefits"
    when /debt principal/i, /interest on debt/i
      "Debt Service"
    when /total expenditure/i
      "Total"
    end
  end

  def print_summary
    puts ""
    puts "=" * 70
    puts dry_run ? "PREVIEW SUMMARY (no changes made)" : "CREATION SUMMARY"
    puts "=" * 70
    puts ""

    if dry_run
      puts "Would create:     #{stats[:would_create]}"
    else
      puts "Created:          #{stats[:created]}"
    end
    puts "Already exists:   #{stats[:already_exists]}"
    puts ""

    unless dry_run
      puts "Metrics by account_type:"
      Metric.where(data_source: :osc).group(:account_type).count.each do |type, count|
        puts "  #{type || 'nil'}: #{count}"
      end
      puts ""

      puts "School district metrics by level_1_category:"
      Metric.where(data_source: :osc)
            .where("key LIKE 'school_%'")
            .group(:level_1_category)
            .count
            .sort_by { |_, v| -v }
            .each do |cat, count|
              puts "  #{cat || 'nil'}: #{count}"
      end
      puts ""
    end

    puts "Current totals:"
    puts "  Total Metrics:          #{Metric.count}"
    puts "  School District Metrics: #{Metric.where("key LIKE 'school_%'").count}"
  end
end
# rubocop:enable Metrics/ClassLength

# Service class for importing school district financial data
# rubocop:disable Metrics/ClassLength
class SchoolDistrictImporter
  CSV_DIR = Rails.root.join("db/seeds/osc_school_district_data")
  OSC_SOURCE_URL = "https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm"

  # Files 2012-2014 have no header row - skip them for now
  YEARS_WITHOUT_HEADERS = [2012, 2013, 2014].freeze

  # Columns to skip (metadata, not financial data)
  METADATA_COLUMNS = (
    SchoolDistrictMetricCreator::METADATA_COLUMNS + ["District Type"]
  ).freeze

  # Normalize column names across years (old name => canonical name matching 2024)
  COLUMN_ALIASES = {
    "Total Debt Outstanding at End of FY" => "Debt Outstanding",
    "Sanitation" => "Sanitation Fees"
  }.freeze

  attr_reader :dry_run, :stats, :errors

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
    @errors = []
    @entity_cache = {}
    @metric_cache = {}
    @document_cache = {}
  end

  def run(year: nil)
    puts "=" * 70
    puts dry_run ? "School District Import PREVIEW (dry run)" : "School District Import"
    puts "=" * 70
    puts ""

    files = csv_files(year)
    if files.empty?
      puts "No CSV files found#{" for year #{year}" if year}"
      return
    end

    puts "Found #{files.count} CSV file(s) to process"
    puts ""

    # Pre-load caches for performance
    load_entity_cache
    load_metric_cache

    files.each { |file| process_file(file) }

    print_summary
  end

  private

  def csv_files(year)
    if year
      if YEARS_WITHOUT_HEADERS.include?(year)
        puts "WARNING: Year #{year} has no headers, skipping"
        return []
      end
      file = CSV_DIR.join("leveltwo#{year.to_s[-2..]}.csv")
      File.exist?(file) ? [file] : []
    else
      # Filter out years without headers
      Dir.glob(CSV_DIR.join("leveltwo*.csv")).reject do |f|
        file_year = extract_year_from_filename(File.basename(f))
        YEARS_WITHOUT_HEADERS.include?(file_year)
      end
    end
  end

  def load_entity_cache
    puts "Loading entity cache..."
    Entity.where(kind: :school_district).find_each do |entity|
      @entity_cache[entity.osc_municipal_code] = entity
    end
    puts "  Loaded #{@entity_cache.size} school districts"
  end

  def load_metric_cache
    puts "Loading metric cache..."
    Metric.where("key LIKE 'school_%'").find_each do |metric|
      @metric_cache[metric.key] = metric
    end
    puts "  Loaded #{@metric_cache.size} school district metrics"
    puts ""
  end

  def process_file(file)
    year = extract_year_from_filename(File.basename(file))
    puts "-" * 40
    puts "Processing: #{File.basename(file)} (FY #{year})"

    row_count = 0
    skipped_empty = 0

    CSV.foreach(file, headers: true) do |row|
      row_count += 1
      skipped_empty += process_row(row, year)
    end

    puts "  Rows: #{row_count}, Skipped empty values: #{skipped_empty}"
    puts ""
  end

  def process_row(row, year)
    muni_code = row["Muni Code"]
    return 0 if muni_code.blank?

    entity = find_entity(muni_code, row["Entity Name"])
    return 0 unless entity

    document = find_or_create_document(entity, year) unless dry_run

    skipped = 0
    row.headers.each do |col|
      next if col.blank?
      next if METADATA_COLUMNS.include?(col)

      if should_skip_value?(row[col])
        skipped += 1
        next
      end

      process_observation(entity, document, col, row[col], year)
    end

    skipped
  end

  def find_entity(muni_code, name)
    return @entity_cache[muni_code] if @entity_cache.key?(muni_code)

    # Not in cache - likely a new district or data issue
    stats[:entities_not_found] += 1
    errors << "Entity not found: #{name} (#{muni_code})" if errors.size < 20
    nil
  end

  def find_or_create_document(entity, year)
    cache_key = "#{entity.id}-#{year}"
    return @document_cache[cache_key] if @document_cache.key?(cache_key)

    document = Document.find_or_create_by!(
      entity: entity,
      doc_type: "osc_school_afr",
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

  def process_observation(entity, document, col, value, year)
    # Normalize column name to match 2024 canonical names
    normalized_col = normalize_column_name(col)
    metric_key = metric_key_for(normalized_col)
    metric = @metric_cache[metric_key]

    unless metric
      stats[:metrics_not_found] += 1
      errors << "Metric not found: #{col} (key: #{metric_key})" if errors.size < 20
      return
    end

    amount = parse_amount(value)
    return unless amount

    if dry_run
      stats[:would_create] += 1
      return
    end

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

  def extract_year_from_filename(filename)
    # leveltwo24.csv -> 2024, leveltwo12.csv -> 2012
    year_suffix = filename.match(/leveltwo(\d{2})\.csv/)[1].to_i
    year_suffix < 50 ? 2000 + year_suffix : 1900 + year_suffix
  end

  def metric_key_for(col)
    "school_#{col.parameterize.underscore}"
  end

  def normalize_column_name(col)
    COLUMN_ALIASES.fetch(col, col)
  end

  def parse_amount(value)
    return nil if value.blank?

    BigDecimal(value.to_s.delete(","))
  rescue ArgumentError
    nil
  end

  def should_skip_value?(value)
    return true if value.blank?

    amount = parse_amount(value)
    amount.nil? || amount.zero?
  end

  def print_summary
    puts ""
    puts "=" * 70
    puts dry_run ? "PREVIEW SUMMARY (no changes made)" : "IMPORT SUMMARY"
    puts "=" * 70
    puts ""

    if dry_run
      puts "Would create:           #{stats[:would_create]} observations"
    else
      puts "Documents created:      #{stats[:documents_created]}"
      puts "Observations created:   #{stats[:observations_created]}"
      puts "Observations updated:   #{stats[:observations_updated]}"
      puts "Observations unchanged: #{stats[:observations_unchanged]}"
    end
    puts ""

    if stats[:entities_not_found].positive? || stats[:metrics_not_found].positive?
      puts "WARNINGS:"
      puts "  Entities not found: #{stats[:entities_not_found]}" if stats[:entities_not_found].positive?
      puts "  Metrics not found:  #{stats[:metrics_not_found]}" if stats[:metrics_not_found].positive?
      puts ""
    end

    if errors.any?
      puts "ERRORS (first 20):"
      errors.each { |e| puts "  - #{e}" }
      puts ""
    end

    puts "Current totals:"
    puts "  School Districts: #{Entity.where(kind: :school_district).count}"
    puts "  Documents:        #{Document.count}"
    puts "  Observations:     #{Observation.count}"
    school_obs_count = Observation.joins(:metric).where("metrics.key LIKE ?", "school_%").count
    puts "  School District Observations: #{school_obs_count}"
  end
end
# rubocop:enable Metrics/ClassLength

# Service class for calculating derived school district metrics
# rubocop:disable Metrics/ClassLength
class SchoolDistrictDerivedMetrics
  # Per-pupil metrics: divide numerator by enrollment
  PER_PUPIL_METRICS = [
    { key: "school_per_pupil_spending", label: "Per-Pupil Spending",
      numerator: "school_total_expenditures", display: "currency_rounded" },
    { key: "school_per_pupil_instruction", label: "Per-Pupil Instruction",
      numerator: "school_instruction", display: "currency_rounded" },
    { key: "school_per_pupil_administration", label: "Per-Pupil Administration",
      numerator: "school_administration", display: "currency_rounded" },
    { key: "school_per_pupil_property_tax", label: "Per-Pupil Property Tax",
      numerator: "school_real_property_taxes", display: "currency_rounded" },
    { key: "school_per_pupil_debt", label: "Per-Pupil Debt",
      numerator: "school_debt_outstanding", display: "currency_rounded" }
  ].freeze

  # Percentage metrics: (numerator / denominator) * 100
  PERCENTAGE_METRICS = [
    { key: "school_admin_overhead_pct", label: "Administrative Overhead %",
      numerator: "school_administration", denominator: "school_total_expenditures" },
    { key: "school_state_aid_dependency_pct", label: "State Aid Dependency %",
      numerator: :state_aid_total, denominator: :revenue_total }
  ].freeze

  # State aid keys to sum for total
  STATE_AID_KEYS = %w[
    school_state_aid_education
    school_state_aid_community_services
    school_state_aid_culture_and_recreation
    school_state_aid_economic_development
    school_state_aid_general_government
    school_state_aid_health
    school_state_aid_public_safety
    school_state_aid_sanitation
    school_state_aid_social_services
    school_state_aid_transportation
    school_state_aid_utilities
    school_unrestricted_state_aid
    school_miscellaneous_state_aid
  ].freeze

  attr_reader :dry_run, :stats

  def initialize(dry_run: false)
    @dry_run = dry_run
    @stats = Hash.new(0)
    @metric_cache = {}
  end

  def run
    puts "=" * 70
    puts dry_run ? "Derived Metrics Calculation PREVIEW (dry run)" : "Derived Metrics Calculation"
    puts "=" * 70
    puts ""

    # Step 1: Create derived metrics (if not exists)
    create_derived_metrics

    # Step 2: Load source metrics
    load_metric_cache

    # Step 3: Calculate and store observations
    calculate_all_observations

    print_summary
  end

  private

  def create_derived_metrics
    puts "Creating derived metric definitions..."
    puts ""

    (PER_PUPIL_METRICS + PERCENTAGE_METRICS).each do |config|
      create_metric(config)
    end

    puts ""
  end

  def create_metric(config)
    existing = Metric.find_by(key: config[:key])
    if existing
      puts "  Exists: #{config[:label]}"
      stats[:metrics_exist] += 1
      return
    end

    if dry_run
      puts "  Would create: #{config[:label]}"
      stats[:metrics_would_create] += 1
    else
      Metric.create!(
        key: config[:key],
        label: config[:label],
        data_source: :derived,
        value_type: :numeric,
        display_format: config[:display] || "percentage",
        description: "Derived metric for school districts"
      )
      puts "  Created: #{config[:label]}"
      stats[:metrics_created] += 1
    end
  end

  def load_metric_cache
    puts "Loading source metrics..."
    Metric.where("key LIKE 'school_%'").find_each do |m|
      @metric_cache[m.key] = m
    end
    puts "  Loaded #{@metric_cache.size} metrics"
    puts ""
  end

  def calculate_all_observations
    puts "Calculating derived observations..."
    puts ""

    years = Observation.joins(:metric)
                       .where("metrics.key LIKE 'school_%'")
                       .distinct.pluck(:fiscal_year).sort

    puts "  Years with data: #{years.first}..#{years.last}"
    puts ""

    Entity.school_districts.find_each.with_index do |entity, idx|
      years.each do |year|
        calculate_for_entity_year(entity, year)
      end
      print_progress(idx + 1) if ((idx + 1) % 100).zero?
    end

    puts ""
  end

  def calculate_for_entity_year(entity, year)
    # Load base values for this entity/year
    base_values = load_base_values(entity, year)

    # Find source document for derived observations
    document = find_source_document(entity, year)
    return if document.nil? && !dry_run

    # Calculate per-pupil metrics
    enrollment = base_values["school_enrollment"]
    if enrollment&.positive?
      PER_PUPIL_METRICS.each do |config|
        numerator = base_values[config[:numerator]]
        next unless numerator

        value = (numerator / enrollment).round(2)
        save_observation(entity, config[:key], year, value, document)
      end
    else
      stats[:missing_enrollment] += 1
    end

    # Calculate percentage metrics
    PERCENTAGE_METRICS.each do |config|
      numerator = resolve_value(config[:numerator], base_values)
      denominator = resolve_value(config[:denominator], base_values)

      next unless numerator && denominator&.positive?

      value = (numerator / denominator * 100).round(2)
      save_observation(entity, config[:key], year, value, document)
    end
  end

  def find_source_document(entity, year)
    Document.find_by(entity: entity, fiscal_year: year, doc_type: "osc_school_afr")
  end

  def load_base_values(entity, year)
    Observation.joins(:metric)
               .where(entity: entity, fiscal_year: year)
               .where("metrics.key LIKE 'school_%'")
               .pluck("metrics.key", :value_numeric)
               .to_h
  end

  def resolve_value(source, base_values)
    case source
    when String
      base_values[source]
    when :state_aid_total
      STATE_AID_KEYS.sum { |k| base_values[k].to_f }
    when :revenue_total
      # Sum all revenue metrics
      base_values.select { |k, _| revenue_key?(k) }.values.sum
    end
  end

  def revenue_key?(key)
    # Revenue metrics have account_type: revenue
    metric = @metric_cache[key]
    metric&.revenue_account?
  end

  def save_observation(entity, metric_key, year, value, document)
    if dry_run
      stats[:would_create] += 1
      return
    end

    metric = @metric_cache[metric_key]
    unless metric
      stats[:metric_not_found] += 1
      return
    end

    obs = Observation.find_or_initialize_by(
      entity: entity,
      metric: metric,
      document: document,
      fiscal_year: year
    )

    if obs.new_record?
      obs.value_numeric = value
      obs.verification_status = :verified
      obs.save!
      stats[:created] += 1
    elsif obs.value_numeric != value
      obs.update!(value_numeric: value)
      stats[:updated] += 1
    else
      stats[:unchanged] += 1
    end
  end

  def print_progress(count)
    total = Entity.school_districts.count
    puts "  Processed #{count}/#{total} districts..."
  end

  def print_summary
    puts ""
    puts "=" * 70
    puts dry_run ? "PREVIEW SUMMARY (no changes made)" : "CALCULATION SUMMARY"
    puts "=" * 70
    puts ""

    puts "Metrics:"
    if dry_run
      puts "  Would create:     #{stats[:metrics_would_create]}"
    else
      puts "  Created:          #{stats[:metrics_created]}"
    end
    puts "  Already exist:    #{stats[:metrics_exist]}"
    puts ""

    puts "Observations:"
    if dry_run
      puts "  Would create:     #{stats[:would_create]}"
    else
      puts "  Created:          #{stats[:created]}"
      puts "  Updated:          #{stats[:updated]}"
      puts "  Unchanged:        #{stats[:unchanged]}"
    end
    puts ""

    if stats[:missing_enrollment].positive?
      puts "Warnings:"
      puts "  Missing enrollment: #{stats[:missing_enrollment]} entity-years skipped"
      puts ""
    end

    puts "Derived metrics summary:"
    (PER_PUPIL_METRICS + PERCENTAGE_METRICS).each do |config|
      count = Observation.joins(:metric).where(metrics: { key: config[:key] }).count
      puts "  #{config[:label]}: #{count} observations"
    end
  end
end
# rubocop:enable Metrics/ClassLength
