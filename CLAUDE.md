# Claude Code Context

This file provides context for Claude Code sessions on this project.

## Essential Reading

Before making changes, read these files for domain knowledge and constraints:

- **AI-CONTEXT.md** - Domain invariants, non-negotiable rules, and AI usage protocol
- **README.md** - Project overview, core concepts, and development setup

## Development Environment

This project uses a **Docker-first workflow**. Do not run Rails commands directly on the host.

### Key Aliases (defined in user's shell)

| Alias | Command | Purpose |
|-------|---------|---------|
| `dup` | `docker compose up --build` | Start dev server |
| `ddown` | `docker compose down` | Stop containers (keeps DB) |
| `dce` | `docker compose exec web` | Run commands in container |
| `dcr` | `docker compose exec web bin/rails` | Run Rails commands |
| `dci` | `docker compose exec web bin/ci` | Run full CI suite |
| `kd` | `kamal deploy` | Deploy to production |

### Git Workflow

**IMPORTANT: The `main` branch is protected on GitHub.** Never commit directly to main.

1. Create a feature branch: `git switch -c feat/your-feature-name`
2. Make changes
3. Run `dci` to verify tests, RuboCop, Brakeman, and bundle-audit pass
4. Commit with descriptive message
5. Push branch and create PR: `git push -u origin feat/your-feature-name && gh pr create`
6. Wait for CI checks to pass on GitHub
7. **User merges PR on GitHub website** (not via CLI)
8. **User handles in separate terminal:** `git switch main && git pull && dci && kd`

### Database Safety

**NEVER use destructive database commands without explicit user approval:**

| Command | Risk | Safe Alternative |
|---------|------|------------------|
| `db:seed:replant` | DELETES ALL DATA then seeds | `db:seed` (additive only) |
| `db:reset` | Drops and recreates database | `db:migrate` |
| `db:drop` | Destroys entire database | Don't use |

**Safe patterns for data updates:**
- Use `find_or_create_by` / `find_or_initialize_by` for seeding
- Write rake tasks that UPDATE existing records, never DELETE
- Always test data migrations locally with `db:seed` before production
- For production data backfills, use `kamal app exec "bin/rails task:name"`

## Recently Completed

### Entity Index Filtering (PR #105)

Added filter dropdowns to the Entities index page:
- Filter by **Kind** (city, county, town, village, school district)
- Filter by **Government Structure** (strong mayor, council manager, etc.)
- Filters preserve sort params; sorting preserves filter params
- Enables ICMA use case: find "all council manager cities"

### Pagination and Sortable Columns (PR #104)

All four index pages now have:
- **Pagy pagination** (25 items per page) with info tags and navigation
- **Clickable sortable column headers** with up/down arrows indicating sort direction
- URL params (`?sort=column&direction=asc|desc`) for bookmarkable/shareable sorted views
- Helper method: `sortable_column_header` in ApplicationHelper

| Index | Sortable Columns |
|-------|------------------|
| Entities | Name, Kind, Gov. Structure, Docs count, Obs count |
| Documents | Title, Entity, Fiscal Year |
| Metrics | Label, Value Type |
| Observations | Entity, Metric, Year |

### Entity Parent Selector and Governance (PRs #101, #102)

Entity model now supports:
- **ICMA recognition year** for council-manager governments
- **Organization notes** for governance structure details
- **Fiscal parent selector** (shown when `fiscal_autonomy == dependent`)
- **Conditional school district fields** (legal type, board/executive selection)

Entity index improvements:
- Gov. Structure column (sortable) with "Needs research" indicator for missing data
- Fiscal Autonomy column showing parent entity links
- Document and Observation counts

Entity show page improvements:
- "Help wanted" banner when governance data is missing
- "Dependent Entities" section for parent entities
- Parent Entity link for dependent entities

### LLM Discoverability (PR #99)

Added machine-readable context for LLM crawlers:
- `/llms.txt` - Machine-readable site context
- `/for-llms` - Clean Markdown context page
- Schema.org JSON-LD in `app/views/shared/_schema_org.html.erb`

### Parent Document Inheritance (PR #98)

Dependent entities (e.g., Yonkers Public Schools) can see documents from their parent entity. The `Document.for_entity` scope includes parent entity documents.

## Verify Cockpit Technical Details

**Current implementation:**
- PDF.js via importmap CDN pins (see `config/importmap.rb`)
- Continuous scroll with virtualization (IntersectionObserver renders visible pages + 200px buffer)
- Bidirectional sync: scroll updates page display, page input/buttons scroll to target
- Click any page to capture that page number to form
- Toolbar: prev/next buttons, zoom dropdown, capture button
- Conditional value input (numeric vs text) based on metric type
- Source URL editing via nested attributes

**Production note:** DigitalOcean Spaces requires CORS configuration to allow PDF.js to fetch files. The bucket must allow origin `https://app.nybenchmark.org` with GET/HEAD methods.
