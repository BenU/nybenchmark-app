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
7. Merge PR: `gh pr merge --merge --delete-branch`
8. Update local main: `git switch main && git pull && dci`
9. Deploy: `kd`

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

## Current Feature Work

### Unify Observation New/Edit with Verify Cockpit (Next Up)

The observation new and edit pages should use the same layout as the verify cockpit, with shared partials for consistency.

**Goal:** Users creating or editing observations should see the PDF viewer alongside the form, just like in the verify cockpit.

**Approach (TDD):**
1. Write failing tests for new/edit pages using cockpit layout
2. Extract shared partials from `verify.html.erb`:
   - `_pdf_viewer.html.erb` - Left pane with PDF.js viewer or URL fallback
   - `_observation_form.html.erb` - Right pane with form fields
3. Update `new.html.erb` and `edit.html.erb` to use the verify layout and partials
4. Handle the entity/document selection flow for new observations (entity selection triggers document filter)

**Key files:**
- `app/views/observations/verify.html.erb` - Source of truth for cockpit UI
- `app/views/observations/new.html.erb` - Needs cockpit layout
- `app/views/observations/edit.html.erb` - Needs cockpit layout
- `app/views/observations/_form.html.erb` - Current form partial (to be refactored)
- `app/views/layouts/verify.html.erb` - Full-width layout for cockpit views
- `app/javascript/controllers/pdf_navigator_controller.js` - PDF.js Stimulus controller
- `app/javascript/controllers/metric_value_field_controller.js` - Dynamic value field switching

**Considerations:**
- New observations won't have a document selected initially, so PDF viewer shows placeholder until document is chosen
- Entity selection should filter available documents (existing Stimulus controller handles this)
- The form needs to work for both create (new) and update (edit/verify) actions
- Preserve the "Verify & Next" and "Skip" buttons only for verify action

### Verify Cockpit Technical Details

**Current implementation (as of PR #95):**
- PDF.js via importmap CDN pins (see `config/importmap.rb`)
- Continuous scroll with virtualization (IntersectionObserver renders visible pages + 200px buffer)
- Bidirectional sync: scroll updates page display, page input/buttons scroll to target
- Click any page to capture that page number to form
- Toolbar: prev/next buttons, zoom dropdown, capture button
- Conditional value input (numeric vs text) based on metric type
- Source URL editing via nested attributes

**Production note:** DigitalOcean Spaces requires CORS configuration to allow PDF.js to fetch files. The bucket must allow origin `https://app.nybenchmark.org` with GET/HEAD methods.
