require 'csv'
require 'fileutils'

puts "🌱 Starting Seed Process..."

# --- Configuration ---
SEEDS_DIR = Rails.root.join('db', 'seeds')
DOCS_DIR  = SEEDS_DIR.join('documents')
SOURCES_CSV = SEEDS_DIR.join('sources.csv')
OBSERVATIONS_CSV = SEEDS_DIR.join('observations.csv')

# --- Helper: Extract URL from text ---
def extract_url(text)
  # Matches http/https URL until whitespace
  match = text.to_s.match(%r{(https?://[^\s]+)})
  match ? match[1] : text
end

# --- Helper: Clean Numeric Values ---
def clean_numeric(value)
  return nil if value.blank?
  # Remove $, %, commas, and whitespace. Handle "(123)" as negative if needed.
  cleaned = value.to_s.gsub(/[$,\s%]/, '')
  return nil unless cleaned.match?(/^-?\d+(\.\d+)?$/)
  cleaned.to_f
end

# --- Step 0: Scoped Cleaning (Idempotency) ---
puts "🧹 Cleaning up data for import targets..."

# Identify the slugs we are about to import
slugs_to_import = ['yonkers', 'new_rochelle', 'shared']

# Find existing entities matching these slugs
target_entities = Entity.where(slug: slugs_to_import)

# Delete observations ONLY for these entities
# This preserves data for 'buffalo' or 'albany' if they exist
if target_entities.exists?
  count = Observation.where(entity: target_entities).count
  puts "   - Removing #{count} old observations for #{slugs_to_import.join(', ')}"
  Observation.where(entity: target_entities).destroy_all
  
  # Optional: Remove documents for these entities if you want a full file reset
  # Document.where(entity: target_entities).destroy_all 
end

# --- Step 1: Create Entities ---
puts "🏗️  Creating Entities..."
entities = {}

# Create standard cities
['yonkers', 'new_rochelle'].each do |slug|
  name = slug.titleize
  entities[slug] = Entity.find_or_create_by!(slug: slug) do |e|
    e.name = name
    e.state = "NY"
    e.kind = "city"
  end
end

# Create a special Entity for statewide/shared documents
# Changed kind to 'state' per your request
entities['shared'] = Entity.find_or_create_by!(slug: 'shared') do |e|
  e.name = "New York State" # More accurate name
  e.state = "NY"
  e.kind = "state" 
end

# --- Step 2: Import Sources (Documents) ---
puts "📚 Importing Documents..."
doc_lookup = {} # Map Doc_Key -> Document Object

CSV.foreach(SOURCES_CSV, headers: true) do |row|
  doc_key = row['Doc_Key']
  entity_slug = row['Entity']
  
  # Find the owner entity (City or Shared)
  owner_entity = entities[entity_slug]
  unless owner_entity
    puts "   ⚠️  Skipping document #{doc_key}: Entity '#{entity_slug}' not found."
    next
  end

  # Determine Source URL
  if row['Type'] == 'web'
    source_url = extract_url(row['Filename_or_URL'])
  else
    source_url = "Local PDF Import" 
  end

  # Find or Create Document
  # We search by title AND entity to ensure we don't duplicate if re-running
  document = Document.find_or_create_by!(title: row['Title'], entity: owner_entity) do |d|
    d.fiscal_year = row['Fiscal_Year']
    d.doc_type = row['Type']
    d.source_url = source_url
  end

  # Attach PDF if applicable and not already attached
  if row['Type'] == 'pdf' && !document.file.attached?
    filename = row['Filename_or_URL']
    file_path = DOCS_DIR.join(filename)

    if File.exist?(file_path)
      document.file.attach(
        io: File.open(file_path),
        filename: filename,
        content_type: 'application/pdf'
      )
      puts "   📎 Attached: #{filename}"
    else
      puts "   ❌ File Missing: #{filename} (Expected at #{file_path})"
    end
  end

  doc_lookup[doc_key] = document
end

# --- Step 3: Import Observations ---
puts "📊 Importing Observations..."

CSV.foreach(OBSERVATIONS_CSV, headers: true) do |row|
  entity_slug = row['Entity']
  metric_key  = row['Metric']
  doc_key     = row['Doc_Key']
  raw_value   = row['Value']
  
  entity = entities[entity_slug]
  document = doc_lookup[doc_key]
  
  # Create Metric if missing
  metric = Metric.find_or_create_by!(key: metric_key) do |m|
    m.label = metric_key.titleize
  end

  # Determine Value (Numeric or Text)
  val_numeric = clean_numeric(raw_value)
  val_text = val_numeric ? nil : raw_value

  # Create Observation
  Observation.create!(
    entity: entity,
    metric: metric,
    document: document,
    fiscal_year: document&.fiscal_year || 2024,
    page_reference: row['Page_Ref'].presence || "N/A",
    value_numeric: val_numeric,
    value_text: val_text
  )
rescue ActiveRecord::RecordInvalid => e
  puts "   ⚠️  Skipping #{metric_key} for #{entity_slug}: #{e.message}"
end

puts "✅ Seeding Complete!"