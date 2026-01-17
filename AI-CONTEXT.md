# AI-CONTEXT.md
## Canonical Rules for AI Assistance on NY Benchmarking App

This file defines **how AI assistants must operate** on this project.
It is not a specification of the system; the code is authoritative.

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
4. **README.md (explanatory)**

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

## 2. Mandatory File Requirements

Before making or suggesting changes, the AI must confirm access to:
- `db/schema.rb`
- relevant model files
- relevant tests
- any CSVs or seed files being modified

If required files are missing or stale:
> Stop and request them. Do not infer.

---

## 3. Core Domain Invariants (High-Level Only)

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

## 4. Authentication & Authorization:

Authentication: Devise.

Authorization: All approved users have full read/write access to all resources (Entities, Metrics, Documents, Observations). There is currently no distinction between logged in "User" and "Admin."

---

## 5. Development & Git Workflow (Strict)

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
2. Write failing tests
3. Implement changes
4. Update fixtures/seeds
5. Run tests locally
6. Push branch
7. Open PR
8. CI must pass
9. Merge
10. Pull `main` locally
11. Deploy

AI instructions must respect this workflow.

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

## 6. Infrastructure & Security Invariants (Strict)

### Database Isolation
- The database container must **never** expose port 5432 to the host's public interface (`0.0.0.0`).
- Database access must occur via the internal Docker network or via SSH tunnel.

### Log Management
- All containers in `deploy.yml` must utilize the `json-file` logging driver with `max-size` and `max-file` limits to prevent disk exhaustion.

### User Context
- Deployment and operational scripts should target the `deploy` user, not `root`.

## 7. AI Output Expectations

AI responses should:
- Prefer full-file replacements (complete file contents) for any file that changes,
  unless the user explicitly asks for a diff.
- When only a small part of a file changes, also include a “drop-in snippet” option.
- Call out order-of-operations risks
- Avoid duplicating schema/model code into markdown
- Prefer correctness and auditability over brevity

When in doubt, ask.

---

## 8. Current Context Snapshot (Non-Authoritative)

- Entity governance modeling implemented via enums
- School districts are first-class entities
- Education metrics reassigned to school entities
- Fiscal parent relationships reflect reporting reality

Always verify against uploaded code.