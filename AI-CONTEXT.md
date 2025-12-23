# Project Context: New York Benchmarking App

## Mission:

A civic-tech data engine to extract and curate data from financial documents (ACFRs, Budgets) across New York State’s 62 cities, in order to verify, standardize, visualize, and analyze government efficiency and effectiveness with full auditability.

## How This Document Is Used

This document serves as a shared source of truth for both human contributors and AI-assisted development. It is intended to provide sufficient architectural, domain, and process context so that AI tools can offer accurate, conservative, and workflow-compliant guidance when helping build and maintain this project.

## Workflow Constraints

- The `main` branch is protected; direct pushes are not allowed.
- All changes must follow this sequence:
  1. Create a feature or chore branch from `main`
  2. Push the branch to GitHub
  3. All CI checks must pass on GitHub
  4. Merge the PR into `main` on GitHub
  5. Delete the remote branch
  6. Run `git pull origin main` locally to sync

## Explicit Non-Goals

- Fully automated document ingestion or data extraction
- Unverified or uncited data points
- Silent data transformations without traceable provenance
- Optimizing for speed or scale at the expense of correctness

## Tech Stack:

* **Framework:** Rails 8.1.1 (API \+ HTML hybrid)  
* **Ruby:** 3.4.7  
* **Database:** PostgreSQL 17 (Running via Docker in dev/prod)  
* **Testing:** Minitest (Standard Rails 8 suite) with Fixtures  
* **Frontend:** Hotwire / standard Rails views (Minimal CSS currently)  
* **Background Jobs:** Solid Queue (Rails 8 default)

## Infrastructure & Deployment:

* **Host:** DigitalOcean Droplet (Ubuntu/Docker) \+ DigitalOcean Spaces (S3-compatible object storage)  
* **Deployment:** Kamal 2 (Deploying from local Mac to DO Droplet)  
* **DNS/CDN:** Cloudflare (Proxied/Orange Cloud enabled)  
* **Domains:**  
  * `nybenchmark.org` (Jekyll Static Site \- Hosted on GitHub Pages)  
  * `app.nybenchmark.org` (Rails Application \- Hosted on DO)

## Models & Domain Logic (Strict Rails Definition)

### Global Architecture:

* **Invariant:** Every persisted data point must be traceable to a source document and page reference.

