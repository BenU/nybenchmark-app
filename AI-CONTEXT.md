# Project Context: New York Benchmarking App

## 1. Mission

A civic-tech data engine to extract and curate data from financial documents (ACFRs, Budgets) across all of New York State’s political entities, starting with its 62 cities, in order to verify, standardize, visualize, and analyze government efficiency and effectiveness with full auditability.  Ultimately the project will explore similar data from the 62 counties in New York as well as towns, villages and districts.

## 2. 🤖 AI Interaction Guidelines
When requesting code generation or debugging from AI assistants, strictly provide the following context files to ensure adherence to the project's domain and schema:

### For UI/View Tasks (e.g., "Create an Index Page"):
1. **AI-CONTEXT.md** (This file - for domain rules/mission)
2. **db/schema.rb** (Source of truth for database columns)
3. **config/routes.rb** (To understand current paths)
4. **Target Model(s)** (e.g., `app/models/metric.rb`)
5. **Target Fixtures** (e.g., `test/fixtures/metrics.yml`) - ensures tests use real data)
6. **Current/Failing Tests** (e.g., `test/models/metrics_test.rb`)

### For Logic/Backend Tasks:
1. **AI-CONTEXT.md**
2. **db/schema.rb** (Source of truth for database columns)
3. **Related Models** (including parents/children for associations)
4. **Existing Tests** (to prevent regression)

## 3. Tech Stack & Architecture
* **Framework:** Rails 8.1.1 (API + HTML hybrid)
* **Ruby:** 3.4.7
* **Database:** PostgreSQL 17 (Running via Docker in dev/prod)
* **Testing:** Minitest (Standard Rails 8 suite) with Fixtures.
* **Frontend:** Hotwire / standard Rails views / pico.css (Minimal CSS).
* **Storage:** DigitalOcean Spaces (S3-compatible).
    * **Integration:** Uses `aws-sdk-s3` gem via ActiveStorage.
    * **Constraint:** Docker containers are ephemeral. All user-uploaded files MUST use ActiveStorage (S3), never local disk.
    * **CDN:** Enabled (Asset delivery is proxied).

## 4. Development & Git Workflow (Strict)

### Branch and Commit Message Conventions
Use a prefix for both your branch name and commit message to categorize the change.

| Prefix     | Description                                           |
| :--------- | :---------------------------------------------------- |
| `feat`     | A new feature                                         |
| `fix`      | A bug fix                                             |
| `docs`     | Documentation changes                                 |
| `style`    | Code style changes (formatting, etc.)                 |
| `refactor` | Code changes that neither fix a bug nor add a feature |
| `test`     | Adding or correcting tests                            |
| `chore`    | Routine maintenance, dependency updates               |
| `ci`       | Changes to CI/CD workflow files                       |

**Example:**
* **Branch:** `git checkout -b feat/add-user-avatars`
* **Commit:** `git commit -m "feat: Add user profile avatars"`

### Workflow Constraints
- The `main` branch is protected; direct pushes are prohibited by GitHub Workflow.
- All changes must follow this sequence:
  1.  Create a branch from `main` following branch name guidelines from above.
  2.  Write failings tests for new feature if appropriate
  3.  Write appropriate code for desired change.
  4.  If tests exist, confirm that they are now passing and green.
  5.  Run linter and make appropriate changes if needed.
  6.  Push the branch to GitHub
  7.  All CI checks must pass
  8.  Merge the PR into `main`
  9.  Delete the remote branch
  10. `git pull origin main` locally
  11. Delete local branch
  12. Deploy changes to production
  13. Continue work

### Testing Strategy (Strict TDD)
1. **TDD First:** Write the failing test *before* implementation code.
2. **Fixtures:** Use Rails fixtures (`test/fixtures`) with semantic keys (e.g., `yonkers_acfr_2024`).
3. **Coverage:** Aim for high coverage of both happy paths, unhappy paths and edge cases.
4. **Command:** `bin/rails test` is the source of truth.

## Models & Domain Logic (Strict Rails Definition)

### Global Architecture:

* **Invariant:** Every persisted data point must be traceable to a source document and page reference.

* **Auditing:** All models below include \`has\_paper\_trail\` to track create/update/destroy events.

* **Database:** PostgreSQL.

* Note that the db/schema.rb and the models are the ultimate sources of truth for the database.  Point out any inconsistancies in those files and the information below before proceeding.  

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

* **Role:** A specific source file (PDF) or government website from a specific year.

* **Associations:**

    * `belongs_to :entity`

    * `has_many :observations, dependent: :destroy`

    * `has_one_attached :file` (Storage: DigitalOcean Spaces)

* **Validations:**

    * `validates :title, :doc_type, :fiscal_year, :source_url, presence: true`

    * `validates :doc_type, uniqueness: {
    scope: %i[entity_id fiscal_year],
    message: "already exists for this entity and year"
      }`

    * **Security:** File must be `application/pdf` and `< 20MB`.

* **Attributes:**

    * `title` (String): Human-readable name (e.g., "2024 Adopted Budget").

    * `doc_type` (String): Category of document.  Strict business domain types with supported types: `acfr, budget, school_budget, school_financials, demographics, public_safety, tax_return, tax_instructions`.

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

    * **Denormalization of Year:** `fiscal_year` is stored on the Observation for efficiency but MUST match `document.fiscal_year` (validated on save).

* **Attributes:**

    * `value_numeric` (Decimal): The raw number (e.g., `500000.00`). Used for graphing/stats.

    * `value_text` (Text): Qualitative data (e.g., "A+" or "Qualified Opinion") if a number isn't applicable.

    * `page_reference` (String): **Citation.** Where in the PDF this fact was found (e.g., "p. 42").

    * `fiscal_year` (Integer): Redundant storage of the year for faster queries (denormalized from Document).

    * `notes` (Text): Context about this specific data point (e.g., "Includes one-time grant").

## 6. Explicit Non-Goals
- Fully automated document ingestion or data extraction (Human verification is required).
- Unverified or uncited data points (Must have page references).
- Silent data transformations without traceable provenance.
- Optimizing for speed or scale at the expense of correctness.

## 7. Current Status
* **Production:** LIVE at `app.nybenchmark.org`.
* **Data:** Seeded preliminary data for Yonkers and New Rochelle.
* **Immediate Priority:** TDD and implementation of UI index/show pages for core models.