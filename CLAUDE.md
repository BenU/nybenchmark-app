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
- `osc` - NYS Comptroller AFR data (account codes like A3120.1)
- `census` - US Census Bureau (population, income, poverty)
- `dcjs` - NYS Division of Criminal Justice Services (crime stats)
- `rating_agency` - Bond ratings (Moody's, S&P)
- `derived` - Calculated from other metrics (per capita, ratios)
- `nyc_checkbook` - NYC Checkbook data (NYC 2011+, separate from OSC)

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

Avoid inline `style=` attributes; use CSS classes.

## In Progress

**OSC Data Import** - Schema ready for NYS Comptroller bulk data import. See `PLAN.md` for full roadmap.

**Next steps:**
1. Download OSC CSV files to local dev environment
2. Analyze CSV structure, confirm data integrity
3. Build and test `osc:import` rake task locally
4. Verify local database populated correctly
5. Replicate in production: download CSVs to server, run rake task

**Rake tasks available:**
- `data:counts` - Check current stats (non-destructive)
- `data:reset_for_osc` - Clear metrics/observations before import

**Account code fields on Metric:** `account_code`, `fund_code`, `function_code`, `object_code`
