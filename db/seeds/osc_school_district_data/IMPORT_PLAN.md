# School District Import Plan

## Overview

Import ~691 school districts with 13 years of financial data (2012-2024) plus outcomes data from NYSED. This enables:
- Per-pupil spending comparisons
- Economies of scale analysis (spending vs district size)
- "Bang for buck" analysis (spending vs outcomes)

## Data Sources

| Source | Data | Years | Format |
|--------|------|-------|--------|
| OSC Bulk Downloads | Financial (revenue, expenditure, balance sheet) | 2012-2024 | CSV (converted from XLSX) |
| NYSED Fiscal Profiles | Per-pupil breakdowns, wealth measures | 1993-2024 | Excel |
| NYSED Data Downloads | Test scores, graduation rates, enrollment | 2006-2024 | Excel/Access |

## Phase 1: Entity Creation

### Create ~691 school district entities

```ruby
# Rake task: osc:create_school_districts

CSV.foreach("leveltwo24.csv", headers: true) do |row|
  Entity.find_or_create_by!(osc_municipal_code: row["Muni Code"]) do |e|
    e.name = row["Entity Name"]
    e.slug = row["Entity Name"].parameterize
    e.kind = :school_district
    e.school_legal_type = map_class_to_legal_type(row["Class Description"])
    e.county = row["County"]
    # parent_id set in Phase 1b for City Public School districts
  end
end

def map_class_to_legal_type(osc_class)
  case osc_class
  when "City Public School"
    # Determine big_five vs small_city based on name
    %w[Buffalo Rochester Syracuse Yonkers].any? { |c| name.include?(c) } ? :big_five : :small_city
  when "Central", "Independent Superintendent", "Central High"
    :central
  when "Union Free"
    :union_free
  when "Common"
    :common
  end
end
```

### Link City Public School districts to parent cities

```ruby
# The 61 City Public School districts are fiscally dependent
# Link them to their parent city entity

Entity.where(kind: :school_district, school_legal_type: [:big_five, :small_city]).find_each do |district|
  city_name = district.name.gsub(" City School District", "").gsub(" School District", "")
  city = Entity.find_by(kind: :city, name: "City of #{city_name}")
  district.update!(parent_id: city.id) if city
end
```

## Phase 2: Metric Creation

### Financial metrics from OSC columns

Create one metric per financial column (~170 metrics):

```ruby
# Metadata columns (not metrics)
METADATA_COLS = %w[
  Muni\ Code Entity\ Name County Class\ Description
  Fiscal\ Year\ End\ Date Months\ in\ Fiscal\ Period
]

# Special columns (create as metrics with specific handling)
ENROLLMENT_COL = "Enrollment"
FULL_VALUE_COL = "Full Value"  # Property value
DEBT_COL = "Debt Outstanding"

# All other columns are financial metrics
headers = CSV.read("leveltwo24.csv", headers: true).headers
financial_cols = headers - METADATA_COLS - [ENROLLMENT_COL, FULL_VALUE_COL, DEBT_COL]

financial_cols.each do |col_name|
  Metric.find_or_create_by!(
    name: col_name,
    data_source: :osc,
    account_type: infer_account_type(col_name),
    level_1_category: infer_level_1(col_name)
  )
end

def infer_account_type(col_name)
  case col_name
  when /Tax|Aid|Fee|Charge|Revenue|Earning|Property|Sale of Obligations|Transfer/i
    :revenue
  when /Debt Outstanding|Full Value/i
    :balance_sheet
  else
    :expenditure
  end
end
```

### Key metrics to create

| Metric | Type | Source Column |
|--------|------|---------------|
| Enrollment | numeric | `Enrollment` |
| Property Value | numeric | `Full Value` |
| Debt Outstanding | balance_sheet | `Debt Outstanding` |
| Real Property Taxes | revenue | `Real Property Taxes` |
| State Aid - Education | revenue | `State Aid - Education` |
| Instruction | expenditure | `Instruction` |
| Instructional Support | expenditure | `Instructional Support` |
| Pupil Services | expenditure | `Pupil Services` |
| Administration | expenditure | `Administration` |
| Employee Benefits (various) | expenditure | Multiple columns |
| Debt Principal | expenditure | `Debt Principal` |
| Interest on Debt | expenditure | `Interest on Debt` |
| Total Expenditures | expenditure | `Total Expenditures` |

