 # NY Benchmarking App

A civic-tech Rails application for collecting, verifying, and benchmarking
financial and operational data from New York State local governments.

- Application: https://app.nybenchmark.org
- Project site / blog: https://nybenchmark.org

---

## Mission

A civic-tech data engine to extract and curate data from government financial
documents (ACFRs, budgets, audits, census, crime statistics) across New York
State, starting with cities and school districts.

The project prioritizes **correctness, transparency, and reproducibility**
over automation.

Every datapoint in the system must be explicitly traceable to:
- a specific government entity
- a source document
- a page or reference within that document

This traceability requirement is non-negotiable.

---

## Project Context

This repository contains the Rails application that powers the NY Benchmarking project.

High-level architecture, domain invariants, operating assumptions, and a
structured context for AI-assisted development are documented in:

👉 **[AI-CONTEXT.md](AI-CONTEXT.md)**

That file is authoritative for:
- domain invariants
- AI usage rules
- development workflow constraints

---

## Core Concepts (Conceptual Overview)

> **Note:** This section is descriptive.  
> The database schema, validations, and exact relationships are defined in the code
> (`db/schema.rb`, models, and tests) and may evolve over time.

- **Entity**  
  A government body (e.g., city, town, school district).

- **Document**  
  A source financial or statistical document (PDF or web source), tied to an
  entity and fiscal year.

- **Metric**  
  A standardized definition of a datapoint (e.g., total revenue, education expenses).

- **Observation**  
  A single extracted, citable fact linking an Entity, a Document, and a Metric.

Observations always include a citation back to the original source document.

Governance structure (e.g., strong mayor vs. council–manager) is modeled
**only on Entity**, never in observations.

---

## Entity Relationships (High-Level Semantics)

- Entities may have a **fiscal / reporting parent**
- This relationship represents **financial roll-up only**
- It does **not** represent geography or political containment

Examples:
- Yonkers Public Schools → fiscally dependent on Yonkers
- New Rochelle City School District → fiscally independent

Geographic or political containment is **not currently modeled** and is
expected to be handled via a separate, orthogonal relationship in the future.

---

## 🤖 AI Assistance Protocol (Important)

This project is actively developed using AI assistance.

Contributors who use AI tools are expected to:
1. Read `AI-CONTEXT.md`
2. Provide it to their AI assistant
3. Upload relevant schema, model, and test files when requesting changes

`AI-CONTEXT.md` defines:
- non-negotiable domain invariants
- git and workflow constraints
- conflict-handling expectations for AI reasoning

Changes that ignore these rules may be rejected or require rework.

---

## 🚀 Getting Started

### Prerequisites
- **Ruby:** 3.4.7
- **Rails:** 8.1.1
- **Docker:** Required locally (database services, Kamal builds) and in production
- **PostgreSQL:** 14+ (via Docker or local install)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/nybenchmark-app.git
   cd nybenchmark-app

3.  **Install Dependencies:**
    ```bash
    bundle install
    ```

4.  **Setup Database (The "Clean Slate" Method):**
    This project uses a strict **Composite Unique Index** on documents. To ensure data integrity during setup, use the reset command, which handles dropping, creating, migrating, and seeding automatically.
    ```bash
    bin/rails db:reset
    ```

5.  **Run the Test Suite:**
    Always ensure tests are green before developing.
    ```bash
    bin/rails test
    ```

6.  **Start the Server:**
    ```bash
    bin/dev
    ```
    Visit `http://localhost:3000`.

---

## 🚢 Deployment (Production)

This application uses **Kamal** for zero-downtime deployments to a DigitalOcean Droplet.

### 🔐 Deployment Prerequisites
To deploy this application via Kamal, you must configure the following in your local `.env` file (never commit this file):

**1. Container Registry (GitHub)**
* **Token:** GitHub Personal Access Token (Classic).
* **Scopes:** `write:packages`, `delete:packages`.
* **Variable:** `KAMAL_REGISTRY_PASSWORD`.
* **Purpose:** Authenticates Kamal to push Docker images to `ghcr.io`.

**2. Cloud Storage (DigitalOcean Spaces)**
* **Service:** S3-Compatible Object Storage (Region: `nyc3`).
* **Bucket:** `nybenchmark-production`.
* **Variables:** `DO_SPACES_KEY`, `DO_SPACES_SECRET`.
* **Purpose:** Persistent storage for user uploads (PDFs).

### Key Deployment Commands

* **Deploy New Code:**
    ```bash
    kamal deploy
    ```

* **Seed Production Data:**
    *Note: Deployment does not auto-seed. You must run this manually if you change `seeds.rb`.*
    ```bash
    kamal app exec -i -- bin/rails db:seed
    ```

* **Remote Console (Debugging):**
    ```bash
    kamal app exec -i -- bin/rails c
    ```

## License

MIT License. See [LICENSE](LICENSE).