# EV Grant Sprint — Status

Branch: `feat/ev-grant-sprint` (all changes uncommitted, no commits yet)

Goal: Prepare app for Emergent Ventures grant application. Navbar cleanup, methodology page, non-filer highlights.

---

## COMPLETED

### 1. Navbar Cleanup
- **`app/views/shared/_navbar.html.erb`** — Public nav: NY Benchmark | Cities | Methodology | Blog. Documents/Metrics behind auth only. Verify Queue removed from nav entirely.
- **`app/views/shared/_footer.html.erb`** — Added Documents, Metrics, Methodology links.
- **`test/integration/site_navigation_test.rb`** — Updated for new nav structure.
- **`test/system/authentication_nav_test.rb`** — Updated (removed Verify Queue tests, added admin link visibility tests).

### 2. PagesController + Routes
- **`app/controllers/pages_controller.rb`** — NEW. Actions: `methodology`, `non_filers`.
- **`config/routes.rb`** — Added `get "methodology" => "pages#methodology"` and `get "non-filers" => "pages#non_filers"`.
- **`test/controllers/pages_controller_test.rb`** — NEW. Tests for both pages (200 status, content assertions, not noindex).

### 3. Methodology Page
- **`app/views/pages/methodology.html.erb`** — NEW. Full content: Data Sources (61 cities via OSC, 62 via Census, NYC planned), How Metrics Are Calculated (Fund Balance %, Debt Service %, Per-Capita Spending, all-fund approach, T-fund exclusion, interfund transfers), Known Limitations, Open Source.

### 4. FilingStatus Concern
- **`app/models/concerns/filing_status.rb`** — NEW. Instance methods: `last_osc_filing_year`, `osc_missing_years(range)`, `osc_filing_rate(range)`. Class methods: `Entity.latest_majority_year`, `Entity.filing_report(as_of_year)`. Three categories: chronic (3+ years behind), recent_lapse (1-2 years), sporadic (<80% 10-year filing rate).
- **`app/models/entity.rb`** — Added `include FilingStatus`.
- **`test/models/filing_status_test.rb`** — NEW. 10 tests covering all methods and categorization.

### 5. Non-Filer Page
- **`app/views/pages/non_filers.html.erb`** — NEW. Filing compliance page with Mount Vernon case study, tables grouped by chronic/recent_lapse/sporadic, filing rates, link to methodology.

### 6. Entity Show — Non-Filer Banner + Missing Years
- **`app/views/entities/show.html.erb`** — Amber warning banner between header and hero stats for chronic/recent_lapse entities. Single "Amber bands indicate years with no data filed: ..." note in Financial Trends section. All trend card renders pass `missing_years: @missing_osc_years`.
- **`app/controllers/entities_controller.rb`** — Added `load_filing_status` private method (computes `@filing_category`, `@last_osc_year`, `@missing_osc_years`, `@latest_majority_year`). Added `load_non_filer_ids` for index action.

### 7. Trend Card — Chart.js Annotation Config
- **`app/views/entities/_trend_card.html.erb`** — Rewritten to accept `missing_years` local, build Chart.js annotation plugin box annotations (amber rectangles) for each missing year, fill nil values for gaps in chart data, pass annotations through chartkick's `library` option.

### 8. Landing Page + Entity Index
- **`app/views/welcome/index.html.erb`** — Added non-filer callout: "{N} cities are not included in these rankings..." with link to /non-filers.
- **`app/controllers/concerns/city_rankings.rb`** — Exposed `@non_filer_count`.
- **`app/views/entities/index.html.erb`** — Amber "Late" badge next to non-filer city names.
- **`app/controllers/entities_controller.rb`** — `load_non_filer_ids` precomputes non-filer ID set (no N+1).
- **`test/controllers/entities_controller_test.rb`** — Added non-filer banner and Late badge tests.
- **`test/controllers/welcome_controller_test.rb`** — Added non-filer callout test.

### 9. CSS
- **`app/assets/stylesheets/application.css`** — Added: `.non-filer-banner`, `.non-filer-callout`, `.trend-missing-years`, `.non-filer-badge`.

