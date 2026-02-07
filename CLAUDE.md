# Claude Code Context

This file provides essential context for Claude Code sessions. For detailed history, see git log and GitHub PRs.

## Essential Reading

- **README.md** - Project overview, tech stack, and getting started
- **AUDIT.md** - Data quality audit checklist (pending ACFR cross-check)
- **doc/ops.md** - Production operations, backups, security

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
6. **User handles deploy in separate terminal:** `git switch main && git pull && kd`
   - Skip `dci` locally — CI already passed on the same commits in GitHub. Only re-run `dci` if you made local changes after merge (e.g., conflict resolution).

**Docs-only changes (CLAUDE.md, AUDIT.md, PLAN.md, README.md, etc.):** Commit locally on a branch but don't push or deploy — fold into the next feature PR unless otherwise specified. Skip `dci` and `kd` since nothing user-facing changed. Exception: push a standalone docs PR when significant planning or institutional knowledge is at stake and warrants off-machine backup.

## Testing Approach

**Use TDD for behavior/logic changes:** Write failing tests first, then implement.

**Skip TDD for:** Pure visual CSS changes (colors, spacing, fonts), simple config updates, documentation.

**Navigation/layout changes require tests:** Adding, removing, or moving links in the navbar or footer is a functional change (affects what users can access), not a styling change. Update existing navigation integration tests to match the desired state before modifying views.

**Use fixtures:** Prefer existing fixtures (e.g., `users(:one)`, `entities(:yonkers)`) over creating records from scratch in tests.

## Database Safety

**Never use destructive commands without explicit approval:**
- `db:seed:replant` - DELETES ALL DATA (use `db:seed` instead)
- `db:reset` / `db:drop` - Destroys database (use `db:migrate`)

**Safe patterns:** `find_or_create_by`, rake tasks that UPDATE not DELETE

## Adding Environment Variables

When adding a new environment variable, update these files:

| File | Purpose |
|------|---------|
| `.env` | Local development (gitignored) |
| `.kamal/secrets` | Production secrets (gitignored) - format: `VAR_NAME=$VAR_NAME` |
| `config/deploy.yml` | Declare in `env.secret` array for Kamal to inject |

**Current environment variables:**
- `CENSUS_API_KEY` - US Census Bureau API key (register at api.census.gov)
- `ADMIN_EMAIL` - Email for admin notifications
- `BREVO_SMTP_USERNAME` / `BREVO_SMTP_PASSWORD` - Transactional email

After updating secrets: `kamal env push` then `kd` to deploy.

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
- `parent_id` represents **fiscal/reporting roll-up only**, not geography or political containment
- Geographic containment is not currently modeled; do not overload `parent_id` for this
- `Document.for_entity(id)` includes parent entity documents

**School district rule:**
- If `kind == school_district`, `school_legal_type` must be present
- Otherwise, `school_legal_type` must be blank

**Authentication & authorization:**
- Authentication via Devise
- No role distinctions — all logged-in users have full read/write access to all resources
- Public visitors can view entities, landing page, methodology, and non-filers pages

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
- `.non-filer-banner` - Amber warning banner for non-filing entities
- `.non-filer-badge` - Small inline amber "Late" badge on entity index
- `.non-filer-callout` - Landing page note about excluded non-filers
- `.trend-missing-years` - Note below trend charts for missing years

Avoid inline `style=` attributes; use CSS classes.

## Project History

**OSC Data Import** - See `db/seeds/osc_data/` for data files and analysis.

**Completed:**
- [x] Downloaded OSC CSV files (1995-2024, 57 cities)
- [x] Analyzed CSV structure (see `db/seeds/osc_data/README.md`)
- [x] Created entity name mapping (see `db/seeds/osc_data/entity_mapping.yml`)
- [x] Documented data quality issues (see `db/seeds/osc_data/DATA_QUALITY.md`)
- [x] Filing status schema decision: **Option C** - derive from observations (no filing status table)
- [x] Schema migrations: added `osc_municipal_code` to entities
- [x] Built `osc:import` rake task
- [x] Tested locally: 647,630 observations imported (1995–2024, 57 cities)
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

