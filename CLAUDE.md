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

## Current Feature Work

### Verify Cockpit Refinements (Next Up)

The verify cockpit now has continuous scroll PDF viewing. Next steps are UI refinements.

**Key files:**
- `app/javascript/controllers/pdf_navigator_controller.js` - Stimulus controller with PDF.js logic
- `app/views/observations/verify.html.erb` - Verify cockpit view template
- `app/views/layouts/verify.html.erb` - Custom full-width layout for cockpit

**Current implementation (as of PR #91):**
- PDF.js via importmap CDN pins (see `config/importmap.rb`)
- Continuous scroll with virtualization (IntersectionObserver renders visible pages + 200px buffer)
- Bidirectional sync: scroll updates page display, page input/buttons scroll to target
- Click any page to capture that page number to form
- Toolbar: prev/next buttons, zoom dropdown, capture button
