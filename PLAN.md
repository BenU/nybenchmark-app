# OSC Data Import Plan

## Overview

Import bulk financial data from the NYS Office of the State Comptroller (OSC) into the nybenchmark app, starting with a clean slate for metrics and observations while preserving entities and documents.

**Data Sources:**
- **Primary:** https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm (all 62 cities, 1995-2024)
- **NYC 2011+:** https://checkbooknyc.com/ (separate data source due to OSC gap)

**Historical Range:** As far back as available (1995-2024 for most cities)

---

## Phase 0: Data Reset

### 0.1 What We Keep
- **Users** - Current user accounts
- **Entities** - All 62 cities with governance data (ICMA council-manager designations, etc.)
- **Documents** - Keep existing 6 documents (can coexist with new OSC documents)

### 0.2 What We Delete
- **Observations** - All (contains errors from CSV import issues)
- **Metrics** - All (will rebuild around OSC account codes + census/crime data)

### 0.3 Reset Rake Task

```ruby
# lib/tasks/data_reset.rake
namespace :data do
  desc "Reset observations and metrics only (DESTRUCTIVE - keeps entities, documents, and users)"
  task reset_for_osc: :environment do
    puts "WARNING: This will delete ALL observations and metrics!"
    puts "Entities, documents, and users will be preserved."
    puts "Press Ctrl+C within 5 seconds to cancel..."
    sleep 5

    ActiveRecord::Base.transaction do
      puts "Deleting observations..."
      Observation.delete_all
      puts "Observations deleted: #{Observation.count} remaining"

      puts "Deleting metrics..."
      Metric.delete_all
      puts "Metrics deleted: #{Metric.count} remaining"

      puts "Done. Database reset for OSC import."
      puts "Entities remaining: #{Entity.count}"
      puts "Documents remaining: #{Document.count}"
      puts "Users remaining: #{User.count}"
    end
  end
end
```

---

## Phase 1: Schema Modifications

### 1.1 Add `bulk_data` source type to Document

```ruby
# app/models/document.rb
enum :source_type, { pdf: 0, web: 1, bulk_data: 2 }, default: :pdf
```

**Behavior for bulk_data:**
- Does not require `page_reference` on observations
- Does not have file attachments
- `source_url` points to data source download page
- Allows bulk import without manual verification

### 1.2 Add `data_source` enum to Metric

```ruby
# app/models/metric.rb
enum :data_source, {
  manual: 0,          # Manually entered
  osc: 1,             # NYS Comptroller AFR data (non-NYC, and NYC pre-2011)
  census: 2,          # US Census Bureau (population, income, poverty)
  dcjs: 3,            # NYS Division of Criminal Justice Services (crime stats)
  rating_agency: 4,   # Moody's, S&P, Fitch (bond ratings)
  derived: 5,         # Calculated from other metrics (per capita, ratios)
  nyc_checkbook: 6    # NYC Checkbook data (NYC 2011+)
}, default: :manual
```

**Rationale for separate `nyc_checkbook`:**
- Different data structure than OSC
- Different URL/provenance
- NYC is uniquely large and has its own transparency portal
- Keeps OSC data "pure" for the other 61 cities

### 1.3 Add Account Code Fields to Metric

```ruby
# Migration: add_osc_fields_to_metrics
add_column :metrics, :data_source, :integer, default: 0, null: false
add_column :metrics, :account_code, :string      # Full code: "A3120.1"
add_column :metrics, :fund_code, :string         # "A" (General Fund)
add_column :metrics, :function_code, :string     # "3120" (Police)
add_column :metrics, :object_code, :string       # "1" (Personal Services)

add_index :metrics, :data_source
add_index :metrics, :account_code
add_index :metrics, :fund_code
```

**Account Code Structure (Uniform System of Accounts):**
```
A3120.1
│ │     │
│ │     └── Object Code: .1 = Personal Services, .2 = Equipment, .4 = Contractual, .8 = Benefits
│ │
│ └──────── Function Code: 3120 = Police, 3410 = Fire, 8160 = Sanitation, 9015 = PFRS Pension
│
└────────── Fund Code: A = General, F = Water, G = Sewer, V = Debt Service
```

---

## Phase 2: Priority Account Codes (The "Rosetta Stone")

### 2.1 Revenue Codes - Local Sources

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A1001 | Real Property Taxes | Primary citizen "pain point" |
| A1110 | Sales and Use Tax | Economic activity measure |
| A1120 | Utility Gross Receipts Tax | Local business tax |
| A2401 | Interest and Earnings | Investment income |

### 2.2 Revenue Codes - State Aid

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A3001 | State Aid - Revenue Sharing | AIM payments from Albany |
| A3005 | State Aid - Mortgage Tax | Housing market indicator |
| A3040 | State Aid - Public Safety | Targeted safety grants |
| A3089 | State Aid - Other | Miscellaneous state grants |

