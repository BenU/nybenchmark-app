# OSC Data Quality Analysis

**Analysis Date:** 2026-01-26
**Data Source:** NYS Comptroller Financial Data for Local Governments
**Coverage:** 1995-2024 (30 years)

## Executive Summary

Of New York's 62 cities:
- **57 cities** (92%) have complete or near-complete OSC filings
- **4 cities** (6%) are significantly behind on filings (2+ years)
- **1 city** (2%) never in OSC system (NYC has separate Comptroller)

**Key Finding:** The OSC reports that ~20% of local governments fail to file on time, affecting over 482,000 New Yorkers. Mount Vernon lost its credit rating due to non-filing.

---

## Filing Status Categories

### Complete Filers (57 cities)

Cities with data through 2023 or 2024. These have continuous filing histories from 1995.

All 57 cities listed in `entity_mapping.yml` are complete filers.

### Severely Late Filers (4 cities)

These cities have stopped filing OSC data and represent a **data quality concern**:

| City | Last Filed | Years Missing | Gap |
|------|------------|---------------|-----|
| **Mount Vernon** | 2020 | 2021-2024 | 4 years |
| **Ithaca** | 2021 | 2022-2024 | 3 years |
| **Rensselaer** | 2021 | 2022-2024 | 3 years |
| **Fulton** | 2022 | 2023-2024 | 2 years |

**Mount Vernon** is the most concerning - a city of 70,000+ people with no financial transparency data for 4 years. This may indicate fiscal stress or governance issues.

### Never in OSC System (1 city)

