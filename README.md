# NY Benchmark

A civic-tech Rails application that benchmarks financial data across New York State's 62 cities using bulk data from the NYS Office of the State Comptroller (OSC) and U.S. Census Bureau.

- **Application:** https://app.nybenchmark.org
- **Project site / blog:** https://nybenchmark.org

---

## What It Does

- **City rankings** — Landing page ranks cities by Fund Balance %, Debt Service %, and Per-Capita Spending
- **Entity dashboards** — Each city has a page with hero stats, financial trend charts, top revenue/expenditure breakdowns, and governance info
- **Non-filer tracking** — Identifies cities that haven't filed with OSC, with amber badges and a dedicated filing compliance page
- **Data methodology** — Public-facing documentation of data sources, metric calculations, and known limitations
- **661K+ observations** — 31 years of financial data (1995-2024) for 57 filing cities, plus Census demographics for all 62

---

## Core Concepts

- **Entity** — A government body (city, town, school district). Governance structure (council-manager, strong mayor, etc.) lives only on Entity.
- **Document** — A source record (PDF, web URL, or bulk data import) tied to an entity and fiscal year.
- **Metric** — A standardized data definition with account code, data source, and category classification (e.g., `A31201` = Police - Personal Services, OSC expenditure).
- **Observation** — A single data value linking an Entity, Document, and Metric for a given fiscal year.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Ruby 3.4.7 |
| Framework | Rails 8.1.x |
| Database | PostgreSQL 14+ (Docker) |
| Authentication | Devise (no roles — all users have full access) |
| Frontend | Hotwire (Turbo + Stimulus), server-rendered views |
| CSS | Tailwind via `tailwindcss-rails` |
| Assets | Propshaft, JS via importmap (no Node build) |
| Charts | Chartkick + Chart.js |
| Auditing | PaperTrail (version tracking) |
| Background jobs | Solid Queue |
| Deployment | Kamal + Docker (Traefik reverse proxy) |
| Storage | DigitalOcean Spaces (S3-compatible) |
| Email | Brevo (SMTP) |
| Testing | Minitest + Capybara system tests |

---

## Getting Started

### Prerequisites

- Docker Desktop (running)
- Docker Compose v2+

> This repo uses a Docker-first workflow. You should not need to run `bundle install` on the host — gems are installed inside the web container and cached in a Docker volume.

### Clone the repository

```bash
git clone https://github.com/BenU/nybenchmark-app.git
cd nybenchmark-app
```

### Start the application

```bash
docker compose up --build
```

Once running:

- App: http://localhost:3000
- Mailpit inbox: http://localhost:8025

Leave this running in a terminal while developing.

### Database setup

The first time you run the stack (or after pulling new migrations):

```bash
docker compose exec web bin/rails db:prepare
```

### Stop the application

```bash
docker compose down
```

Do **not** use `docker compose down -v` unless you intentionally want to wipe the local database.

### Running commands in the container

All Rails commands should be run inside the Docker container:

```bash
docker compose exec web bin/rails test
docker compose exec web bin/rails c
docker compose exec web bin/rails db:migrate
docker compose exec web bin/ci          # Full CI suite (tests + Brakeman + RuboCop + bundle-audit)
```

### Updating gems

After pulling changes that update `Gemfile.lock`:

```bash
docker compose exec web bundle install
docker compose exec web bin/rails test
```

If native extensions break (or after a Ruby version change), wipe the cache volume and reinstall:

```bash
docker compose down
docker volume ls | grep bundle_cache
docker volume rm <project>_bundle_cache
docker compose up --build
```

Avoid running `bundle update` without gem names. Prefer merging Dependabot PRs or targeted `bundle update <gem>` when needed.

### Email in development

Emails are captured by **Mailpit** (not delivered externally). Open http://localhost:8025 to view them.

### Avoid running two servers

Do **not** run `bin/rails s` on the host at the same time as `docker compose up`. Use Docker Compose only for local development.

### Workflow aliases

These aliases cover the full development lifecycle:

```bash
# Lifecycle
alias dup="docker compose up --build"
alias ddown="docker compose down"

# Commands
alias dce="docker compose exec web"
alias dcr="docker compose exec web bin/rails"
alias dci="docker compose exec web bin/ci"

# Kamal
alias kd="kamal deploy"
alias klogs="kamal app logs -f"
alias kc="kamal app exec -i -- bin/rails c"
```

---

## Deployment

This application uses **Kamal** for zero-downtime deployments to a DigitalOcean Droplet.

See **[doc/ops.md](doc/ops.md)** for production operations, backups, and security procedures.

### Deployment prerequisites

Configure these in your local `.env` file (never committed):

| Variable | Purpose |
|----------|---------|
| `KAMAL_REGISTRY_PASSWORD` | GitHub PAT for pushing Docker images to `ghcr.io` |
| `DO_SPACES_KEY` / `DO_SPACES_SECRET` | DigitalOcean Spaces (PDF storage, sitemaps) |
| `BREVO_SMTP_USERNAME` / `BREVO_SMTP_PASSWORD` | Transactional email |
| `CENSUS_API_KEY` | US Census Bureau API (register at api.census.gov) |

### Deploy

```bash
kamal deploy    # or: kd
```

---

## Development Workflow

- **Branch from main:** `git switch -c feat/your-feature`
- **TDD:** Write failing tests first for behavior/logic changes
- **CI:** Run `dci` before pushing
- **PR:** Push branch and open PR via `gh pr create`
- **Merge:** On GitHub (main is protected)
- **Deploy:** `git switch main && git pull && dci && kd`

See **[CLAUDE.md](CLAUDE.md)** for detailed development context, domain rules, and project history.

---

## License

MIT License. See [LICENSE](LICENSE).
