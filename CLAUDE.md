# Claude Code Context

This file provides essential context for Claude Code sessions. For detailed history, see git log and GitHub PRs.

## Essential Reading

- **AI-CONTEXT.md** - Domain invariants and non-negotiable rules
- **README.md** - Project overview and core concepts

## Development Environment

**Docker-first workflow.** Do not run Rails commands directly on the host.

| Alias | Command | Purpose |
|-------|---------|---------|
| `dup` | `docker compose up --build` | Start dev server |
| `ddown` | `docker compose down` | Stop containers |
| `dce` | `docker compose exec web` | Run commands in container |
| `dcr` | `docker compose exec web bin/rails` | Run Rails commands |
| `dci` | `docker compose exec web bin/ci` | Run full CI suite |
| `kd` | `kamal deploy` | Deploy to production |

## Git Workflow

**The `main` branch is protected.** Never commit directly to main.

1. Create feature branch: `git switch -c feat/your-feature-name`
2. Make changes using **TDD when applicable** (write failing tests first)
3. Run `dci` to verify all checks pass
4. Push and create PR: `git push -u origin feat/your-feature-name && gh pr create`
5. **User merges PR on GitHub website** (not via CLI)
6. **User handles deploy in separate terminal:** `git switch main && git pull && dci && kd`

## Testing Approach

**Use TDD for behavior/logic changes:** Write failing tests first, then implement.

**Skip TDD for:** Pure CSS/styling changes, simple config updates, documentation.

**Use fixtures:** Prefer existing fixtures (e.g., `users(:one)`, `entities(:yonkers)`) over creating records from scratch in tests.

## Database Safety

**Never use destructive commands without explicit approval:**
- `db:seed:replant` - DELETES ALL DATA (use `db:seed` instead)
- `db:reset` / `db:drop` - Destroys database (use `db:migrate`)

**Safe patterns:** `find_or_create_by`, rake tasks that UPDATE not DELETE

## Key Domain Rules

**Document uniqueness:** One document per `(entity, doc_type, fiscal_year)`. Use distinct doc_types for different sources (e.g., `us_census_quickfacts` vs `us_census_population`).

**Document source types:**
- `pdf` (default) - Has file attachment, requires `page_reference` on observations
- `web` - URL-only, `page_reference` optional, `pdf_page` auto-cleared
- `bulk_data` - Machine-readable imports (OSC, etc.), `page_reference` optional

