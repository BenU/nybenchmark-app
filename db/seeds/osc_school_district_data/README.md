# OSC School District Financial Data

Downloaded from NYS Comptroller bulk data portal:
https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm

## Files

| File | Year | Districts | Columns |
|------|------|-----------|---------|
| leveltwo12.csv | 2012 | 693 | 180 |
| leveltwo13.csv | 2013 | 693 | 180 |
| leveltwo14.csv | 2014 | 691 | 180 |
| leveltwo15.csv | 2015 | 693 | 179 |
| leveltwo16.csv | 2016 | 693 | 179 |
| leveltwo17.csv | 2017 | 693 | 179 |
| leveltwo18.csv | 2018 | 693 | 180 |
| leveltwo19.csv | 2019 | 693 | 181 |
| leveltwo20.csv | 2020 | 692 | 181 |
| leveltwo21.csv | 2021 | 691 | 181 |
| leveltwo22.csv | 2022 | 691 | 181 |
| leveltwo23.csv | 2023 | 691 | 181 |
| leveltwo24.csv | 2024 | 691 | 181 |

Original XLSX files retained for reference.

## Data Structure

### Metadata Columns (1-9)
- `Muni Code` - OSC municipal code (12-digit)
- `Entity Name` - School district name
- `County` - County name
- `Class Description` - District type (see below)
- `Fiscal Year End Date` - Usually 06/30/YYYY
- `Months in Fiscal Period` - Usually 12
- `Enrollment` - Student count
- `Full Value` - Property value
- `Debt Outstanding` - Total debt

### Revenue Columns (10-93)
- Real Property Taxes and Assessments
- State Aid (broken down by purpose)
- Federal Aid (broken down by purpose)
- Charges for Services
- Other Local Revenues

### Expenditure Columns (94-179)
- Instruction
- Instructional Support
- Pupil Services
- Transportation
- Employee Benefits
- Debt Service
- Administration

### Total Columns (179-181)
- Total Expenditures
- Total Expenditures and Other Uses

## District Types (Class Description)

Maps to `school_legal_type` enum in Entity model:

| OSC Class | Count | Entity school_legal_type |
|-----------|-------|--------------------------|
| Central | 267 | `central` |
| Independent Superintendent | 276 | `central` (same legal structure) |
| Union Free | 72 | `union_free` |
| City Public School | 61 | `big_five` or `small_city` |
| Common | 10 | `common` |
| Central High | 3 | `central` |

### City Public School Districts (Fiscally Dependent)

The 61 "City Public School" districts correspond to NY cities:
- **Big Five** (4 in OSC): Buffalo, Rochester, Syracuse, Yonkers
  - NYC not in OSC (has own Comptroller)
  - Their budgets are part of city budgets
- **Small City** (57): Albany, Amsterdam, Auburn, etc.
  - Also fiscally dependent on their cities

These should have `parent_id` pointing to their city entity.

## Import Notes

- Format is similar to city data but columns differ
- Need to map column names to metrics
- Big Five districts may have duplicated data with city filings
- Consider whether to import school-specific metrics separately or merge
