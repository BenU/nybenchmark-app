# AI-CONTEXT.md
## Canonical Rules for AI Assistance on NY Benchmarking App

This file defines **how AI assistants must operate** on this project.
It is not a specification of the system; the code is authoritative.

---

## 0. Project Snapshot (Non-Authoritative)

- **Mission:** Collect, verify, and benchmark financial/operational data from New York State local governments with full auditability.
- **Hard invariant:** Every persisted datapoint must be traceable to a specific source document and a specific page/reference.
- **Primary domain objects:** Entities, Documents, Metrics, Observations (exact schema/validations live in code).

Always verify the current truth in:
- `db/schema.rb`
- models
- migrations
- tests

---

## 1. Source of Truth & Conflict Handling (Strict)

### Authority order (for reasoning only)

1. **Code and schema**
   - `db/schema.rb`
   - model files
   - migrations
   - tests
2. **User prompt (intended change)**
3. **AI-CONTEXT.md (invariants & workflow rules)**
4. **README.md (explanatory / onboarding)**

### Conflict rule (non-negotiable)

If the AI detects a conflict between:
- code and prompt, or
- code and AI-CONTEXT.md / README.md, or
- prompt and AI-CONTEXT.md

The AI must:
1. **Explicitly flag the conflict**
2. **Explain why it matters**
3. Either:
   - proceed cautiously *only if the conflict does not affect correctness*, or
   - **stop and ask for clarification**

The AI must never silently choose a resolution in the presence of ambiguity.

---

## 2. Tech Stack & Architecture Snapshot (Non-Authoritative)

> This section is a snapshot for orientation. Exact versions/configuration are defined by the codebase (Gemfile, Dockerfiles, etc.).

- **Ruby:** 3.4.x (project currently targets Ruby 3.4.7)
- **Rails:** 8.1.x
- **Database:** PostgreSQL (Docker in development and production)
- **Authentication:** Devise
- **Authorization:** Currently “all logged-in users can do everything” (no roles)
- **Frontend:** Hotwire (Turbo + Stimulus), server-rendered Rails views
- **Assets:** Propshaft; JS via importmap (no Node build required for basic JS)
- **CSS:** Tailwind via `tailwindcss-rails` (where used)
- **Auditing:** PaperTrail (version tracking)
- **Storage:** ActiveStorage to S3-compatible object storage in production (DigitalOcean Spaces)
- **Background jobs / cache / cable:** Solid Queue / Solid Cache / Solid Cable (where configured)
- **Deployment:** Kamal + Docker (reverse proxy via Traefik in production)
- **Testing:** Minitest (`bin/rails test` is the source of truth)

---

## 3. Mandatory Context Files (Required Before Changes)

Before making or suggesting changes, the AI must confirm access to:
- `db/schema.rb`
- relevant model files
- relevant tests
- any CSVs / seed files being modified

If required files are missing or stale:
> Stop and request them. Do not infer.

### Task-specific required context (guidance)

**UI/View tasks**
- `AI-CONTEXT.md`
- `db/schema.rb`
- `config/routes.rb`
- target controller(s) + view(s)
- target model(s)
- target fixtures used by tests (if applicable)
- failing/expected tests (or a clear acceptance checklist if no tests exist)

**Logic/Backend tasks**
- `AI-CONTEXT.md`
- `db/schema.rb`
- relevant model(s) + related models (associations)
- failing/expected tests
- any service objects/modules touched

**Data import / CSV tasks**
- CSV sample(s)
- import code
- validations/constraints
- tests proving idempotency and correct mapping

**Docker/infra tasks**
- `Dockerfile` / `Dockerfile.dev`
- `docker-compose.yml`
- relevant environment config (example `.env`, deploy config, etc.)

---

## 4. Core Domain Invariants (High-Level Only)

### Entities
- `entities` is the single canonical table for government bodies.
- Governance structure lives **only on Entity**:
  - string-backed enums
  - `organization_note`
- Observations must **not** encode governance structure.

### Fiscal / Reporting Hierarchy
- `parent_id` represents **fiscal / reporting roll-up only**
- It does **not** represent geography or political containment.

Examples:
- Yonkers Public Schools → parent: Yonkers
- New Rochelle City School District → no parent (fiscally independent)

### School District Rule
- If `kind == school_district`:
  - `school_legal_type` must be present
- Otherwise:
  - `school_legal_type` must be blank

(Exact validations live in code.)

### Geographic containment (future)
- Geographic or political containment is **not currently modeled**
- Do not overload `parent_id` for geography
- A separate relationship may be added later

---

## 5. Authentication & Authorization

- **Authentication:** Devise.
- **Authorization:** All approved users have full read/write access to all resources (Entities, Metrics, Documents, Observations).
  - There is currently no distinction between logged in "User" and "Admin."

---

## 6. Development & Git Workflow (Strict)

### Branch and Commit Message Conventions

Use a prefix for both branch names and commit messages.