## Phase 3: Financial Data Import

### Import OSC data (2012-2024)

```ruby
# Rake task: osc:import_school_districts

(12..24).each do |year_suffix|
  year = 2000 + year_suffix
  file = "leveltwo#{year_suffix.to_s.rjust(2, '0')}.csv"

  CSV.foreach(file, headers: true) do |row|
    entity = Entity.find_by!(osc_municipal_code: row["Muni Code"])
    fiscal_year = extract_fiscal_year(row["Fiscal Year End Date"])  # Usually June 30 → same calendar year

    # Create document for this filing
    doc = Document.find_or_create_by!(
      entity: entity,
      doc_type: :osc_school_afr,
      fiscal_year: fiscal_year
    ) do |d|
      d.source_type = :bulk_data
      d.source_url = "https://wwe1.osc.state.ny.us/localgov/findata/schools/leveltwo#{year_suffix}.xlsx"
    end

    # Create observations for each financial column
    row.headers.each do |col|
      next if METADATA_COLS.include?(col)
      next if row[col].blank? || row[col].to_f.zero?

      metric = Metric.find_by!(name: col, data_source: :osc)

      Observation.find_or_create_by!(
        entity: entity,
        metric: metric,
        document: doc,
        fiscal_year: fiscal_year
      ) do |o|
        o.value_numeric = row[col].to_f
      end
    end
  end
end
```

### Expected observation count

- 691 districts × 13 years × ~100 non-null columns avg = **~900K observations**
- Plus existing city data: 661K observations
- **Total: ~1.6M observations**

## Phase 4: Derived Metrics

### Per-pupil calculations

```ruby
# After import, calculate derived per-pupil metrics

PERPUPIL_METRICS = [
  { base: "Total Expenditures", derived: "Total Expenditures Per Pupil" },
  { base: "Instruction", derived: "Instruction Per Pupil" },
  { base: "Administration", derived: "Administration Per Pupil" },
  { base: "Real Property Taxes", derived: "Property Tax Per Pupil" },
  { base: "Debt Outstanding", derived: "Debt Per Pupil" },
]

Entity.school_districts.find_each do |entity|
  (2012..2024).each do |year|
    enrollment = entity.observations.joins(:metric)
                       .where(fiscal_year: year, metrics: { name: "Enrollment" })
                       .first&.value_numeric
    next unless enrollment&.positive?

    PERPUPIL_METRICS.each do |config|
      base_value = entity.observations.joins(:metric)
                         .where(fiscal_year: year, metrics: { name: config[:base] })
                         .first&.value_numeric
      next unless base_value

      derived_metric = Metric.find_or_create_by!(
        name: config[:derived],
        data_source: :derived
      )

      Observation.find_or_create_by!(
        entity: entity,
        metric: derived_metric,
        fiscal_year: year
      ) do |o|
        o.value_numeric = base_value / enrollment
      end
    end
  end
end
```

### Administrative overhead ratio

```ruby
# Admin spending as % of total - key efficiency metric
admin = entity.observations.where(metric: admin_metric, fiscal_year: year).first&.value_numeric
total = entity.observations.where(metric: total_metric, fiscal_year: year).first&.value_numeric

admin_ratio = (admin / total * 100).round(2) if admin && total&.positive?
```

### State aid dependency

```ruby
# State aid as % of total revenue - measures fiscal independence
state_aid = sum of all "State Aid - *" columns
total_revenue = sum of all revenue columns
dependency = (state_aid / total_revenue * 100).round(2)
```

## Phase 5: Outcomes Data Import (NYSED)

### Data sources