### 10. Sitemap + CLAUDE.md
- **`config/sitemap.rb`** — Added methodology and non-filers pages.
- **`CLAUDE.md`** — Updated testing guidance, CSS documentation.

---

## REMAINING — Chart.js Annotation Plugin Loading (THE BLOCKER)

The annotation plugin config is correctly built in `_trend_card.html.erb` and passed to chartkick via `library` option. BUT the annotation plugin itself isn't loading/registering with Chart.js properly.

### Problem
- Chartkick loads Chart.js via importmap (`import "Chart.bundle"` in `application.js`). This is an ES module that sets `window.Chart` when loaded.
- The chartjs-plugin-annotation UMD build (`chartjs-plugin-annotation.min.js`) needs `window.Chart` and `window.Chart.helpers` at **parse time** (in its IIFE factory).
- ES module scripts (`<script type="module">`) execute AFTER classic `<script defer>` scripts, so a `<script defer src="annotation.min.js">` runs before `window.Chart` exists.

### Current state of `_head.html.erb`
The annotation plugin script tags were just REMOVED (they didn't work due to the timing issue above). Only `<%= javascript_importmap_tags %>` remains.

### Solution: Dynamic script loading in application.js
Load the annotation plugin dynamically AFTER Chart.bundle import, when `window.Chart` is guaranteed to exist:

```javascript
// app/javascript/application.js
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

// Dynamically load annotation plugin after Chart.js is on window
const script = document.createElement("script")
script.src = "https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.1.0/dist/chartjs-plugin-annotation.min.js"
script.onload = () => {
  if (window.Chart && window["chartjs-plugin-annotation"]) {
    window.Chart.register(window["chartjs-plugin-annotation"])
  }
}
document.head.appendChild(script)
```

**Potential timing concern:** If chartkick renders charts before the dynamic script loads, annotations won't appear on the initial page load. BUT on Turbo navigations (which is how most users browse entity pages), charts re-render after the plugin is already loaded. Test this — if initial page load is a problem, may need to defer chartkick rendering or re-render charts after plugin loads.

---

## REMAINING — After Plugin Fix

1. **Run `dci`** — Full CI suite to verify all tests pass
2. **Manual verification:**
   - Mount Vernon entity page: amber banner + amber rectangles on trend charts for missing years
   - Albany entity page: no banner, no rectangles
   - Landing page: non-filer callout with count
   - Entity index: "Late" badge on Mount Vernon, Ithaca, Rensselaer, Fulton
   - `/methodology` — all sections render
   - `/non-filers` — filing compliance table with categories
   - Navbar: Cities, Methodology, Blog visible; Documents/Metrics only when signed in
3. **Commit all changes** on `feat/ev-grant-sprint`
4. **Push and create PR**
5. **Add automated data refresh TODO to CLAUDE.md** (cron via solid_queue — per plan)

---

## FILES CHANGED (all uncommitted)

### New files:
- `app/controllers/pages_controller.rb`
- `app/models/concerns/filing_status.rb`
- `app/views/pages/methodology.html.erb`
- `app/views/pages/non_filers.html.erb`
- `test/controllers/pages_controller_test.rb`
- `test/models/filing_status_test.rb`

### Modified files:
- `CLAUDE.md`
- `app/assets/stylesheets/application.css`
- `app/controllers/concerns/city_rankings.rb`
- `app/controllers/entities_controller.rb`
- `app/models/entity.rb`
- `app/views/entities/_trend_card.html.erb`
- `app/views/entities/index.html.erb`
- `app/views/entities/show.html.erb`
- `app/views/shared/_footer.html.erb`
- `app/views/shared/_navbar.html.erb`
- `app/views/welcome/index.html.erb`
- `config/routes.rb`
- `config/sitemap.rb`
- `test/controllers/entities_controller_test.rb`
- `test/controllers/welcome_controller_test.rb`
- `test/integration/site_navigation_test.rb`
- `test/system/authentication_nav_test.rb`
