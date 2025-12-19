# NY Benchmarking App

A civic-tech Rails application for collecting, verifying, and analyzing financial data from New York State local governments.

## Mission

**Mission:** A civic-tech data engine to extract and curate data from financial documents (ACFRs, Budgets) across New York State’s 62 cities, in order to verify, standardize, visualize, and analyze government efficiency and effectiveness with full auditability.

This project prioritizes correctness, transparency, and reproducibility over automation. Every data point is explicitly traceable back to its original source document and page reference.

## Project Context

This repository contains the Rails application that powers the NY Benchmarking project.

- Static site / blog: https://nybenchmark.org  
- Application: https://app.nybenchmark.org

High-level architecture, domain modeling decisions, operating assumptions, and a structured AI context used to support accurate and efficient AI-assisted development are documented in:

👉 **[AI Context](AI-CONTEXT.md)**

## Core Concepts

- **Entities** represent government bodies (e.g., cities).
- **Documents** are source financial files (PDFs) tied to a fiscal year.
- **Metrics** define standardized data points.
- **Observations** are individual, citable facts extracted from documents.

Observations form the intersection of Entity + Document + Metric and always include a citation to the original source.

## Status

- Core domain models implemented with validations
- Production deployment live
- Preliminary data seeded for select cities
- Styling intentionally minimal

**Near-term priorities**
- Index and show pages for core models
- TDD of document archiving workflows
- Improved data-entry and validation tooling

## Development

- Rails 8 (API + HTML hybrid)
- PostgreSQL
- Hotwire for frontend interactions
- Minitest with strict TDD discipline

See **[AI Context](AI-CONTEXT.md)** 
for detailed architectural notes, design constraints, and testing philosophy.

## License

MIT License. See [LICENSE](LICENSE).