# frozen_string_literal: true

require "csv"

namespace :icma do
  desc "Import ICMA Council-Manager (C) recognized entities from CSV (creates if not found)"
  task import: :environment do
    csv_path = Rails.root.join("db/seeds/NY_Recognized_CM_Communities.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      exit 1
    end

    puts "Starting ICMA import from #{csv_path}..."
    puts "=" * 60

    updated = 0
    created = 0
    skipped_g = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      name = row["Local Government"]
      form = row["Form of Recognition"]
      year = row["Year of Recognition"]

      # Skip G (General Management) entities - import C (Council-Manager) only
      if form == "G"
        puts "  SKIP (G): #{name}"
        skipped_g += 1
        next
      end

      # Parse entity type and name from the CSV format
      # Examples: "City of New Rochelle", "County of Westchester", "Village of Port Chester", "Town of Mamaroneck"
      parsed = parse_entity_name(name)

      unless parsed
        puts "  ERROR: Could not parse entity name: #{name}"
        errors << { name: name, error: "Could not parse entity name" }
        next
      end

      kind, entity_name = parsed

      # Find or create the entity in the database
      entity = Entity.find_or_initialize_by(name: entity_name, kind: kind, state: "NY")
      is_new = entity.new_record?

      # Set slug if new entity - use kind suffix if base slug is taken
      if is_new && entity.slug.blank?
        base_slug = entity_name.parameterize
        entity.slug = if Entity.exists?(slug: base_slug)
                        "#{base_slug}-#{kind}"
                      else
                        base_slug
                      end
      end

      # Update governance fields
      entity.government_structure = "council_manager"
      entity.icma_recognition_year = year.to_i

      if entity.save
        if is_new
          puts "  CREATED: #{entity.name} (#{entity.kind}) -> council_manager, ICMA #{year}"
          created += 1
        else
          puts "  UPDATED: #{entity.name} (#{entity.kind}) -> council_manager, ICMA #{year}"
          updated += 1
        end
      else
        puts "  ERROR: #{entity_name} - #{entity.errors.full_messages.join(', ')}"
        errors << { name: entity_name, error: entity.errors.full_messages }
      end
    end

    puts "=" * 60
    puts "ICMA Import Complete!"
    puts "  Created: #{created}"
    puts "  Updated: #{updated}"
    puts "  Skipped (G entities): #{skipped_g}"
    puts "  Errors: #{errors.count}"

    if errors.any?
      puts "\nErrors:"
      errors.each { |e| puts "  - #{e[:name]}: #{e[:error]}" }
    end
  end
end

# Make the helper method available at top level for the rake task
def parse_entity_name(full_name)
  patterns = {
    /^City of (.+)$/ => "city",
    /^County of (.+)$/ => "county",
    /^Village of (.+)$/ => "village",
    /^Town of (.+)$/ => "town"
  }

  patterns.each do |pattern, kind|
    match = full_name.match(pattern)
    return [kind, match[1]] if match
  end

  nil
end