### 2.3 Revenue Codes - Federal Aid (Important!)

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A4089 | Federal Aid - Other | General federal grants |
| A4389 | Federal Aid - Public Safety | COPS grants, Homeland Security |
| A4910 | Federal Aid - Housing/Community Dev | HUD, CDBG funds |
| A4960 | Federal Aid - Emergency Management | FEMA, disaster relief |

**Note:** Federal aid is significant, especially post-COVID (ARPA funds). Cities with higher poverty rates often receive more federal community development aid. This measures federal dependency alongside state dependency.

### 2.4 Expenditure Codes - Public Safety (Critical)

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A3120.1 | Police - Personal Services | Baumol labor cost |
| A3120.2 | Police - Equipment | Capital intensity |
| A3120.4 | Police - Contractual | Operational overhead |
| A3410.1 | Fire - Personal Services | Comparative benchmark |
| A3410.4 | Fire - Contractual | Equipment/supplies |

### 2.5 Expenditure Codes - Sanitation (Efficiency Benchmark!)

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A8160.1 | Refuse & Garbage - Personal Services | **Labor cost (your Yonkers vs Watertown example!)** |
| A8160.2 | Refuse & Garbage - Equipment | Trucks, bins, automation level |
| A8160.4 | Refuse & Garbage - Contractual | Contracted vs in-house collection |

**Strategic Note:** Sanitation is a perfect efficiency benchmark because:
- Service output is measurable (tons collected, households served)
- Labor intensity varies dramatically (manual vs automated collection)
- Easy to understand ("2 guys + driver" vs "1 guy with robotic arm")
- Union contract impacts are visible (Teamsters negotiations)

### 2.6 Expenditure Codes - Undistributed Benefits (Hidden Costs)

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A9015.8 | Police & Fire Retirement (PFRS) | CRITICAL - uniformed pension load |
| A9010.8 | State Retirement (ERS) | Non-uniformed pensions |
| A9030.8 | Social Security | Federal mandate |
| A9040.8 | Workers Compensation | Risk/injury costs |
| A9060.8 | Health Insurance | Fastest-growing cost |

### 2.7 Expenditure Codes - Infrastructure & Debt

| Code | Label | Strategic Value |
|------|-------|-----------------|
| A5110.1 | Street Maintenance | Infrastructure capacity |
| A5142.4 | Snow Removal | Variable cost (upstate) |
| A7110.1 | Parks | Quality of life |
| A9710.6 | Serial Bonds - Principal | Debt burden |
| A9710.7 | Serial Bonds - Interest | Debt cost |

---

## Phase 3: Per Capita & Derived Metrics

### 3.1 Why Per Capita Matters

Raw spending numbers are misleading:
- NYC spends $6B on police; Sherrill spends $500K
- But NYC has 8M people; Sherrill has 3,000
- Per capita comparison reveals efficiency

### 3.2 Derived Metric Examples

| Derived Metric | Formula | Strategic Value |
|----------------|---------|-----------------|
| police_cost_per_capita | (A3120.* + A9015.8) / population | True cost of policing |
| sanitation_cost_per_capita | A8160.* / population | Garbage collection efficiency |
| fire_cost_per_capita | (A3410.* + A9015.8 allocated) / population | Fire service cost |
| state_aid_per_capita | A3xxx / population | Dependency on Albany |
| federal_aid_per_capita | A4xxx / population | Federal dependency |
| property_tax_per_capita | A1001 / population | Local tax burden |
| debt_service_per_capita | A9710.* / population | Legacy cost burden |

### 3.3 Implementation Approach

```ruby
# Derived metrics stored in metrics table with:
#   data_source: :derived
#   formula: "A3120.* + A9015.8 / population"
#
# Calculation happens at query time or via background job
# Requires population observation for same entity/year
```

### 3.4 Population Data Requirement

Per capita metrics require population data. Sources:
- **Census 2020:** Decennial count (most accurate)
- **ACS estimates:** Annual estimates (2021-2024)
- **data_source: :census** for these metrics

---

## Phase 4: Manual CSV Download Process

### 4.1 Download Steps

1. Go to: https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm
2. Select export type: **"Revenue, Expenditure and Balance Sheet Data"**
3. Select detail: **"Single Class of Government for All Years"**
4. Select class: **"City"**
5. Click Download (ZIP file)

### 4.2 File Organization

```
db/seeds/osc_data/
├── README.md                    # Download date, source URL, notes
├── city_all_years.zip           # Original download (archive)
├── city_expenditure.csv         # Extracted
├── city_revenue.csv             # Extracted
└── city_balance_sheet.csv       # Extracted
```

### 4.3 NYC Data (Post-2010)

