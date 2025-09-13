# Scout UI Backlog (Sweep of Submodules)

**Purpose:** Track features implemented elsewhere (submodules, prototypes, sibling apps) that are not yet in `PRD-SCOUT-UI-v6.0` but are candidates for inclusion.

> 📋 **Source of truth file:** `docs/PRD/backlog/SCOUT_UI_BACKLOG.yml`

---

## A) Candidate Items (Curated Starter Set)

### 🎯 High Priority

**1) Predictive Metrics (Forecasts)** `SCOUT-BL-001`
- **Source:** ops/analytics → ForecastChart component
- **UI Target:** Overview → Revenue Trend toggle (forecast on/off)
- **RPCs:** `scout_forecast_revenue`, `scout_forecast_share`
- **Effort:** 3-5 days
- **Notes:** Display cone of uncertainty; CI perf & a11y compliance.

**2) Smart Alerts & Subscriptions** `SCOUT-BL-004`
- **Source:** notifications/alerts → AlertsManager component
- **UI Target:** Overview → Bell icon on KPI row; per-card "Create alert"
- **RPCs:** `alerts_create`, `alerts_list`, `alerts_trigger`
- **Effort:** 5-7 days
- **Notes:** Threshold & anomaly modes; email/slack integration.

### 📊 Medium Priority

**3) Saved Queries + History/Share** `SCOUT-BL-002`
- **Source:** command-center → SavedQueryBar component
- **UI Target:** AI tab – top strip (load/run/save/share)
- **RPCs:** `saved_queries_list`, `saved_queries_run`
- **Effort:** 2-3 days
- **Notes:** "Copy link w/ filters" and "pin to sidebar" functionality.

**4) Insight Templates (Reusable prompts)** `SCOUT-BL-003`
- **Source:** advisor/suqi → retail analysis templates
- **UI Target:** AI tab – "Templates" drawer (price sensitivity, substitution, geo expansion)
- **RPCs:** `insight_templates_list` (needs implementation)
- **Effort:** 1-2 days
- **Notes:** Publish template JSON in repo; link to MCP.

**5) Exports & Scheduled Reports** `SCOUT-BL-005`
- **Source:** reporting → ExportManager component
- **UI Target:** Card footer "Export" (PNG/CSV) + "Schedule"
- **RPCs:** `report_create`, `export_sign_url`, `schedule_report`
- **Effort:** 4-6 days
- **Notes:** Add loading/disabled state when RLS blocks.

**6) Dark Mode & Theming** `SCOUT-BL-009`
- **Source:** theme-lab → ThemeProvider system
- **UI Target:** Global toggle with system preference detection
- **RPCs:** N/A (frontend only)
- **Effort:** 3-4 days
- **Notes:** Ensure Code Connect mappings document theme tokens.

### 🔬 Low Priority / Advanced

**7) Geo Hexbin (Advanced visualization)** `SCOUT-BL-006`
- **Source:** geo-labs → HexbinMap component
- **UI Target:** Geography tab – toggle { choropleth | hexbin }
- **RPCs:** `scout_geo_hexbin`
- **Effort:** 6-8 days
- **Notes:** Feature flag `GEO_HEXBIN=1` (CI ensures off by default).

**8) Cohorts & AB-Testing Overlays** `SCOUT-BL-007`
- **Source:** experiments → CohortAnalysis, ABTestOverlay
- **UI Target:** Mix + Competitive tabs → treatment/control ribbons
- **RPCs:** `scout_cohort_perf`, `scout_ab_test_summary`
- **Effort:** 4-5 days
- **Notes:** Overlay ribbons; tooltips w/ CI.

**9) Design System Analytics Panel** `SCOUT-BL-008`
- **Source:** creative-studio → ComponentUsage tracker
- **UI Target:** AI tab sub-panel or About section
- **RPCs:** `design_system_usage`
- **Effort:** 1-2 days
- **Notes:** Usage of UI kit components; helps governance.

**10) Localization (en-PH, en-US)** `SCOUT-BL-010`
- **Source:** intl → LocaleProvider, formatters
- **UI Target:** Global settings menu → locale selector
- **RPCs:** N/A (frontend formatting)
- **Effort:** 4-5 days
- **Notes:** Currency/number/date format; CI snapshot per locale.

---

## B) Backlog Management Process

