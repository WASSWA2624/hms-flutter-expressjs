# Reports inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after code-traced inventory (2026-08-11).

## Residual

1. **No `AppTabStrip`** — panel navigation buried in Filters (`key: panel`); violates tabs.mdc primary strip + count rules.
2. **No authoritative tab counts / tones** — inactive panel workload invisible.
3. **No URL sync for panel/search/filters** — only `?dataset=`; no `section`/`panel` deep-link parity with Reception.
4. **Table Export ungated** — `AppListTable` defaults `enableExport`/`canExport` true; not `reportsExportRequirement` / `evidence:export`.
5. **No table Print** — `enablePrint` false; Print only in detail/domain dialogs.
6. **Date filter UI not wired** to `ReportsWorkspaceQuery.from`/`to` / `datePreset` despite labels and `_hasReportFilters` checking from/to.
7. **`query.trigger` unused** in UI Filters.
8. **Default 4 columns** (not prefer-5) — intentional in tests; still a tables.mdc exception.
9. **Empty allowed-panels** — no forbidden `AppFailureStateView` (Reception does).
10. **Pause/resume schedule** — inventory/controller only; omitted from chrome (`reportsDeleteRequirement` also unused).
11. **Page failure banner suppressed** — mutations clear `lastFailure` without workspace banner.
12. **Clear filters label** uses `opdClearFiltersAction` (shared) rather than a Reports-specific clear key.
13. **Domain Overview** forks UX (hides header/schedules/timeline; ModuleReporting nested tabs) — parallel chrome vs single desk strip.