| Prefix     | Description                                           |
|------------|-------------------------------------------------------|
| `feat`     | A new feature                                         |
| `fix`      | A bug fix                                             |
| `docs`     | Documentation changes                                 |
| `style`    | Formatting / style-only changes                       |
| `refactor` | Code changes that neither fix a bug nor add a feature |
| `test`     | Adding or correcting tests                            |
| `chore`    | Maintenance, dependency updates                       |
| `ci`       | CI/CD workflow changes                                |

**Examples:**
- Branch: `feat/entity-governance-modeling`
- Commit: `feat(entities): add governance enums and fiscal hierarchy`

### Workflow Constraints

- `main` branch is protected
- Never push directly to `main`
- All work must happen on a feature branch

Required sequence:
1. Create/switch to a feature branch
2. Write failing tests (when appropriate)
3. Implement changes
4. Update fixtures/seeds (when appropriate)
5. Run tests locally
6. Push branch
7. Open PR
8. CI must pass
9. Merge
10. Pull `main` locally
11. Deploy

### Pre-flight (branch maintenance, low-friction)

At the start of any new feature/fix request (before tests or implementation), the AI must:

1. Assume the user is currently on `main` unless told otherwise.
2. Provide a suggested branch name and the exact command to create/switch:
   - Example: `git switch -c feat/<short-topic>`
3. If there are already uncommitted changes on `main`, instruct the user to create the feature branch
   *before* any `git add` or `git commit` so the changes move onto the feature branch automatically.
4. Do not require the user to paste `git status` or confirm they switched branches unless they report a Git error or confusion.
5. If the user supplies an order-of-operations that starts with tests, the AI must insert “Step 0: Create branch” ahead of tests and proceed with the requested workflow.

---

## 7. Local Development (Docker-first) & Gem Updates

### Docker-first development

- Run Rails and dependencies via Docker Compose.
- Container-to-container DB traffic uses:
  - host: `db`
  - port: `5432`

### Database port publishing (security)

- Prefer **not publishing** Postgres at all unless you truly need host DB tools.
- If publishing Postgres to the host, bind to localhost only:
  - `127.0.0.1:5433:5432`
- Never publish Postgres bound to `0.0.0.0` on a shared network.

### Gems / Bundler workflow (Docker)

- Gems are installed **inside** the `web` container.
- For fast iteration, use a named volume mounted at `/usr/local/bundle` (commonly `bundle_cache`) so gem installs persist across restarts.
- The `web` service can start with:
  - `bundle check || bundle install`
  - then `bin/rails server ...`

### Updating gems after merging Dependabot PRs

Preferred:
1. Merge Dependabot PR(s) that update `Gemfile.lock`
2. Pull `main` locally
3. Install/update gems in the running container
4. Run tests

Commands:
```bash
git pull origin main
docker compose exec web bundle install
docker compose exec web bin/rails test
```

Avoid running `bundle update` with no gem names; use targeted updates only when needed.

### If native extensions get weird (or Ruby version changes)

Reset the bundler cache volume and reinstall:
```bash
docker compose down
docker volume rm <project>_bundle_cache
docker compose up -d --build
docker compose exec web bundle install
```

---

## 8. Infrastructure & Security Invariants (Strict)

### Database Isolation
- The database container must **never** expose Postgres to the host's public interface (`0.0.0.0`).
- Database access must occur via the internal Docker network or via SSH tunnel (production).

### Log Management
- All containers in `deploy.yml` must utilize the `json-file` logging driver with `max-size` and `max-file` limits to prevent disk exhaustion.

### User Context
- Deployment and operational scripts should target the `deploy` user, not `root`.

---

## 9. AI Output Expectations

AI responses should:
- Prefer full-file replacements (complete file contents) for any file that changes,
  unless the user explicitly asks for a diff.
- When only a small part of a file changes, also include a “drop-in snippet” option.
- Call out order-of-operations risks
- Avoid duplicating schema/model code into markdown
- Prefer correctness and auditability over brevity

When in doubt, ask.

---

## 10. Current Context Snapshot (Non-Authoritative)

### Domain Model
- Entity governance modeling implemented via enums (kind, government_structure, fiscal_autonomy, school_legal_type)
- School districts are first-class entities with conditional fields
- Fiscal parent relationships (`parent_id`) reflect reporting/budget roll-up only
- Documents can be inherited by dependent entities from their fiscal parent

### UI Features
- All index pages have Pagy pagination (25 items/page)
- Sortable column headers via `sortable_column_header` helper
- Entity index has Kind and Government Structure filter dropdowns
- "Needs research" indicators for missing governance data
- Verify Cockpit for observation data entry with PDF.js viewer

### Key Helpers & Patterns
- `ApplicationHelper#sortable_column_header` - reusable sortable headers
- `Model.sorted_by(column, direction)` - sorting scope pattern on all models
- `Document.for_entity(entity)` - includes parent entity documents

Always verify against uploaded code.
