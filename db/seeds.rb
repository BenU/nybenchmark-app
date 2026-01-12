# db/seeds.rb
require 'csv'
require 'yaml'

puts "🌱 Starting Database Seed..."

# ====================================================
# 1. ENTITIES (The Governments)
# ====================================================
puts "\n--- Seeding Entities ---"

# Canonical seed set (for now): 2 cities + 2 school districts
city_rows = [
  {
    name: "Yonkers",
    slug: "yonkers",
    kind: "city",
    government_structure: "strong_mayor",
    fiscal_autonomy: "independent",
    organization_note: "Council President + 6 District Representatives"
  },
  {
    name: "New Rochelle",
    slug: "new_rochelle",
    kind: "city",
    government_structure: "council_manager",
    fiscal_autonomy: "independent",
    organization_note: "Council + City Manager"
  }
]

cities = {}

city_rows.each do |attrs|
  e = Entity.find_or_initialize_by(slug: attrs[:slug])
  e.assign_attributes(attrs.merge(state: "NY"))
  e.save!
  cities[attrs[:slug]] = e
  print "."
end

school_rows = [
  {
    name: "Yonkers Public Schools",
    slug: "yonkers_schools",
    kind: "school_district",
    fiscal_autonomy: "dependent",
    school_legal_type: "big_five",
    board_selection: "appointed",
    executive_selection: "appointed_professional",
    organization_note: "Mayor-appointed board (Big Five structure)",
    parent: cities.fetch("yonkers")
  },
  {
    name: "New Rochelle City School District",
    slug: "new_rochelle_schools",
    kind: "school_district",
    fiscal_autonomy: "independent",
    school_legal_type: "small_city",
    board_selection: "elected",
    executive_selection: "appointed_professional",
    organization_note: "Elected board; superintendent appointed"
  }
]

school_rows.each do |attrs|
  e = Entity.find_or_initialize_by(slug: attrs[:slug])
  e.assign_attributes(attrs.merge(state: "NY"))
  e.parent = attrs[:parent] if attrs.key?(:parent)
  e.save!
  print "."
end

puts "\n✅ Entities synced."

# ====================================================
# 2. METRICS (Definitions)
# ====================================================
puts "\n--- Seeding Metrics ---"
metrics_path = Rails.root.join('db', 'seeds', 'metrics.yml')

if File.exist?(metrics_path)
  YAML.load_file(metrics_path).each do |key, data|
    m = Metric.find_or_initialize_by(key: data['key'])
    m.update!(label: data['label'], unit: data['unit'], description: data['description'])
    print "."
  end
end
puts "\n✅ Metrics synced."

# ====================================================
# 3. DOCUMENTS (From sources.csv)
# ====================================================
puts "\n--- Seeding Documents ---"
sources_path = Rails.root.join('db', 'seeds', 'sources.csv')
doc_lookup = {} 

CSV.foreach(sources_path, headers: true) do |row|
  entity = Entity.find_by(slug: row['Entity'])
  
  if entity.nil?
    puts "   ⚠️  Skipping Doc #{row['Doc_Key']}: Entity '#{row['Entity']}' not found."
    next
  end

  doc = Document.find_or_initialize_by(
    entity: entity,
    fiscal_year: row['Fiscal_Year'],
    doc_type: row['Type']
  )

  doc.title = row['Title']
  
  # 1. Set Valid URL (Required by Validation)
  doc.source_url = row['Source_URL']

  # 2. Attach Local File (If filename provided in CSV)
  filename = row['Local_Filename']
  if filename.present?
    file_path = Rails.root.join('db', 'seeds', 'documents', filename)
    
    if File.exist?(file_path)
      # Only attach if not already attached (Optimizes re-seeding)
      unless doc.file.attached?
        doc.file.attach(io: File.open(file_path), filename: filename)
        print "📎"
      end
    else
      puts "\n   ⚠️  Warning: File '#{filename}' listed in CSV but not found in db/seeds/documents/."
    end
  end

  if doc.save
    doc_lookup[row['Doc_Key']] = doc # Save for linking Observations
    print "."
  else
    puts "\n   ❌ Error saving #{doc.title}: #{doc.errors.full_messages.join(', ')}"
  end
end
puts "\n✅ Documents synced."

# ====================================================
# 4. OBSERVATIONS (From observations.csv)
# ====================================================
puts "\n--- Seeding Observations ---"
obs_path = Rails.root.join('db', 'seeds', 'observations.csv')

CSV.foreach(obs_path, headers: true) do |row|
  entity = Entity.find_by(slug: row['Entity'])
  doc = doc_lookup[row['Doc_Key']] # Precise lookup

  # Auto-Create Metric if missing
  metric = Metric.find_or_create_by(key: row['Metric']) do |m|
    m.label = row['Metric'].titleize
    m.description = "Auto-generated from seed."
  end

  if entity && doc
    obs = Observation.find_or_initialize_by(
      entity: entity,
      metric: metric,
      document: doc,
      fiscal_year: doc.fiscal_year
    )
    
    obs.page_reference = row['Page_Ref'] || "n/a"

    # Handle numeric vs text values
    raw_val = row['Value'].to_s.gsub(',', '').strip
    if raw_val.match?(/^-?\d+(\.\d+)?$/)
      obs.value_numeric = raw_val.to_f
      obs.value_text = nil
    else
      obs.value_numeric = nil
      obs.value_text = row['Value']
    end

    if obs.save
      print "."
    else
      puts "   ❌ Failed Obs: #{obs.errors.full_messages}"
    end
  else
    puts "   ⚠️  Skipping Obs: Doc_Key '#{row['Doc_Key']}' not found."
  end
end
puts "\n🎉 Seed Complete!"