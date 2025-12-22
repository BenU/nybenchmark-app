# New York Benchmarking App

**Data collection, validation, and analysis engine for the New York Benchmarking Project.**

This is the backend Rails application for the [NY Benchmarking Project](https://github.com/yourusername/nybenchmark-website). It is designed to ingest financial documents (ACFRs, Budgets), extract standardized metrics, and provide a rigid audit trail to ensure data integrity.

## Prerequisites
* **Ruby:** 3.4.7
* **Docker:** Required for the database.
* **PostgreSQL:** Version 17 (Running via Docker).

## Getting Started

### 1. Database Setup (Docker)
**You must start Docker every time you restart your computer.**

1.  Open **Docker Desktop**.
2.  Run the following command in the project root:
    ```bash
    docker compose up -d
    ```
    *This starts the database on port `5433`.*

### 2. Application Setup
Once the database is running:
```bash
bundle install
bin/rails db:prepare
bin/rails test

## License

MIT License. See [LICENSE](LICENSE).