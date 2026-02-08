# Plan

This file is used for active planning during Claude Code sessions. Cleared after work is merged.

## Active: FSMS Import (branch `feat/fsms-import`)

### Done
- [x] Explored Excel file structure (26 files, 2 methodology eras)
- [x] Added `roo` + `roo-xls` gems
- [x] Added `fsms: 7` to Metric data_source enum
- [x] Created metric_definitions.yml
- [x] Built FsmsImporter + rake tasks (fsms:import, fsms:import_year, fsms:preview)
- [x] Handled pre-2017 env scoring (row 5 "Indicator N" fallback)
- [x] Handled 2022 schools misnamed .xls (actually XLSX) via magic byte detection + temp copy
- [x] 28 tests, 160 assertions, 0 rubocop offenses (no suppressions)
- [x] Dry run: 172,283 observations, 0 errors
- [x] Updated CLAUDE.md

### Remaining
- [ ] Run `dce bin/rails fsms:import` to seed dev database
- [ ] Verify counts: check a known entity (e.g., Yonkers) has FSMS observations
- [ ] Create feature branch, commit all files, push, create PR
- [ ] After merge: deploy and run `fsms:import` in production

### Files changed
| File | Action |
|------|--------|
| `Gemfile` | Modified — added roo, roo-xls |
| `Gemfile.lock` | Modified — updated lockfile |
| `app/models/metric.rb` | Modified — added fsms: 7 to data_source enum |
| `lib/tasks/fsms_import.rake` | Created — FsmsImporter class + rake tasks |
| `db/seeds/fsms_data/metric_definitions.yml` | Created — metric definitions |
| `db/seeds/fsms_data/*.xls(x)` | 26 Excel files to commit (seed data) |
| `test/tasks/fsms_import_test.rb` | Created — 28 tests |
| `CLAUDE.md` | Modified — added FSMS completed section, rake tasks, data source |
| `PLAN.md` | Modified — active plan |