* **Auditing:** All models below include \`has\_paper\_trail\` to track create/update/destroy events.

* **Database:** PostgreSQL.

### 1\. Entity (\`app/models/entity.rb\`)

* **Role:** The root parent object representing a government body.

* **Associations:**

    * `has_many :documents, dependent: :destroy` (Cascades deletion)

    * `has_many :observations, dependent: :destroy` (Cascades deletion)

* **Validations:**

    * `validates :name, presence: true`

    * `validates :slug, presence: true, uniqueness: true`

* **Attributes:**

    * `name` (String): Common name (e.g., "Albany").

    * `slug` (String): **URL Identifier.** A unique, URL-safe version of the name (e.g., `albany-ny`). Used for routing `entities/:slug`.

    * `kind` (String): The type of entity (Default: 'city'). Future-proofing for counties/states.

    * `state` (String): 2-letter state code (Default: 'NY').

### 2\. Document (\`app/models/document.rb\`)

* **Role:** A specific source file (PDF) from a specific year.

* **Associations:**

    * `belongs_to :entity`

    * `has_many :observations, dependent: :destroy`

    * `has_one_attached :file` (Storage: DigitalOcean Spaces)

* **Validations:**

    * `validates :title, :doc_type, :fiscal_year, :source_url, presence: true`

    * **Security:** File must be `application/pdf` and `< 20MB`.

* **Attributes:**

    * `title` (String): Human-readable name (e.g., "2024 Adopted Budget").

    * `doc_type` (String): Category of document (e.g., `budget`, `acfr`, `audit`).

    * `fiscal_year` (Integer): The financial year this document covers (YYYY).

    * `source_url` (Text): **Reference.** The original URL where the file was found. Kept for lineage/backup even after upload.

    * `notes` (Text): Internal team notes about the document quality/source.

### 3\. Metric (\`app/models/metric.rb\`)

* **Role:** The standard definition of a data point we want to extract.

* **Associations:**

    * `has_many :observations, dependent: :restrict_with_error`

    * *Note:* Cannot delete a metric if data points are using it.

* **Validations:**

    * `validates :key, presence: true, uniqueness: true`

    * `validates :label, presence: true`

* **Attributes:**

    * `key` (String): **Code Identifier.** Immutable, snake_case ID (e.g., `total_revenue`). Used for code lookups, API keys, and matching.

    * `label` (String): **Display Name.** Human-readable title (e.g., "Total Revenue"). Can change without breaking code.

    * `unit` (String): Measurement unit (e.g., "USD", "Count", "FTE").

    * `description` (Text): Help text explaining exactly what this metric measures (for tooltips/documentation).

### 4\. Observation (\`app/models/observation.rb\`)

* **Role:** A single fact extracted from a document. The intersection of Entity \+ Document \+ Metric.

* **Associations:**

    * `belongs_to :entity`

    * `belongs_to :document`

    * `belongs_to :metric`

* **Validations:**

    * `validates :fiscal_year, :page_reference, presence: true`

    * **XOR Logic:** Must have either `value_numeric` OR `value_text`. Both cannot be blank.

* **Attributes:**

    * `value_numeric` (Decimal): The raw number (e.g., `500000.00`). Used for graphing/stats.

    * `value_text` (Text): Qualitative data (e.g., "A+" or "Qualified Opinion") if a number isn't applicable.

    * `page_reference` (String): **Citation.** Where in the PDF this fact was found (e.g., "p. 42").

    * `fiscal_year` (Integer): Redundant storage of the year for faster queries (denormalized from Document).

    * `notes` (Text): Context about this specific data point (e.g., "Includes one-time grant").

## Testing & Quality Assurance (Strict TDD)

### Framework: Minitest (Standard Rails)

### Philosophy: Test-Driven Development (Red-Green-Refactor)

1.  **TDD First:** Before writing any implementation code, you must propose or write the failing test case.

    * Do not generate implementation code until the test strategy is agreed upon.

2.  **Test Types:**

    * **Unit/Model Tests:** Required for all data integrity rules (validations), scopes, and methods. Use standard `assert` and `assert_not`.

    * **System Tests:** Required for all user-facing features (CRUD actions). Use `ApplicationSystemTestCase`.

3\.  **Fixtures:** Use Rails standard Fixtures (\`test/fixtures\`) for sample data. Avoid FactoryBot to keep dependencies low for open source contributors unless requested otherwise.

4\.  **Coverage:** Aim for high test coverage. We value "happy paths" (everything works) and "sad paths" (handling errors/edge cases).

5\.  **Output:** When providing code, always include the verification command (e.g., \`bin/rails test test/models/user\_test.rb\`).

**Goal:** The test suite is the source of truth. If the tests pass, the PR is mergeable.

## Infrastructure & Authentication Details

### Container Registry Authentication (GitHub)

* **Component: GitHub Personal Access Token (Classic).**  
* **Purpose: Authenticates the Kamal deployment tool with the GitHub Container Registry (`ghcr.io`).**  
* **Scopes: `write:packages`, `delete:packages` (Required to push/pull Docker images).**  
* **Management: The token is stored locally in `.env` as `KAMAL_REGISTRY_PASSWORD`. It is never committed to Git. Kamal injects it into the build process securely.**  
### Cloud Storage (DigitalOcean Spaces)
* **Service: DigitalOcean Spaces (S3-Compatible Object Storage).**  
* **Bucket Name: `nybenchmark-production` (Region: `nyc3`).**  
* **Purpose: Persistent storage for user-uploaded files (PDFs). Since Docker containers are ephemeral (files inside them vanish on restart), all `ActiveStorage` attachments are offloaded here.**  
* **Configuration:**  
  * **CDN: Enabled (for fast global delivery via edge caching).**  
  * **Access: A dedicated "Limited Access" key pair (`DO_SPACES_KEY` / `DO_SPACES_SECRET`) handles Read/Write/Delete permissions solely for this bucket.**  
  * **Integration: Rails uses the `aws-sdk-s3` gem to communicate with the Space via `config/storage.yml`.**

## Current Status:

* Production is LIVE (`kamal deploy` working).  
* Core models and validations are tested.  
* Cloudflare RUM analytics enabled.  
* rudimentary css styling with pico.css CDN link  
* Seeded preliminary data for Yonkers and New Rochelle  
* **Next Priority:** TDD and implimentation of UI of index and show pages for the models and current observations