| City | Reason | Alternative Source |
|------|--------|-------------------|
| **New York City** | Has own elected Comptroller | [NYC Checkbook](https://checkbooknyc.com/) |

**Important Correction:** NYC was **never** in the OSC Annual Financial Report system - it's explicitly excluded. The OSC AFR Filing Status page states: "New York City is not included in this data."

NYC has its own independently elected Comptroller (currently Brad Lander) who operates Checkbook NYC. The State Comptroller monitors NYC through a special office (OSDC - Office of the State Deputy Comptroller for NYC) but doesn't collect their AFR data.

All NYC financial data must come from [Checkbook NYC](https://checkbooknyc.com/) (launched July 2010).

### Recently Late (7 cities)

Cities missing from 2024 but present in 2023. These are likely **fiscal year timing issues**, not filing failures:

- Jamestown
- Johnstown
- Mechanicville
- North Tonawanda
- Port Jervis
- Salamanca
- Tonawanda

These cities typically file on July-June fiscal years, so their 2024 data may arrive later.

---

## Year-by-Year Filing Trends

| Year | Cities Filed | Notes |
|------|--------------|-------|
| 2018 | 61 | Full compliance (excluding NYC) |
| 2019 | 61 | Full compliance |
| 2020 | 61 | Full compliance |
| 2021 | 60 | Mount Vernon stops filing |
| 2022 | 58 | Ithaca, Rensselaer stop filing |
| 2023 | 57 | Fulton stops filing |
| 2024 | 50 | 7 additional cities pending (likely timing) |

**Trend:** Filing compliance declining since 2020. This warrants monitoring.

---

---

## OSC Audits and Public Reporting

### Mount Vernon: A Case Study in Non-Filing Consequences

The OSC has conducted multiple audits documenting Mount Vernon's failures:

- **[2020 Audit (2020M-96)](https://www.osc.ny.gov/local-government/audits/city/2020/09/17/city-mount-vernon-financial-reporting-and-oversight-2020m-96):** City Comptroller failed to file AFR for fiscal years 2016-2019. The city **lost its credit rating** as a direct result.

- **[2022 Audit](https://www.osc.ny.gov/press/releases/2022/01/audit-finds-operational-and-oversight-failures-led-financial-instability-mount-vernon):** "Operational and Oversight Failures Led to Financial Instability"

Key quote from Comptroller DiNapoli: "The lack of operational controls and failure by the former city comptroller to complete basic financial functions contributed to Mount Vernon's fiscal crisis."

### Statewide Non-Filing Problem

From the [2025 Fiscal Stress Scores release](https://www.osc.ny.gov/press/releases/2025/04/dinapoli-releases-2024-fiscal-stress-scores-villages-and-some-cities):

> "108 local governments did not file their data in time... approximately **20% of local governments evaluated**... Over **482,000 New Yorkers** reside in these municipalities."

The OSC maintains an [AFR Filing Status dashboard](https://www.osc.ny.gov/local-government/required-reporting/annual-financial-report-afr-filing-status) to track non-filers.

**Note:** School districts have near-perfect compliance (0 persistent non-filers as of August 2024). Cities face less accountability.

### Blog Post Opportunity

This data gap is a story worth telling on nybenchmark.org:
- Visualize filing compliance trends (dropping from ~100% to ~80%)
- Name chronic non-filers and their consequences
- Compare city accountability to school district accountability
- Link to OSC audits and dashboards

---

## Recommended Database Changes

### DECISION NEEDED: Filing Status Schema

We need to track which years each entity has/hasn't filed. The simple approach (`osc_last_filed_year` on Entity) doesn't capture sporadic filing patterns (e.g., Mount Vernon filed 1995-2015, skipped 2016-2019, filed 2020, then stopped again).

**Options under consideration:**

#### Option A: Separate Table for Every Year
```ruby
create_table :entity_filing_records do |t|
  t.references :entity, null: false, foreign_key: true
  t.integer :fiscal_year, null: false
  t.string :status, null: false  # filed, missing, late, pending
  t.date :filed_on               # Actual filing date if known
  t.text :notes                  # "Lost credit rating per OSC audit"
  t.timestamps
end
```
- Pros: Complete history, explicit, easy queries
- Cons: Many records (~1,860 for cities alone)

#### Option B: Track Only Gaps/Problems
```ruby
create_table :entity_filing_gaps do |t|
  t.references :entity, null: false, foreign_key: true
  t.integer :fiscal_year, null: false
  t.string :reason              # missing, late, incomplete
  t.text :notes
  t.timestamps
end
```
- Pros: Fewer records, focuses on problems
- Cons: Absence of record is ambiguous

#### Option C: Derive from Observations
Don't store filing status - calculate from which years have OSC observations.
- Pros: No duplicate data
- Cons: Can't store notes about *why* they didn't file

**Questions to resolve:**
1. Do we need records for "good" years, or just gaps?
2. Auto-populate during import, manual notes, or both?
3. Could a city file partial data (revenue but not expenditure)?

### Entity Fields (simpler, still useful)

Even if we add a filing records table, these Entity fields are useful:

```ruby
add_column :entities, :osc_municipal_code, :string  # 12-digit OSC code for matching
```

---

## Import Handling

### For Late Filers

The import task should:
1. Import all available historical data (1995 through last filed year)
2. Log a warning when processing late filers
3. Update `osc_last_filed_year` automatically during import

### For NYC

NYC requires separate import from Checkbook NYC:
1. Different data structure
2. Different `data_source` enum value (`:nyc_checkbook`)
3. Separate rake task: `osc:import_nyc_checkbook`

---

## Data Integrity Notes

### No Mid-Year Gaps

All cities have **continuous** filing histories from their first year through their last year. No cities skipped years and then resumed.

### Amounts May Have Decimals

Some cities report amounts with cents (e.g., `3619538.81`), others as integers. Import should handle both.

### Fiscal Year Variations

- Most cities: Calendar year (Jan-Dec)
- Some cities: Fiscal year (July-June)
- The `PERIOD_START` and `PERIOD_END` columns indicate the actual period

---

## Action Items

### Decisions Needed
- [ ] **Decide on filing status schema** (Option A, B, or C above)

### Schema Changes
- [ ] Add `osc_municipal_code` to Entity model
- [ ] Create filing status table/fields (pending decision above)

### Import Tasks
- [ ] Build OscImporter service class
- [ ] Auto-detect and log filing gaps during import
- [ ] Create separate NYC Checkbook import task

### UI/UX
- [ ] Add warning indicator for late filers on entity pages
- [ ] Consider: Public dashboard showing filing compliance trends

### Content
- [ ] Write blog post about non-filing cities for nybenchmark.org