### ➕ Adding New Items
1. **Evidence Collection:** Run backlog sweep to find candidates
2. **Item Creation:** Add entry to `SCOUT_UI_BACKLOG.yml` with:
   - Unique ID (`SCOUT-BL-XXX`)
   - Source module and file references
   - UI target location specification
   - RPC contract requirements
   - Effort estimate and complexity
3. **Validation:** Ensure contracts exist or are properly marked as needed

### 🚀 Promoting to Release
When ready to implement a backlog item:
1. **Move to PRD:** Transfer from Backlog → PRD Functional Requirements
2. **Contracts:** Add/verify contracts in `packages/contracts`
3. **Implementation:** Add UI story, tests, Code Connect mapping
4. **Documentation:** Update `CHANGELOG.md` and bump PRD version

### 📊 Status Tracking
- **Proposed:** Initial candidate, needs validation
- **In Review:** Technical review in progress
- **Blocked:** Dependencies or decisions pending
- **Ready:** Approved for next release cycle

---

## C) Automation & Evidence Capture

### 🔍 Backlog Sweep Command
Run this from repo root to discover new candidates:

```bash
# Create sweep directory
mkdir -p .backlog_sweep

# Search for feature candidates
find apps packages modules infra supabase scripts -name "*.ts" -o -name "*.tsx" \
  | grep -v node_modules \
  | xargs grep -l -E 'forecast|predict|dashboard|chart|analytics|export|alert|schedule' \
  > .backlog_sweep/component_candidates.txt

# Search for TODO/backlog annotations
grep -r -n --include="*.ts" --include="*.tsx" --exclude-dir="node_modules" \
  -E 'TODO|FIXME|@backlog|@feature' apps/ packages/ \
  | sed 's/^/HIT: /' > .backlog_sweep/raw_hits.txt

# Summarize findings
cut -d: -f1 .backlog_sweep/raw_hits.txt | sort | uniq -c | sort -nr > .backlog_sweep/by_path.txt

echo "=== Top paths ===" && head -n 20 .backlog_sweep/by_path.txt
echo "=== Sample hits ===" && head -n 30 .backlog_sweep/raw_hits.txt
```

### 📝 Evidence Artifacts
Saved under `.backlog_sweep/`:
- `raw_hits.txt` – grep hits (TODO, @backlog, feature flags)
- `component_candidates.txt` – Components likely useful in dashboard UI
- `by_path.txt` – Hit counts by file path

### 🔄 CI Integration (Optional)
Add a light check that fails if a PR touches a candidate source path without referencing an item ID in the PR body—keeps backlog & changes aligned.

---

## D) GitHub Issues Integration (Optional)

To convert backlog items into GitHub issues:

```bash
# Requires GitHub CLI: brew install gh && gh auth login

# Extract item IDs
yq '.[].id' docs/PRD/backlog/SCOUT_UI_BACKLOG.yml > /tmp/ids.txt

# Create issues for each backlog item
while IFS= read -r ID; do
  TITLE=$(yq ".[] | select(.id==\"$ID\") | .title" docs/PRD/backlog/SCOUT_UI_BACKLOG.yml)
  BODY=$(yq ".[] | select(.id==\"$ID\")" docs/PRD/backlog/SCOUT_UI_BACKLOG.yml)
  echo "$BODY" | gh issue create \
    --title "$ID: $TITLE" \
    --label "backlog,scout-ui,needs-triage" \
    --body-file -
done < /tmp/ids.txt
```

---

## E) Integration with Main PRD

Reference this backlog at the end of your main `PRD-SCOUT-UI-v6.0.md`:

```markdown
## 15) Backlog Features

Features implemented elsewhere but not yet included in this release.

> 📋 See complete backlog: [Scout UI Backlog](SCOUT_UI_BACKLOG.md)

**Next Release Candidates:**
- Predictive Metrics (SCOUT-BL-001) - High priority
- Smart Alerts (SCOUT-BL-004) - High priority  
- Saved Queries (SCOUT-BL-002) - Medium priority

Total backlog items: 10 | Ready for implementation: 2 | In review: 2
```

---

## Summary

This backlog system provides:

✅ **Single source of truth** for features living in submodules  
✅ **Repeatable discovery** process to avoid losing features  
✅ **Clear promotion workflow** from backlog → PRD → implementation  
✅ **Evidence-based tracking** with file references and contracts  
✅ **CI-friendly format** for validation and automation  
✅ **Optional GitHub integration** for project management  

The system ensures that valuable features developed in sibling apps, prototypes, or experiments don't get lost and can be systematically incorporated into the main Scout Dashboard when ready.