1. **Assessment Results** (https://data.nysed.gov/downloads.php)
   - ELA and Math proficiency (Grades 3-8)
   - Regents exam pass rates
   - Format: Excel files by year

2. **Graduation Rates**
   - 4-year, 5-year, 6-year cohort rates
   - By subgroup (all students, economically disadvantaged, etc.)

3. **Enrollment & Demographics**
   - Total enrollment (cross-check with OSC)
   - Free/reduced lunch % (poverty proxy)
   - English Language Learners %
   - Students with Disabilities %

### Key outcome metrics to import

| Metric | Source | Notes |
|--------|--------|-------|
| ELA Proficiency % | NYSED | Grades 3-8, Level 3+4 |
| Math Proficiency % | NYSED | Grades 3-8, Level 3+4 |
| 4-Year Graduation Rate | NYSED | Cohort-based |
| Regents Diploma % | NYSED | Of graduates |
| Advanced Regents % | NYSED | Of graduates |
| Economically Disadvantaged % | NYSED | Poverty proxy |

### Matching NYSED to OSC districts

NYSED uses BEDS codes (12-digit), OSC uses Municipal codes (12-digit).
Need to create a mapping file or match on district name.

```ruby
# NYSED BEDS code format: CCDDDDSSSSSS
# CC = county, DDDD = district, SSSSSS = school (000000 for district-level)

# OSC Muni code format: CCDDDDSSSSS0
# Similar structure but different encoding

# Best approach: match on normalized district name
def normalize_district_name(name)
  name.downcase
      .gsub(/\s*(central|city|union free|common)?\s*school district\s*/i, "")
      .gsub(/[^a-z0-9]/, "")
end
```

## Phase 6: Analysis Views

### Economies of scale analysis

```ruby
# Group districts by enrollment bands
BANDS = [
  { label: "< 500", range: 0..499 },
  { label: "500-1,000", range: 500..999 },
  { label: "1,000-2,500", range: 1000..2499 },
  { label: "2,500-5,000", range: 2500..4999 },
  { label: "5,000-10,000", range: 5000..9999 },
  { label: "> 10,000", range: 10000.. },
]

# Calculate avg per-pupil spending by band
# Hypothesis: larger districts have lower per-pupil costs (economies of scale)
# But may plateau or reverse at very large sizes
```

### Spending vs outcomes scatter plots

```ruby
# X-axis: Per-pupil spending
# Y-axis: ELA/Math proficiency or graduation rate
# Color: District type or region
# Size: Enrollment

# Key question: Does more spending = better outcomes?
# Control for: poverty rate, district wealth, region
```

### Dashboard metrics for school districts

| Metric | Description | Comparable to Cities? |
|--------|-------------|----------------------|
| Per-Pupil Spending | Total expenditures / enrollment | No (different service) |
| Instruction % | Instruction / total expenditures | No |
| Admin Overhead % | Admin / total expenditures | Conceptually yes |
| State Aid Dependency | State aid / total revenue | Yes |
| Debt Per Pupil | Outstanding debt / enrollment | Conceptually yes |
| Property Tax Per Pupil | Property tax / enrollment | No |
| ELA Proficiency | % students Level 3+4 | No |
| Graduation Rate | 4-year cohort rate | No |

## Implementation Order

1. **Create entities** - `osc:schools:create_entities` ✅ COMPLETE (2026-02-05)
   - 689 school districts created
   - Distribution: 546 central, 72 union free, 57 small city, 10 common, 4 big five
   - 61 city school districts linked to parent cities
2. **Create metrics** - `osc:schools:create_metrics` ✅ COMPLETE (2026-02-05)
   - 171 metrics created from CSV column headers
   - Distribution: 83 revenue, 85 expenditure, 2 balance sheet, 1 enrollment
   - Categories assigned: Education, Employee Benefits, Debt Service, State/Federal Aid, etc.
3. **Import financial data** - `osc:schools:import` ✅ COMPLETE (2026-02-05)
   - 272,580 observations imported (2015-2024, 10 years)
   - 6,885 documents created (689 districts × 10 years, minus non-filers)
   - Years 2012-2014 skipped (no header rows in CSV)
   - Column normalization handles name differences between years
   - 3 merged districts skipped (Berkshire, Elizabethtown-Lewis, Westport)
4. **Calculate derived metrics** - `osc:schools:derive_metrics`
5. **Download NYSED outcomes** - Manual or scripted
6. **Import outcomes** - `nysed:import_outcomes`
7. **Build school district dashboard** - New view similar to entity show
8. **Build comparison/ranking views** - Per-pupil leaderboards, scatter plots

## File Structure

```
db/seeds/osc_school_district_data/
├── README.md
├── IMPORT_PLAN.md (this file)
├── leveltwo12.csv ... leveltwo24.csv (OSC financial)
├── leveltwo12.xlsx ... leveltwo24.xlsx (originals)
├── entity_mapping.yml (district name → entity, BEDS → muni code)
└── .gitignore

db/seeds/nysed_data/
├── README.md
├── assessment_results/ (ELA, Math by year)
├── graduation_rates/ (cohort data by year)
└── enrollment/ (demographics by year)
```

## Resolved Questions

### 1. Big Five handling — No double-counting risk

**Decision:** Import both city and school district data. OSC maintains them as completely separate datasets.

**Verification (FY 2024):** Compared expenditures for all four Big Five cities in OSC:

| City | Municipal Code | Municipal Ops | SD Code | School District | SD % of Total |
|------|----------------|---------------|---------|-----------------|---------------|
| Buffalo | 140207000000 | $896M | 140507000000 | $1.28B | 58.8% |
| Rochester | 260248000000 | $908M | 260548000000 | $1.08B | 54.3% |
| Syracuse | 310255000000 | $507M | 310555000000 | $624M | 55.2% |
| Yonkers | 550262000000 | $925M | 550562000000 | $830M | 47.3% |

The municipal code pattern differs at positions 3-4: `02` for cities, `05` for school districts. Expenditure figures are completely separate — for 3 of 4 Big Five cities, school spending exceeds municipal operations.

Set `parent_id` on Big Five school districts to link them to their parent city for fiscal dependency relationship.

### 2. BOCES — Exclude

**Decision:** Do not import BOCES (Boards of Cooperative Educational Services).

**Rationale:** BOCES are regional shared-service providers, not student-serving districts. They have no enrollment for per-pupil calculations and no outcome metrics to benchmark. Districts using BOCES services report that spending as an expenditure line item in their own filings.

### 3. Charter schools — Exclude

**Decision:** Do not import charter schools.

**Rationale:** Charter schools are not in OSC's school district bulk data — they operate under different financial reporting requirements. NYSED tracks them separately. Could be added as a future entity type if there's demand.

### 4. Historical district mergers — Don't track lineage (for now)

**Decision:** Each filing year stands alone. Do not track historical lineage in Phase 1.

**Rationale:** When districts merge, the old district stops appearing in new years and the successor district starts appearing. This works fine for year-over-year analysis within a district.

**Known merged districts (skipped in import):**
- Berkshire Union Free School District (100911800800)
- Elizabethtown-Lewis Central School District (150726000100)
- Westport Central School District (150789600100)

**Future Enhancement: Merger Tracking**

Tracking mergers would enable "economies of scale" analysis:
- Did per-pupil spending decrease after merger?
- Did outcomes improve for students from the smaller district?
- What's the optimal district size for cost efficiency?

**Proposed schema:**
```ruby
# Add to entities table
add_column :status, :string, default: 'active'  # active, merged, closed
add_column :successor_id, :bigint               # points to merged-into entity
add_column :merger_year, :integer               # when merger happened
add_index :entities, :successor_id
```

**Workflow:**
1. Research actual merger history (NYSED maintains this)
2. Create entities for merged districts with `status: 'merged'`
3. Set `successor_id` to point to the new combined district
4. Import pre-merger data to the original entities
5. Analysis can then compare pre-merger (A+B combined) vs post-merger (C)

**Challenges:**
- Manual research required to identify all mergers
- Need to sum A+B metrics for apples-to-apples comparison with C
- Demographic composition may change (not just A+B population)
- Some mergers are consolidations (new name), others are absorptions (one name survives)

**Priority:** Low. Most districts are stable. Focus on current benchmarking first.

### 5. Metric naming — No prefix

**Decision:** Do not prefix school metrics with "School:". Use `entity.kind` to filter when needed.

**Rationale:** City and school metrics are already distinguishable by name:
- City: Police, Fire, Highways, Water, Sewer (municipal operations)
- School: Instruction, Pupil Services, Instructional Support (education operations)

The few overlapping concepts (Debt Service, Employee Benefits) have different account codes and represent the same financial concept — this is actually useful for cross-entity-type queries like "total debt service burden across all local governments."