**Completed (Census data import):**
- [x] Created FIPS place code mapping (`db/seeds/census_data/entity_fips_mapping.yml`)
- [x] Created Census metric definitions (`db/seeds/census_data/metric_definitions.yml`)
- [x] Built `census:import` rake task with CensusImporter class
- [x] Added test coverage (`test/tasks/census_import_test.rb`)
- [x] Imported 14,322 observations (2012-2023, 62 cities, 21 metrics)

**Completed (landing page & entity redesign):**
- [x] Landing page with city rankings (Fund Balance %, Debt Service %, Per-Capita Spending)
- [x] Top 10 / Bottom 10 toggle via Stimulus controller
- [x] Year selection uses most recent year with >= 50% city coverage (avoids sparse early-filer data)
- [x] Entity hero stats bar (Population, Fund Balance %, Per-Capita Spending, Debt Service %)
- [x] Entity page reordered: hero stats → trends → docs → governance (collapsible) → recent data
- [x] Observations moved from main nav to footer
- [x] Removed needs-research banner (relic from manual data entry era)

**Completed (manual data cleanup):**
- [x] Created `data:cleanup_manual` rake task (PR #140)
- [x] Ran locally: removed 12 documents, 78 observations, 69 orphaned metrics
- [x] Deployed to production and ran: removed 9 documents, 69 observations, 63 orphaned metrics
- [x] Fixes A917 double-counting (manual + OSC values coexisted for New Rochelle and Yonkers)
- [x] Production counts after cleanup: 2,507 documents, 4,343 metrics, 661,883 observations
- [x] Bumped brakeman 8.0.0 → 8.0.1

**Completed (EV Grant Sprint — PR #145):**
- [x] Navbar cleanup: public nav is Cities, Non-Filers, Methodology, Blog; Documents/Metrics behind auth only; Verify Queue removed from nav
- [x] Footer: added Documents, Metrics, Methodology links; observations link kept in footer
- [x] PagesController with `/methodology` and `/non-filers` routes
- [x] Methodology page: data sources (OSC, Census), metric calculations (Fund Balance %, Debt Service %, Per-Capita Spending), all-fund approach, T-fund exclusion, interfund transfers, known limitations
- [x] FilingStatus concern (`app/models/concerns/filing_status.rb`): `last_osc_filing_year`, `osc_missing_years`, `osc_filing_rate`, `filing_category` (chronic/recent_lapse/sporadic), `Entity.latest_majority_year`, `Entity.filing_report`
- [x] Non-filers page: filing compliance tables grouped by category, filing rates, Mount Vernon case study
- [x] Entity show: non-filer amber banner, missing years note in Financial Trends section
- [x] Entity index: "Late" badge on non-filer cities, filing status filter dropdown
- [x] Landing page: non-filer callout with count and link to `/non-filers`
- [x] CityRankings concern: exposed `@non_filer_count`
- [x] TrendChartHelper for consistent x-axis year labels (string keys for Chart.js category scale)
- [x] Sitemap updated with methodology and non-filers pages
- [x] 207 new test assertions across 6 new and 5 updated test files

**Completed (filing status bugfix — PR #146):**
- [x] Fixed `filing_category` returning `:recent_lapse` for cities filing ahead of `latest_majority_year` (e.g., early filers for 2025 when target year is 2024)
- [x] Changed `== as_of_year` to `>= as_of_year` in `FilingStatus#filing_category`

**In Progress (county partisan scatter — branch `feat/county-partisan-scatter`):**

- [x] `lib/tasks/osc_counties.rake` — `CountyEntityCreator` + `CountyOscImporter`, rake tasks: `osc:counties:create_entities`, `osc:counties:import`, `osc:counties:import_year[YEAR]`
- [x] 57 county entities created; OSC financial data imported
- [x] `app/views/shared/_scatter_chart.html.erb` — shared scatter chart partial used by both county and school district comparisons
- [x] `scatter_chart_controller.js` — Stimulus controller that creates Chart.js scatter charts directly (bypasses Chartkick), with plugins (partisan zones, reference lines) and custom tooltips built into the initial config
- [x] School district comparisons use same shared partial (no regression)
- [x] `CountyPartisanScatterData` concern — loads partisan CSV, calculates Fund Balance %, Debt Service %, Operating Ratio vs Conservative %
- [x] Fund balance uses A917 (GASB 54, FY 2011+) or A910+A911 (pre-GASB 54) for historical consistency
- [x] Operating Ratio = Revenue / Expenditures × 100 (>100% = surplus), with green 100% reference line and compressed y-axis (70-140%)
- [x] `CountyComparisonsController` + view at `/counties/compare` with 3 scatter charts
- [x] Year scroller: arrow buttons, range slider, mouse wheel. `year_scroller_controller.js` Stimulus controller navigates via Turbo with `?year=YYYY`
- [x] Route, navbar link ("Compare Counties"), sitemap entry
- [x] Methodology page updated: added Operating Ratio definition, GASB 54 fund balance note, Counties section
- [x] Dot color: `#64748b` (Tailwind slate-500, visible in light + dark modes)
- [x] Background partisan zones (blue/purple/red gradient behind scatter plots)
- [x] Custom tooltips showing county/district names with formatted values
- [x] Green dashed reference line at 100% on operating ratio chart

*Remaining work:*
- [ ] Verify in browser: all 3 charts render with zones, tooltips, and reference line
- [ ] Gitignore `db/seeds/osc_data/county_all_years/` (large CSVs)
- [ ] Census county demographic import (API works: `for=county:*&in=state:36`, needs FIPS mapping + task)
- [ ] Push branch, create PR, merge

*Key files:*
- `app/javascript/controllers/scatter_chart_controller.js` — Stimulus controller: creates Chart.js scatter charts directly with plugins/tooltips in initial config
- `app/views/shared/_scatter_chart.html.erb` — shared partial: passes config as Stimulus data attributes
- `app/controllers/concerns/county_partisan_scatter_data.rb` — data queries + scatter series building
- `app/controllers/county_comparisons_controller.rb` — loads 3 chart datasets + available years
- `app/views/county_comparisons/show.html.erb` — 3 charts with year scrollers, legend, about section
- `app/javascript/controllers/year_scroller_controller.js` — Stimulus controller for year navigation
- `lib/tasks/osc_counties.rake` — county entity creation + OSC data import
- `db/seeds/county_data/council_partisan_composition_2025.csv` — partisan data for 57 counties

**TODO (prioritized):**
1. [x] ~~Exclude custodial pass-throughs from expenditure totals~~ — Merged PR #137. ACFR cross-checks still pending (only Albany verified, see AUDIT.md)
2. [x] ~~Add `app.nybenchmark.org` to Google Search Console~~ — Registered, verified, sitemaps submitted for both properties. Jekyll `_config.yml` url fixed. Validated redirect fix for nybenchmark.org.
3. [x] ~~Highlight non-filing entities~~ — Merged PR #145. FilingStatus concern, `/non-filers` page, amber banners/badges, landing page callout. Fixed early-filer bug in PR #146.
4. [x] ~~Data methodology page~~ — Merged PR #145. `/methodology` page with full content, added to sitemap.
5. [x] ~~Fix `www` CNAME redirect chain~~ — Added Cloudflare Page Rule: `www.nybenchmark.org/*` → 301 to `https://nybenchmark.org/$1`. Redirect now happens at Cloudflare edge, no longer hops through GitHub Pages/Fastly.
6. [x] ~~Fix NYC non-filer misclassification~~ — Merged PR #154. Added `osc_filing_exempt?` to `FilingStatus`, excluded NYC from `filing_category`, `filing_report`, `latest_majority_year`, non-filers page, landing page rankings. Non-filer count corrected from 12 to 11.
7. [ ] **Verify backup retention** — After next 2:00 AM run, confirm old backups (>30 days) were pruned: `ssh deploy@68.183.56.0 "/snap/bin/aws s3 ls s3://nybenchmark-production/db-backups/ --endpoint-url https://nyc3.digitaloceanspaces.com"` (PR #163)
8. [ ] **Production monitoring** — Add `lograge` gem (structured single-line request logs, zero overhead) and AppSignal free tier (error tracking, host metrics, slow query detection, no overage fees, Rust agent ~15-25MB, no Redis needed). Skip `rails_performance` (needs Redis) and Skylight (auto-bills on overage). Optionally enable `rack-mini-profiler` in production for admin-only ad-hoc debugging.
9. [ ] **Wikipedia link on entity show page** — Add a link to the entity's Wikipedia page on the entity show page, if one exists. Store a `wikipedia_url` (or derive from entity name/slug) and render it in the entity header or governance section.
10. [ ] **Per-page Open Graph meta tags** — Current OG tags use site-wide defaults. Build a helper or `content_for :head` blocks to generate per-page `og:title`, `og:description`, and optionally `og:image` for entity dashboards (e.g., "Mount Vernon — City Dashboard | NY Benchmark"), the non-filers page, methodology, and landing page. This improves social sharing previews and search engine rich results.
11. [ ] **Chart.js missing-year annotations on entity trend charts** — Amber highlight rectangles on trend charts for years with no data filed. Chart.js annotation plugin has a loading/timing conflict with chartkick's importmap-based Chart.js (UMD plugin needs `window.Chart` at parse time, but ES modules load later). Attempted dynamic script loading; deferred for now. Options: pin annotation plugin in importmap, vendor the ESM build, or use a Stimulus controller to add annotations after chart render.
12. [ ] **Complete ACFR audit** — Verify remaining cities in AUDIT.md (New Rochelle, Plattsburgh, White Plains, Syracuse, Buffalo, Yonkers, Rochester) against their ACFRs
13. [ ] Import NYC data from Checkbook NYC (separate data source, all years). After import, request GSC indexing for `https://app.nybenchmark.org/entities/nyc` and other key entity pages.
14. [ ] **Infrastructure scaling (phased — see `doc/ops.md` for full details)**
    - **Phase 1 (now):** Resize to `s-1vcpu-2gb` ($12/mo, 50GB disk). Eliminates swap thrashing at current 661K observations. Tune PG: `shared_buffers=512MB`, `effective_cache_size=1.5GB`.
    - **Phase 2 (NYC import):** No resize needed — 2GB handles ~900K observations fine.
    - **Phase 3 (counties, ~62 entities):** Resize to `s-2vcpu-4gb` ($24/mo, 80GB disk) before import. Tune PG: `shared_buffers=1GB`, `effective_cache_size=3GB`.
    - **Phase 4 (towns + villages, ~1,500 entities):** Resize to `s-4vcpu-8gb` ($48/mo, 160GB disk). Tune PG: `shared_buffers=2GB`, `effective_cache_size=6GB`. ~15-20M observations.
    - **Phase 5 (school districts + authorities, ~1,700 entities):** 8GB droplet still sufficient. ~22-28M observations.
    - **Phase 6 (full Census/DCJS for all entities):** Evaluate managed PostgreSQL if ops burden grows. ~25-30M observations.
    - **Trigger to resize:** swap usage > 100MB sustained, or before any bulk import that will >2x observation count.
15. [ ] Import towns, villages, counties, districts, and authorities from OSC
16. [ ] **Side-by-side city comparison tool** — Select two or more cities and compare them on any metric across years. Core benchmarking feature. Likely a new route (`/compare?cities=albany,syracuse`) with multi-select UI, shared chart, and table view. Consider URL-shareable comparisons for embedding/sharing.
17. [ ] **Metric-specific leaderboards** — Rank all cities on any individual metric (e.g., police spending per capita, fire department costs, debt service burden). Extends the landing page's three summary rankings to arbitrary metrics. Could be a filterable index or per-metric show page.
18. [ ] **State Aid as % of Revenue** — Derived metric benchmarking state aid dependency across cities. OSC revenue data already includes state aid line items; needs metric definition, derivation logic, hero stat / ranking placement. Exact denominator (revenue vs expenditures) TBD — research industry standard (GFOA/ICMA practice).
19. [ ] Level 2 category drill-down (see options below)
20. [ ] Import crime data from DCJS/FBI UCR (property and violent crime rates)
21. [ ] Import demographic data for counties, towns, villages, and school districts from Census
22. [ ] Import FTE staffing data by department (police, fire, public works, etc.) from ACFRs
23. [ ] **Cross-entity-type benchmarking** — Compare cities vs. villages vs. towns on comparable per-capita metrics. Requires entity type imports (#15) and population data for non-city entities (#21). Enables questions like "Do cities spend more on public safety per capita than villages?"
24. [ ] **Demographic context for comparisons** — Overlay poverty rates, crime rates, population density, and other contextual variables on spending comparisons. Helps distinguish policy choices from structural differences. Requires crime data (#20) and expanded Census data (#21).
25. [ ] **Automate OSC/Census data refresh** — Cron job (via solid_queue) to periodically re-import OSC and Census data as new years become available. Currently manual rake tasks.
26. [ ] **Import historical county council partisan composition** — Currently using only Nov 2025 election results (`council_partisan_composition_2025.csv`) for all fiscal years. Gather historical election results (or at minimum a few benchmark years) so the scatter x-axis reflects actual partisan makeup for each fiscal year, not just the current one. Source TBD (NY Board of Elections, county clerk records, Ballotpedia).
27. [ ] **Investigate missing school district financial charts** — School district entity show pages only display a Debt Service trend chart. Fund Balance, revenue, and expenditure charts are missing. Determine whether the data exists in the imported OSC school district data (check account codes/categories), whether `EntityTrends` concern needs school-district-specific logic, or whether additional metrics need to be derived.
28. [ ] **Read: NY partisan politics background** — Two articles for context on historical county partisan shifts, relevant to interpreting the scatter charts and sourcing historical election data (#26):
    - "New York's Republican Crack-Up" (2001) — https://www.city-journal.org/article/new-yorks-republican-crack-up
    - "The Decline of the Republican Party in New York State" (2011, URI honors thesis) — https://digitalcommons.uri.edu/cgi/viewcontent.cgi?article=1270&context=srhonorsprog
29. [ ] **Cache county comparison scatter data** — Year scrolling on `/counties/compare` is slow because each year change triggers 3 heavy queries (expenditures, fund balances, debt service across 57 counties). Add `Rails.cache.fetch("county_scatter_#{year}")` to cache query results per year. First visit is slow, repeat visits instant. Must invalidate cache after data imports (`osc:counties:import`). If still too slow, consider preloading adjacent years as JSON for client-side swapping.

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
- `census:import` - Import Census ACS 5-year data (2010-2023, requires CENSUS_API_KEY)
- `census:import_year[YEAR]` - Import Census data for single year
- `census:preview` - Dry run Census import (verifies API key and entity matching)
- `data:cleanup_manual` - Remove manually-entered documents/observations (keeps OSC and Census)
- `osc:counties:create_entities` - Create county entities from OSC county CSV
- `osc:counties:import` - Import all county OSC financial data
- `osc:counties:import_year[YEAR]` - Import county OSC data for single year

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

## SEO & Sitemap

**Two domains, two sitemaps:**
- `nybenchmark.org` — Jekyll marketing site (GitHub Pages). Sitemap generated by `jekyll-sitemap` plugin. Requires `url: "https://nybenchmark.org"` in `_config.yml`.
- `app.nybenchmark.org` — Rails app (DigitalOcean/Kamal). Sitemap generated by `sitemap_generator` gem (`config/sitemap.rb`). Uploaded to DO Spaces on deploy.

**Google Search Console:** Both domains are registered as separate properties. Sitemaps submitted for each.
- `nybenchmark.org` — submit `https://nybenchmark.org/sitemap.xml`
- `app.nybenchmark.org` — submit the DO Spaces URL from `config/sitemap.rb`

**Sitemap best practices:**
- Only include public-facing pages that should appear in search results (entities, landing page, future benchmark/comparison pages).
- Do NOT include admin/audit pages (documents, metrics, observations) — these are marked `noindex`.
- **When adding new public-facing pages** (e.g., benchmark comparisons, methodology page), add them to `config/sitemap.rb` and regenerate.

**noindex meta tag:**
- Documents, metrics, and observations controllers call `before_action :set_noindex` (defined in `ApplicationController`).
- The shared head partial (`app/views/shared/_head.html.erb`) renders `<meta name="robots" content="noindex, nofollow">` when `@noindex` is set.
- Entity and landing pages do NOT set `@noindex` — they should be indexed.
- Test coverage: each controller has noindex assertion tests in its controller test file.

**When adding a new controller/resource:**
- If it's public-facing content (should appear in search): add to `config/sitemap.rb`, do NOT add `set_noindex`.
- If it's admin/audit tooling: add `before_action :set_noindex`, do NOT add to sitemap. Add noindex tests.

## Performance Notes

**Entity index query optimization:** With 650K observations, avoid `left_joins` with `COUNT(DISTINCT)`. Use correlated subqueries instead:

```ruby
# SLOW (15s) - joins all observations then groups
Entity.left_joins(:observations).select("COUNT(DISTINCT observations.id)").group("entities.id")

# FAST (0.04s) - uses entity_id index efficiently
Entity.select("(SELECT COUNT(*) FROM observations WHERE entity_id = entities.id) AS observations_count")
```

**Indexes in place:** `observations.entity_id`, `documents.entity_id` - critical for subquery performance.

## Data Quality: Custodial Pass-Throughs

**Problem:** Cities in Westchester and Nassau counties act as tax collectors for county, school district, and special district taxes. These pass-through amounts are reported in the Trust & Custodial (TC) fund under account code `TC19354` ("Other Custodial Activities"). This inflates their apparent expenditures by 40-50%.

**Affected cities and FY 2024 impact:**

| City | TC19354 | % of Total Expenditures | Per-Capita With | Per-Capita Without |
|------|---------|------------------------|-----------------|--------------------|
| New Rochelle | $274M | 49% | $6,810 | $3,456 |
| White Plains | $234M | 47% | $8,348 | $4,433 |
| Glen Cove | $90M | 52% | $6,089 | $2,898 |
| Peekskill | $54M | 42% | $5,099 | $2,971 |

**Fix approach (implemented):** Exclude T-fund (`fund_code: 'T'`) from expenditure totals AND exclude interfund transfers (`level_1_category: 'Other Uses'` for expenditures, `'Other Sources'` for revenue). This uses all legitimate fund data while removing pass-throughs and double-counted transfers. See AUDIT.md for verification checklist.

**Note:** Yonkers uses TC19352 ($90.6M), not TC19354. Rome ($43.1M) was also not in the original analysis.

## Data Quality: Interfund Transfer Double-Counting

**Problem:** OSC reports fund-level data where interfund transfers appear as expenditures ("Other Uses") and revenues ("Other Sources"). Cities' own ACFRs eliminate these in government-wide statements. We must do the same.

**Scale:** $10.5B in transfer expenditures (A99019, A99509, etc.) across all cities/years.

**Fix approach (implemented):** Exclude `level_1_category: 'Other Uses'` from expenditure aggregations and `'Other Sources'` from revenue aggregations.

**Plattsburgh debt service fix:** The old A-fund-only filter gave Plattsburgh 155.6% debt service (all debt in H/V/E funds, denominator only counted A-fund). The new all-fund-minus-exclusions approach gives 38.7%. 8 cities have debt only in non-A funds: Buffalo, Corning, Glen Cove, Niagara Falls, Norwich, Plattsburgh, Troy, White Plains.

## Data Quality: Fund Structure Variation

Cities organize their funds differently. Some run water/sewer through the General Fund (A), others use Enterprise (E), Water (F), and Sewer (G) funds. Debt service may be in A, V, H, C, or E. The all-fund approach (minus T-fund and transfers) handles this correctly by including all legitimate spending regardless of fund structure.

## Data Quality: Late/Non-Filing Cities

**4 cities are known late filers:**
- Mount Vernon (last filed: 2020) — lost credit rating due to non-filing per OSC audit
- Ithaca (last filed: 2021)
- Rensselaer (last filed: 2021)
- Fulton (last filed: 2022)

~20% of NY local governments fail to file on time. Non-filing cities are visually distinguished with amber "Late" badges on entity index, amber banners on entity show, and excluded from landing page rankings. See `/non-filers` page and `FilingStatus` concern.
