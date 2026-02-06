# Methodology Page Update: School Districts

This draft extends the methodology page to cover school district data. The approach: restructure into entity-type sections to avoid conflicts with existing city content.

## Proposed Page Structure

```
Methodology
├── Cities
│   ├── Data Sources (OSC AFRs, Census ACS)
│   ├── Headline Metrics (Fund Balance %, Debt Service %, Per-Capita)
│   ├── All-Fund Approach
│   └── Known Limitations
├── School Districts [NEW]
│   ├── Data Sources (OSC bulk data, NYSED outcomes)
│   ├── Headline Metrics (Per-Pupil Spending, Admin %, State Aid %)
│   ├── District Types
│   └── Known Limitations
└── Open Source
```

---

## Draft Content for School Districts Section

### Data Sources

#### NYS Comptroller (OSC) — School District Financials

The [NYS Office of the State Comptroller](https://wwe1.osc.state.ny.us/localgov/findata/financial-data-for-local-governments.cfm) publishes annual financial data for all ~691 school districts in New York State. NY Benchmark imports this data from 2012 to present, totaling approximately 900,000 observations.

Unlike city data (which uses a long/normalized format with one row per account code), school district data is published in a wide format with one row per district per year and ~180 columns representing pre-aggregated category totals.

**Categories included:**
- Revenue by source (property taxes, state aid, federal aid, charges for services)
- Expenditures by function (instruction, administration, transportation, debt service)
- Balance sheet items (debt outstanding, fund balances)
- Enrollment and property values

#### NYSED — Educational Outcomes

The [New York State Education Department](https://data.nysed.gov/downloads.php) publishes assessment results, graduation rates, and enrollment demographics for all districts.

| Data Type | Years Available | Key Metrics |
|-----------|-----------------|-------------|
| Graduation Rates | 2006–present | 4/5/6-year cohort rates, Regents diploma %, dropout rate |
| Assessment Results | 2014–2021 | ELA and Math proficiency (Grades 3-8), Regents pass rates |
| Enrollment & Demographics | 2006–present | Total enrollment, % economically disadvantaged, % ELL, % SWD |

**Note:** 2019-20 assessment data was not collected due to COVID-19 school closures.

### How Metrics Are Calculated

The headline metrics for school district comparisons are:

**Per-Pupil Spending**
: Total Expenditures divided by Enrollment. The primary measure for comparing spending across districts of different sizes. NY State averages ~$33,000 per pupil, highest in the nation.

**Administrative Overhead %**
: Administration expenditures divided by Total Expenditures. Measures how much of the budget goes to administration vs. instruction. Lower is generally considered more efficient.

**State Aid Dependency %**
: Total State Aid divided by Total Revenue. Measures fiscal independence. Higher dependency indicates greater reliance on state funding (and vulnerability to state budget cuts).

**Instruction %**
: Instruction expenditures divided by Total Expenditures. The share of spending that directly supports classroom teaching.

**Outcomes metrics** (from NYSED):

**Graduation Rate**
: Percentage of a cohort that graduates within 4 years (or 5/6 years for extended measures). Based on cohort tracking, not year-over-year enrollment.

**Proficiency Rate**
: Percentage of students scoring at Level 3 or 4 (proficient or advanced) on state ELA and Math assessments in Grades 3-8.

### District Types

New York has five legal classifications for school districts:

| Type | Count | Description |
|------|-------|-------------|
| Central | ~543 | Consolidated districts serving multiple municipalities. Includes "Independent Superintendent" and "Central High" variants. |
| Union Free | 72 | Districts formed by vote of multiple school districts, typically in suburbs. |
| City | 61 | Districts coterminous with a city. The Big Five (Buffalo, Rochester, Syracuse, Yonkers, NYC) are "dependent" — their budgets require city approval. The 56 other city districts are independent. |
| Common | 10 | Historic one-room-schoolhouse districts, mostly in rural areas. Few remain. |

**Note on the Big Five:** Buffalo, Rochester, Syracuse, and Yonkers school districts are fiscally dependent on their parent cities. NYC Department of Education is the fifth but is not in OSC data (NYC has its own Comptroller). We import Big Five districts from OSC's school district files and link them to their parent city via `parent_id`.

**Verified: No double-counting.** OSC uses different municipal codes for cities vs school districts (e.g., Buffalo city = `140207000000`, Buffalo City SD = `140507000000`). FY 2024 comparison shows completely separate expenditure figures:

| City | Municipal Ops | School District | SD % of Total |
|------|---------------|-----------------|---------------|
| Buffalo | $896M | $1.28B | 58.8% |
| Rochester | $908M | $1.08B | 54.3% |
| Syracuse | $507M | $624M | 55.2% |
| Yonkers | $925M | $830M | 47.3% |

For three of four Big Five cities, school district spending exceeds municipal operations.

### Exclusions

**BOCES (Boards of Cooperative Educational Services):** Regional shared-service providers are excluded. They don't serve students directly and have no enrollment for per-pupil calculations. Districts using BOCES services report that spending as an expenditure.

**Charter Schools:** Not included in OSC's school district bulk data. NYSED tracks charter schools separately, but they operate under different financial reporting requirements.

### Known Limitations

- **Assessment gaps:** State testing was cancelled in 2019-20 (COVID). Assessment data availability varies by year.
- **District mergers:** Some districts have consolidated over time. We don't track historical lineage — each year's filing stands alone.
- **Enrollment timing:** OSC enrollment figures are point-in-time snapshots that may differ slightly from NYSED's audited enrollment counts.
- **NYC schools:** NYC Department of Education is not in OSC data. NYC school data will be imported separately from NYC Open Data in a future release.
- **Pre-2012 data:** OSC's school district bulk downloads only go back to 2012, unlike city data which goes back to 1995.

---

## Implementation Notes

Each import phase should trigger a methodology update:

| Phase | Methodology Update |
|-------|-------------------|
| Phase 1: Entity creation | Add "District Types" section, confirm Big Five handling |
| Phase 2: Metric creation | Add "How Metrics Are Calculated" section |
| Phase 3: Financial import | Add OSC data source section, confirm observation counts |
| Phase 4: Derived metrics | Add per-pupil and ratio metric definitions |
| Phase 5: NYSED outcomes | Add NYSED data source section, add outcomes metrics |
| Phase 6: Analysis views | Update with actual dashboards/comparisons available |

## Resolved Questions

1. **Big Five double-counting:** No risk. OSC separates city and school data. Verified approach.
2. **BOCES:** Excluded. Not student-serving, no enrollment.
3. **Charter schools:** Excluded. Not in OSC school data.
4. **Historical mergers:** Not tracked. Each year stands alone.
5. **Metric naming:** No prefix. Filter by entity.kind. Concepts like "Debt Service" are legitimately comparable.
