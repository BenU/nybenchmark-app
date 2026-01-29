# Data Quality Audit Checklist

**Created:** 2026-01-28 (late night session)
**Branch:** `fix/exclude-custodial-pass-throughs`
**Status:** Code changes committed, CI passing. Needs ACFR cross-check before pushing/PR.

## What We Changed and Why

### Problem 1: Custodial Pass-Throughs (T-Fund)

Cities in Westchester and Nassau counties collect taxes on behalf of the county, school districts, and special districts. These pass-through amounts are reported in the Trust & Custodial fund (fund_code `T`, account codes like `TC19354`) and were inflating expenditure totals by 40-50% for affected cities.

**Also discovered:** Yonkers uses `TC19352` (not `TC19354`) for $90.6M in pass-throughs. Rome ($43.1M) was not in the original analysis.

### Problem 2: Interfund Transfers (Other Uses / Other Sources)

OSC reports fund-level data, not government-wide consolidated data. When a city transfers money from the General Fund to the Debt Service Fund, it appears as an "expenditure" (category: "Other Uses") in Fund A and "revenue" (category: "Other Sources") in Fund V. Summing across funds double-counts this money.

In a city's own ACFR, government-wide statements eliminate interfund transfers. We must do the same.

**Scale:** $10.5B in transfer expenditures and $10.5B in transfer revenues across all cities/years.

### Problem 3: Plattsburgh Debt Service 155.6%

The original code filtered expenditures to `fund_code: 'A'` only ($26.1M for Plattsburgh) but queried debt service across all funds ($40.7M). Plattsburgh books all debt in funds H, V, and E — zero in the General Fund. Ratio: $40.7M / $26.1M = 155.6%.

8 cities have debt ONLY in non-A funds: Buffalo, Corning, Glen Cove, Niagara Falls, Norwich, Plattsburgh, Troy, White Plains.

### The Fix

Changed from `WHERE fund_code = 'A'` to:
```
WHERE fund_code != 'T'           -- exclude custodial pass-throughs
  AND level_1_category != 'Other Uses'   -- exclude interfund transfers out
```

For revenue trends on entity pages, also exclude:
```
  AND level_1_category != 'Other Sources'  -- exclude interfund transfers in
```

