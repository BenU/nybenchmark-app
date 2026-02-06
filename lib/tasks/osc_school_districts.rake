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
