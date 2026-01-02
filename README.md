 NY Benchmarking App

A civic-tech Rails application for collecting, verifying, and analyzing financial data from New York State local governments.

## Mission

**Mission:** A civic-tech data engine to extract and curate data from financial documents (ACFRs, Budgets) across New York State’s 62 cities, in order to verify, standardize, visualize, and analyze government efficiency and effectiveness with full auditability for the data acquisition process and improved accountability for governments.

This project prioritizes correctness, transparency, and reproducibility over automation. Every data point is explicitly traceable back to its original source document and page reference.

## Project Context

This repository contains the Rails application that powers the NY Benchmarking project.

- Static site / blog: https://nybenchmark.org
- Application: https://app.nybenchmark.org

High-level architecture, domain modeling decisions, operating assumptions, and a structured AI context used to support accurate and efficient AI-assisted development are documented in:

👉 **[AI Context](AI-CONTEXT.md)**

## Core Concepts

- **Entities** represent government bodies (e.g., cities).
- **Documents** are source financial files (PDFs) or government websites tied to a fiscal year.
- **Metrics** define standardized data points.
- **Observations** are individual, citable specific metric facts extracted from documents for a particular entity.

Observations form the intersection of Entity + Document + Metric and always include a citation to the original source.

## Status

- Core domain models implemented with validations
- Production deployment live
- Preliminary data seeded for select cities
- Styling intentionally minimal with pico.css

A Rails 8.1 application designed to provide transparency and benchmarking for New York local government data (Budgets, ACFRs, Census, Crime stats). The goal is "Efficiency and Effectiveness" through auditable, comparable data.

## 🚀 Getting Started

### Prerequisites
* **Ruby:** 3.4.7
* **Rails:** 8.1.1
* **Docker:** Required locally (for database services/Kamal builds) and in production.
* **PostgreSQL:** 14+ (Run via Docker or locally).

### Local Development Setup
1.  **Clone the repo:**
    ```bash
    git clone [https://github.com/yourusername/nybenchmark-app.git](https://github.com/yourusername/nybenchmark-app.git)
    cd nybenchmark-app
    ```

2.  **Start Docker:**
    Ensure your Docker Desktop (or engine) is running. The application relies on it for database services and building production images.

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

### Data Integrity Note
The database enforces uniqueness on `[:entity_id, :fiscal_year, :doc_type]`.
* **Document Types** are strict business domains (e.g., `acfr`, `budget`, `public_safety`, `demographics`), NOT file formats.
* If you encounter a `PG::UniqueViolation` during seed/deploy, it means you have duplicate source data (e.g., two "Budget" documents for Yonkers in 2024).

## 🛠 Tech Stack
* **Framework:** Ruby on Rails 8.1
* **Database:** PostgreSQL
* **Testing:** Minitest (Standard Rails)
* **Styling:** pico.css
* **Hosting:** DigitalOcean (via Kamal)

**Near-term priorities**
- Index and show pages for core models
- TDD of document archiving workflows

## License

MIT License. See [LICENSE](LICENSE).