**Metric data sources:**
- `manual` (default) - Manually entered data
- `osc` - NYS Comptroller AFR data (account codes like A31201, no dots)
- `census` - US Census Bureau (population, income, poverty)
- `dcjs` - NYS Division of Criminal Justice Services (crime stats)
- `rating_agency` - Bond ratings (Moody's, S&P)
- `derived` - Calculated from other metrics (per capita, ratios)
- `nyc_checkbook` - NYC Checkbook data (NYC is never in OSC - has own Comptroller)

**Observation validation:**
- `page_reference` required for PDF documents, optional for web
- `pdf_page` automatically cleared when switching to web document
- Value must match metric type (numeric vs text)

**Entity relationships:**
- Fiscally dependent entities (e.g., Big Five school districts) have a `parent_id`
- `Document.for_entity(id)` includes parent entity documents

## Verify Cockpit

PDF verification interface at `/observations/:id/verify`:
- PDF.js with continuous scroll virtualization
- Click page to capture `pdf_page` to form
- Conditional value input based on metric type
- Source URL editing via nested attributes

**Production:** DigitalOcean Spaces requires CORS for `https://app.nybenchmark.org`.

## CSS Architecture

Centralized styles in `app/assets/stylesheets/application.css`:
- `.flash`, `.flash--alert`, `.flash--notice` - Notifications
- `.page-header` - Title + action button layouts
- `.button-group` - Horizontal button arrangements
- `.sortable-header` - Clickable table column headers
- `.trend-card`, `.trend-card--revenue` (green), `.trend-card--expenditure` (red), `.trend-card--balance-sheet` (blue) - Financial trend charts
- `.trend-card--placeholder` - Coming soon cards (muted, dashed border)

Avoid inline `style=` attributes; use CSS classes.

## In Progress

**OSC Data Import** - See `PLAN.md` for full roadmap, `db/seeds/osc_data/` for data files and analysis.

**Completed:**
- [x] Downloaded OSC CSV files (1995-2024, 57 cities)
- [x] Analyzed CSV structure (see `db/seeds/osc_data/README.md`)
- [x] Created entity name mapping (see `db/seeds/osc_data/entity_mapping.yml`)
- [x] Documented data quality issues (see `db/seeds/osc_data/DATA_QUALITY.md`)
- [x] Filing status schema decision: **Option C** - derive from observations (no filing status table)
- [x] Schema migrations: added `osc_municipal_code` to entities
- [x] Built `osc:import` rake task
- [x] Tested locally: 647,630 observations imported (31 years, 57 cities)
- [x] Deployed to production

**Completed (metric categories):**
- [x] Added `level_1_category` and `level_2_category` columns to metrics
- [x] Created `osc:backfill_categories` rake task to populate from CSV
- [x] Updated OSC import to set categories for future imports
- [x] Added Category column and filter to metrics index
- [x] Added Category/Subcategory display to metrics show page

**Completed (performance):**
- [x] Fixed observations index filter performance (removed expensive JOINs)
- [x] Fixed documents index filter performance
- [x] Added Bullet safelist for Entity parent eager loading
- [x] Auto-remove stale PID file on container start

**Completed (curated entity dashboard):**
- [x] Replaced "show all categories" with curated financial dashboard
- [x] Fiscal Health section: Unassigned Fund Balance (A917), Cash Position (A200+A201), Debt Service
- [x] Placeholder cards for derived metrics (Fund Balance %, Debt Service %) with "Coming Soon" styling
- [x] Top Revenue Sources: top 5 revenue categories by most recent year value
- [x] Top Expenditures: top 5 expenditure categories (excludes Debt Service)
- [x] Extracted trend logic into `EntityTrends` concern (`app/controllers/concerns/entity_trends.rb`)
- [x] Balance sheet card styling (blue), placeholder card styling (muted, dashed border)

**TODO (prioritized):**
1. [x] Entity dashboard with trends (sparklines by level_1_category)
2. [ ] Derived/comparison metrics (FTEs per capita, police cost per capita, Fund Balance %)
3. [ ] De-emphasize raw observations (remove from main nav, make admin/audit tool)
4. [ ] Import NYC data from Checkbook NYC (separate data source, all years)
5. [ ] Import towns, villages, counties from OSC
6. [x] Normalize metric labels (titleize casing via `osc:normalize_metrics`)
7. [x] Color-code trend charts by account_type (green=revenue, red=expenditure)
8. [x] Curated entity dashboard with fiscal health metrics
9. [ ] Level 2 category drill-down (see options below)

**Level 2 Category Drill-Down Options:**
- **Option A:** Expandable cards - Click level_1 card to expand and show level_2 sub-charts inline
- **Option B:** Dedicated drill-down page - `/entities/:slug/trends/:category` with larger chart, year-by-year values, level_2 breakdown
- **Option C:** Query/filter interface - Add category filters to observations index for ad-hoc exploration

**Completed (view updates):**
- [x] Add late filers to entity_mapping.yml "cities" section (Mount Vernon, Ithaca, Rensselaer, Fulton)
- [x] Entity show: display OSC municipal code when present
- [x] Entity form: exclude `icma_recognition_year` and `osc_municipal_code` (seeded data)
- [x] Entity show: display ICMA recognition nicely ("ICMA-recognized since 1932" or "—")
- [x] Metric show/index: display data source and account code for OSC metrics
- [x] Metric form: add data source dropdown and account code field
- [x] Metric index: add data_source filter
- [x] Document index: add Source column with badge styling

**Key findings:**
- NYC is **never** in OSC system (has own Comptroller, uses Checkbook NYC)
- 4 cities are late filers: Mount Vernon (2020), Ithaca (2021), Rensselaer (2021), Fulton (2022)
- Mount Vernon lost credit rating due to non-filing (per OSC audit)
- ~20% of NY local governments fail to file on time

**Rake tasks available:**
- `data:counts` - Check current stats (non-destructive)
- `data:reset_for_osc` - Clear metrics/observations before import
- `osc:import` - Import all OSC data (1995-2024)
- `osc:import_year[YEAR]` - Import single year
- `osc:update_municipal_codes` - Populate entity OSC codes from mapping
- `osc:normalize_metrics` - Backfill account_type and normalize casing (requires CSV files)

**Account code format:** `A31201` (no dots) - fund + function + object concatenated

## Metric Categories (OSC)

OSC provides classification for metrics via three attributes:

- `account_type`: Financial statement section - `revenue`, `expenditure`, or `balance_sheet`
- `level_1_category`: Broad category (Public Safety, Debt Service, Employee Benefits, etc.)
- `level_2_category`: Specific function (Police, Fire, Interest On Debt, etc.)

**Category hierarchy:**
```
account_type: expenditure
  level_1_category: Public Safety
    level_2_category: Police → A31201, A31202, A31204...
    level_2_category: Fire → A34101, A34102...
  level_1_category: Debt Service
    level_2_category: Interest On Debt
    level_2_category: Debt Principal
```

**Note:** Balance sheet items (GL section) have `account_type: balance_sheet` but typically no level_1/level_2 categories.

**Key balance sheet account codes (used in Fiscal Health dashboard):**
- `A917` - Unassigned Fund Balance
- `A200` - Cash
- `A201` - Cash In Time Deposits

These are queried directly by account_code in `EntityTrends` concern.

**Example aggregation queries:**
```ruby
# Total Debt Service for Yonkers in 2024
Observation.joins(:metric)
           .where(entity: yonkers, fiscal_year: 2024)
           .where(metrics: { level_1_category: "Debt Service" })
           .sum(:value_numeric)

# All revenue for Yonkers in 2024
Observation.joins(:metric)
           .where(entity: yonkers, fiscal_year: 2024)
           .where(metrics: { account_type: :revenue })
           .sum(:value_numeric)

# Police expenses (level_2) across all years
Observation.joins(:metric)
           .where(entity: yonkers)
           .where(metrics: { level_2_category: "Police" })
           .group(:fiscal_year).sum(:value_numeric)
```

**Rake tasks:**
- `osc:normalize_metrics` - Backfill account_type and normalize category casing to Title Case
- `osc:backfill_categories` - (Legacy) Populate categories for existing metrics from CSV files

## Performance Notes

**Entity index query optimization:** With 650K observations, avoid `left_joins` with `COUNT(DISTINCT)`. Use correlated subqueries instead:

```ruby
# SLOW (15s) - joins all observations then groups
Entity.left_joins(:observations).select("COUNT(DISTINCT observations.id)").group("entities.id")

# FAST (0.04s) - uses entity_id index efficiently
Entity.select("(SELECT COUNT(*) FROM observations WHERE entity_id = entities.id) AS observations_count")
```

**Indexes in place:** `observations.entity_id`, `documents.entity_id` - critical for subquery performance.
