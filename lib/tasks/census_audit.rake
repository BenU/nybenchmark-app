# frozen_string_literal: true

require "net/http"
require "json"

namespace :census do
  desc "Audit Census data for accuracy"
  task audit: :environment do
    puts "=" * 70
    puts "CENSUS DATA AUDIT"
    puts "=" * 70
    puts ""

    # Sample cities across different sizes and regions
    audit_cities = [
      { name: "New York City", expected_2023_pop_range: 8_000_000..9_000_000 },
      { name: "Buffalo", expected_2023_pop_range: 250_000..300_000 },
      { name: "Rochester", expected_2023_pop_range: 200_000..230_000 },
      { name: "Yonkers", expected_2023_pop_range: 200_000..220_000 },
      { name: "Syracuse", expected_2023_pop_range: 140_000..160_000 },
      { name: "Albany", expected_2023_pop_range: 95_000..110_000 },
      { name: "Schenectady", expected_2023_pop_range: 65_000..75_000 },
      { name: "Utica", expected_2023_pop_range: 60_000..70_000 },
      { name: "Binghamton", expected_2023_pop_range: 45_000..55_000 },
      { name: "Ithaca", expected_2023_pop_range: 30_000..35_000 },
      { name: "Saratoga Springs", expected_2023_pop_range: 28_000..35_000 },
      { name: "White Plains", expected_2023_pop_range: 55_000..65_000 },
      { name: "Mount Vernon", expected_2023_pop_range: 70_000..80_000 },
      { name: "Niagara Falls", expected_2023_pop_range: 48_000..55_000 },
      { name: "Troy", expected_2023_pop_range: 48_000..55_000 },
      { name: "Sherrill", expected_2023_pop_range: 2_500..4_000 }
    ]

    pop_metric = Metric.find_by(key: "census_b01003_001e")
    income_metric = Metric.find_by(key: "census_b19013_001e")
    home_value_metric = Metric.find_by(key: "census_b25077_001e")

    errors = []
    warnings = []

    puts "1. POPULATION SANITY CHECK (2023)"
    puts "-" * 70
    audit_cities.each do |city_data|
      entity = Entity.find_by(name: city_data[:name], state: "NY")
      unless entity
        errors << "Entity not found: #{city_data[:name]}"
        next
      end

      obs = Observation.find_by(entity: entity, metric: pop_metric, fiscal_year: 2023)
      unless obs
        errors << "No 2023 population for #{city_data[:name]}"
        next
      end

      pop = obs.value_numeric.to_i
      formatted_pop = number_with_commas(pop)
      range = city_data[:expected_2023_pop_range]

      if range.include?(pop)
        status = "OK"
      else
        status = "UNEXPECTED"
        errors << "#{city_data[:name]}: #{formatted_pop} not in expected range #{range}"
      end

      puts "  #{city_data[:name].ljust(20)} #{formatted_pop.rjust(12)} #{status}"
    end

    puts ""
    puts "2. POPULATION TREND CHECK (should generally be stable year-over-year)"
    puts "-" * 70

    %w[Buffalo Rochester Syracuse Albany Ithaca].each do |city_name|
      entity = Entity.find_by(name: city_name, state: "NY")
      next unless entity

      observations = Observation.where(entity: entity, metric: pop_metric)
                                .order(:fiscal_year)
                                .pluck(:fiscal_year, :value_numeric)

      puts "  #{city_name}:"
      prev_pop = nil
      observations.each do |year, pop|
        pop_int = pop.to_i
        formatted = number_with_commas(pop_int)

        change = ""
        if prev_pop
          pct_change = ((pop_int - prev_pop).to_f / prev_pop * 100).round(1)
          if pct_change.abs > 10
            change = " <- #{pct_change}% SUSPICIOUS"
            warnings << "#{city_name} #{year}: #{pct_change}% change from prior year"
          elsif pct_change.abs > 5
            change = " <- #{pct_change}%"
          end
        end

        puts "    #{year}: #{formatted.rjust(10)}#{change}"
        prev_pop = pop_int
      end
      puts ""
    end

    puts "3. MEDIAN INCOME SANITY CHECK (2023)"
    puts "-" * 70
    sample_cities = %w[Yonkers Buffalo Syracuse Albany Ithaca Sherrill]
    sample_cities.each do |city_name|
      entity = Entity.find_by(name: city_name, state: "NY")
      next unless entity

      obs = Observation.find_by(entity: entity, metric: income_metric, fiscal_year: 2023)
      next unless obs

      income = obs.value_numeric.to_i
      formatted = "$#{number_with_commas(income)}"

      status = income.between?(25_000, 150_000) ? "OK" : "SUSPICIOUS"
      errors << "#{city_name} median income: #{formatted} seems wrong" unless income.between?(25_000, 150_000)

      puts "  #{city_name.ljust(20)} #{formatted.rjust(12)} #{status}"
    end

    puts ""
    puts "4. MEDIAN HOME VALUE SANITY CHECK (2023)"
    puts "-" * 70
    sample_cities.each do |city_name|
      entity = Entity.find_by(name: city_name, state: "NY")
      next unless entity

      obs = Observation.find_by(entity: entity, metric: home_value_metric, fiscal_year: 2023)
      next unless obs

      value = obs.value_numeric.to_i
      formatted = "$#{number_with_commas(value)}"

      status = value.between?(50_000, 1_500_000) ? "OK" : "SUSPICIOUS"
      errors << "#{city_name} home value: #{formatted} seems wrong" unless value.between?(50_000, 1_500_000)

      puts "  #{city_name.ljust(20)} #{formatted.rjust(12)} #{status}"
    end

    puts ""
    puts "5. CROSS-REFERENCE: VERIFY FIPS CODES VIA API"
    puts "-" * 70

    api_key = ENV.fetch("CENSUS_API_KEY", nil)
    if api_key.nil?
      puts "  Skipping API verification (no CENSUS_API_KEY)"
    else
      url = "https://api.census.gov/data/2023/acs/acs5?get=NAME,B01003_001E&for=place:*&in=state:36&key=#{api_key}"
      response = Net::HTTP.get(URI(url))
      census_data = JSON.parse(response)

      census_lookup = {}
      census_data[1..].each do |row|
        name, pop, _state, fips = row
        census_lookup[name] = { fips: fips, pop: pop.to_i }
      end

      fips_file = Rails.root.join("db/seeds/census_data/entity_fips_mapping.yml")
      mapping = YAML.load_file(fips_file)

      mismatches = []
      mapping["cities"].merge(mapping["nyc"]).each do |db_name, expected_fips|
        census_name = db_name == "New York City" ? "New York city, New York" : "#{db_name} city, New York"
        census_entry = census_lookup[census_name]

        unless census_entry
          mismatches << "#{db_name}: Not found in Census as \"#{census_name}\""
          next
        end

        if census_entry[:fips] != expected_fips
          mismatches << "#{db_name}: FIPS mismatch - mapping has #{expected_fips}, Census has #{census_entry[:fips]}"
        end

        entity = Entity.find_by(name: db_name, state: "NY")
        next unless entity

        our_obs = Observation.find_by(entity: entity, metric: pop_metric, fiscal_year: 2023)
        next unless our_obs
        next if our_obs.value_numeric.to_i == census_entry[:pop]

        db_pop = our_obs.value_numeric.to_i
        api_pop = census_entry[:pop]
        mismatches << "#{db_name}: Population mismatch - DB has #{db_pop}, API has #{api_pop}"
      end

      if mismatches.empty?
        puts "  All 62 FIPS codes verified against Census API - OK"
        puts "  All population values match Census API - OK"
      else
        mismatches.each { |m| puts "  MISMATCH: #{m}" }
        errors.concat(mismatches)
      end
    end

    puts ""
    puts "=" * 70
    puts "AUDIT SUMMARY"
    puts "=" * 70
    if errors.empty? && warnings.empty?
      puts "All checks passed - data looks good!"
    else
      if errors.any?
        puts ""
        puts "ERRORS (#{errors.count}):"
        errors.each { |e| puts "  - #{e}" }
      end
      if warnings.any?
        puts ""
        puts "WARNINGS (#{warnings.count}):"
        warnings.each { |w| puts "  - #{w}" }
      end
    end
    puts ""
  end

  private

  def number_with_commas(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