Debt service queries are unchanged (all funds, no filter needed — it's real spending).

### Key Finding: Revenue Is Clean

TC fund has zero revenue metrics in the database. Pass-throughs only appear on the expenditure side. Revenue totals are not inflated by custodial pass-throughs.

### OSC Documentation

OSC does not publish comparability warnings with their data. The [Accounting and Reporting Manual](https://www.osc.ny.gov/files/local-government/publications/pdf/arm.pdf) and [interfund transfers guidance](https://www.osc.ny.gov/state-agencies/gfo/chapter-xvi/xvi4r-interfund-transactions-and-transfers) describe the accounting rules but don't warn about cross-city comparison pitfalls. Their [data sources page](https://www.osc.ny.gov/local-government/data/local-government-financial-data-sources) has no methodology notes.

GASB Statement 34 requires government-wide statements to eliminate interfund activity. OSC data is fund-level, so we must do this ourselves.

---

## Audit Checklist

For each city below, find the ACFR and compare our numbers to:

1. **Statement of Activities** → "Total Expenses" line (government-wide, full accrual — won't match exactly but should be in the same ballpark)
2. **All Governmental Funds Statement** → Total Expenditures minus "Other Financing Uses" (transfers out) — this is the closest apples-to-apples comparison
3. **Debt Service** → Verify which funds carry debt payments
4. **General Fund Balance Sheet** → "Unassigned Fund Balance" should match our A917 value

### High Priority (most affected by corrections)

#### New Rochelle FY 2024
- [ ] Our corrected expenditures: **$263.2M** (raw was $555.7M — excluded $273.7M T-fund, $18.8M transfers)
- [ ] Debt Service: **$15.6M (5.9%)**
- [ ] Fund Balance (A917): **$38.8M (14.8%)**
- Notes: Biggest proportional TC pass-through impact

#### Plattsburgh FY 2024
- [ ] Our corrected expenditures: **$105.1M** (raw $114.8M — excluded $0 T-fund, $9.7M transfers)
- [ ] Debt Service: **$40.7M (38.7%)** — all in funds H ($17.4M) and V ($23.1M), zero in A
- [ ] Fund Balance (A917): **$7.6M (7.2%)**
- Notes: The 155.6% bug city. 38.7% is still very high — confirm this is real

#### White Plains FY 2025
- [ ] Our corrected expenditures: **$264.9M** (raw $519.7M — excluded $237.3M T-fund, $17.5M transfers)
- [ ] Debt Service: **$17.4M (6.6%)**
- [ ] Fund Balance (A917): **$31.0M (11.7%)**
- Notes: Large TC exclusion. Non-A debt city

### Sanity Checks (less affected)

#### Syracuse FY 2024
- [ ] Our corrected expenditures: **$422.2M** (raw $494.0M — no T-fund, $71.8M transfers excluded)
- [ ] Debt Service: **$28.5M (6.8%)**
- [ ] Fund Balance (A917): **$115.6M (27.4%)** — unusually strong, worth confirming
- Notes: No TC pass-throughs. Clean test case

#### Buffalo FY 2025
- [ ] Our corrected expenditures: **$772.8M** (raw $874.8M — $0.7M T-fund, $101.3M transfers)
- [ ] Debt Service: **$45.7M (5.9%)** — all in V ($39.9M) and E ($5.4M), only $0.5M in A
- [ ] Fund Balance (A917): **$0.0M (0.0%)** — really zero? Check if Buffalo uses different account
- Notes: Non-A debt city. Zero fund balance is suspicious

#### Yonkers FY 2025
- [ ] Our corrected expenditures: **$735.9M** (raw $906.4M — $91.7M T-fund via TC19352, $78.9M transfers)
- [ ] Debt Service: **$80.5M (10.9%)** — V ($64.1M), A ($16.1M), F ($0.3M)
- [ ] Fund Balance (A917): **$61.0M (8.3%)**
- Notes: Uses TC19352 (not TC19354) for custodial pass-throughs

#### Albany FY 2024 — ✅ VERIFIED
- [x] Our corrected expenditures: **$277.4M** (raw $279.7M — no T-fund, $2.3M transfers excluded)
- [x] Debt Service: **$16.0M (5.8%)** — all in Fund A
- [x] Fund Balance (A917): **$9.1M (3.3%)**
- Notes: Minimal corrections needed. All debt in General Fund. Simplest comparison.

**Source:** [Albany 2024 Annual Financial Report](https://www.albanyny.gov/DocumentCenter/View/12979/2024-Annual-Financial-Report?bidId=)

| Fund | PDF page (printed/file) | Line item | Amount | DB match |
|------|------------------------|-----------|--------|----------|
| A – General | p.22 / p.25 | Total for Expenditures and Other Uses | $220,292,694 | ✅ exact |
| A – General | p.21 / p.24 | Debt Service total | $15,976,343 | ✅ exact |
| A – General | p.6 / p.9 | Unassigned Fund Balance | $9,109,582 | ✅ exact |
| CD – Special Grant | p.30 / p.33 | Total for Expenditures and Other Uses | $3,308,735 | ✅ exact |
| H – Capital Projects | p.40 / p.43 | Total for Expenditures and Other Uses | $56,097,418 | ✅ exact |
| **All funds** | | **Sum** | **$279,698,847** | ✅ exact |

Albany has no T-fund (no custodial pass-throughs). $2,348,294 in interfund transfers ("Other Uses") excluded per GASB 34 → corrected total $277,350,553.

Non-A fund unassigned balances are negative (CD: -$889K, H: -$37.7M) — normal for grant (reimbursement timing) and capital (Bond Anticipation Notes) funds. Not included in fiscal health metrics.

#### Rochester FY 2025
- [ ] Our corrected expenditures: **$935.3M** (raw $1,014.8M — $19.2M T-fund, $60.4M transfers)
- [ ] Debt Service: **$33.2M (3.5%)** — mostly A ($27.9M), some E ($3.0M)
- [ ] Fund Balance (A917): **$3.8M (0.4%)** — very low, worth confirming
- Notes: Moderate T-fund exclusion

---

## What to Look For

- **Numbers within ~5-10% of ACFR:** Expect some variance due to accounting basis differences (OSC modified accrual vs ACFR full accrual for government-wide)
- **Debt service fund structure matches:** If the ACFR shows debt in funds we didn't capture, that's a problem
- **Zero fund balance cities:** Buffalo ($0) and Rochester ($3.8M) — confirm these aren't data artifacts
- **High debt service:** Plattsburgh at 38.7% — confirm this reflects reality (could indicate fiscal stress)

## After Audit: Next Steps

If the audit checks out:

1. Push `fix/exclude-custodial-pass-throughs` branch and create PR
2. Update CLAUDE.md with corrected filter documentation
3. Continue with planned feature branches:
   - Branch 2: `feat/non-filing-entities` — Filing status page and late-filer indicators
   - Branch 3: `feat/methodology-page` — Public data methodology page (should document all findings from this audit)

If the audit reveals issues:
- Investigate specific discrepancies before merging
- May need additional exclusions or corrections

## Files Changed (Branch: fix/exclude-custodial-pass-throughs)

- `app/controllers/concerns/city_rankings.rb` — Expenditure filter: exclude T-fund + "Other Uses"
- `app/controllers/concerns/entity_trends.rb` — Same for entity dashboard + exclude "Other Sources" from revenue
- `test/fixtures/metrics.yml` — Added custodial, interfund transfer, and census population fixtures
- `test/fixtures/observations.yml` — Added custodial and transfer observations for Yonkers
- `test/controllers/welcome_controller_test.rb` — TC + transfer exclusion test for rankings
- `test/controllers/entities_controller_test.rb` — TC + transfer exclusion tests for entity page
- `test/controllers/observations_controller_test.rb` — Updated fixture count
