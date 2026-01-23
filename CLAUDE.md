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

### Unified Observation New/Edit with Verify Cockpit (PR #98)

Observation new and edit pages now use the same cockpit layout as the verify page, with shared partials.

**Extracted partials:**
- `_pdf_viewer.html.erb` - Left pane with PDF.js viewer or URL fallback
- `_error_messages.html.erb` - Form error display
- `_entity_document_metric_selects.html.erb` - Entity/document/metric dropdowns
- `_observation_form_fields.html.erb` - Value, citation, and notes fields

### Parent Document Inheritance for Dependent Entities (PR #97)

Dependent entities (e.g., Yonkers Public Schools) can now see documents from their parent entity (e.g., City of Yonkers). The `Document.for_entity` scope includes parent entity documents.

### LLM Discoverability (PR #99)

Added machine-readable context for LLM crawlers:
- `/llms.txt` - Machine-readable site context
- `/for-llms` - Clean Markdown context page
- Schema.org JSON-LD in `app/views/shared/_schema_org.html.erb`
- Updated `robots.txt` with llms.txt reference

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