OSC data for NYC only available through 2010. For 2011+:
- Source: https://checkbooknyc.com/
- Download budget/spending data
- Uses `data_source: :nyc_checkbook` on metrics
- Different document (doc_type: "nyc_checkbook")

---

## Phase 5: Extensibility for Other Government Types

### 5.1 Current Entity Kinds

```ruby
enum :kind, {
  city: "city",
  town: "town",
  village: "village",
  county: "county",
  school_district: "school_district"
}
```

### 5.2 Future-Proofing

The OSC download interface supports:
- City ✓ (Phase 1)
- Town (future)
- Village (future)
- County (future)
- Fire District (future - would need new kind)
- School District ✓ (already in enum)

### 5.3 Rake Task Parameterization

```ruby
# Design allows for future expansion:
namespace :osc do
  desc "Import OSC data for a specific government class"
  task :import, [:file_path, :data_type, :gov_class] => :environment do |t, args|
    # gov_class: city, town, village, county, school_district, fire_district
    OscImporter.new(
      file_path: args[:file_path],
      data_type: args[:data_type],
      gov_class: args[:gov_class] || 'city'
    ).import
  end
end

# Future usage:
# rails osc:import[db/seeds/osc_data/town_expenditure.csv,expenditure,town]
# rails osc:import[db/seeds/osc_data/village_expenditure.csv,expenditure,village]
```

### 5.4 Authority Support (Deferred)

Authorities have different data structure (Socrata API available). If added later:
- New entity kind: `authority`
- Different import process (API vs CSV)
- Different account code structure

---

## Phase 6: Census & Crime Data (Manual Re-entry)

After OSC import is working, manually add back:

### 6.1 Census Metrics (data_source: :census)
- population_2020 (Decennial Census)
- population_2024_estimate (ACS)
- median_household_income
- poverty_rate

### 6.2 DCJS Metrics (data_source: :dcjs)
- violent_crime_rate
- property_crime_rate

### 6.3 Rating Agency Metrics (data_source: :rating_agency)
- bond_credit_rating_moodys
- bond_credit_rating_sp

These will be entered via the app UI or a separate seed file, linked to `web` source documents pointing to Census/DCJS websites.

---

## Implementation Order

### Week 1: Schema & Reset
1. [ ] Create migration: add OSC fields to metrics
2. [ ] Create migration: add bulk_data to document source_type
3. [ ] Update Document model validations
4. [ ] Update Observation model validations
5. [ ] Create data:reset_for_osc rake task
6. [ ] **RUN RESET** (after backup confirmation)

### Week 2: Download & Explore
7. [ ] Manually download OSC CSV files
8. [ ] Analyze CSV structure (columns, format, quirks)
9. [ ] Create entity name mapping
10. [ ] Document any data quality issues

### Week 3: Import Task
11. [ ] Build OscImporter service class
12. [ ] Build osc:import rake task
13. [ ] Test import with one year of Big Five cities
14. [ ] Verify data integrity
15. [ ] Full import (all years, all cities)

### Week 4: Verification & Census Data
16. [ ] Spot-check imported data against OSC website
17. [ ] Add census metrics (population, income, poverty)
18. [ ] Add DCJS crime metrics
19. [ ] Build comparison views

### Week 5: Per Capita Metrics
20. [ ] Implement derived metric calculation
21. [ ] Add per capita metrics (police, sanitation, fire, etc.)
22. [ ] Build per capita comparison dashboard

---

## Success Criteria

- [ ] Database reset completed (0 observations, 0 metrics, 62 entities, 6 documents preserved)
- [ ] OSC data imported for all 62 cities (61 from OSC, NYC from Checkbook post-2010)
- [ ] Historical depth: 1995-2024 where available
- [ ] Can query: "Police spending for Yonkers, 2015-2023"
- [ ] Can compare: "A3120.1 across Big Five cities"
- [ ] **Per capita comparisons work** (police cost per capita, sanitation per capita, etc.)
- [ ] **Sanitation metrics included** (A8160.* for labor efficiency analysis)
- [ ] **Federal aid tracked** alongside state aid (A4xxx codes)
- [ ] Every observation traces to source document (OSC or NYC Checkbook)
- [ ] Census/crime data re-added for key metrics
- [ ] **Design supports future expansion** to towns, villages, counties, school districts

---

## Risk Mitigation

### Backup Before Reset
```bash
# Create backup before destructive operations
kamal app exec -- bin/rails db:dump > backup_$(date +%Y%m%d).sql
```

### Incremental Import
Import in stages:
1. First: Big Five cities only (Buffalo, Rochester, Syracuse, Yonkers, Albany)
2. Then: Recent years (2019-2024)
3. Finally: Historical data (1995-2018)
4. Last: NYC from Checkbook (2011-2024)

### Data Validation
After each import stage, verify:
- Row counts match expectations
- No orphaned records
- Amounts are reasonable (no obvious data errors)
- Per capita calculations produce sensible results
