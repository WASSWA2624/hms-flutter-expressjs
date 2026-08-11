# Reports tab — Overview

## 1. Tab strip

- Label: `reportsPanelOverview`
- Icon: `Icons.space_dashboard_outlined`
- Count source: **n/a** (no strip counts); Overview metrics from `overview.summary` (ids e.g. `definitions`, `runs_queued`, `schedules_due`, `widgets_pinned`, `kpi_critical`, `activity_24h`)
- Count tone: n/a (metric tones via `reportsSummaryCardTone`)
- Deep-link panel query: **none** (only `?dataset=` may jump to Catalog)
- Tab gate: `reportsCatalogReadRequirement` + tailored pack includes `overview`
- **Omitted when unauthorized** (not disabled)

## 2. Search / Filters / Settings / Export / Print / context

- Non-domain: standalone `AppSearchBar` — Filters with **panel-only** group; `enableDateFilter: false`; no Settings/Export/Print
- Domain (pharmacy / owned packs): workspace search chrome **hidden**; nested Module Reporting search (`reportsPharmacyReportingSearch*` / domain labels) + domain Filters
- Context actions: `reportsOverviewBrowseCatalogAction`, `reportsOverviewViewDeliveryAction`, `reportsOverviewCreateReportAction` (create needs `canWriteReports` + catalog panel)

## 3. Table / panel

- Not a worklist: `ReportsOverviewDashboard` → KPIs, priority queues, charts; optional dataset chips
- Domain: `ReportsPharmacyDomainGroups` or `ReportsOwnedDomainReportingHost` — Reporting/Analytics nested tabs (`ModuleReportingDomainTabs`)
- Schedules sibling + timeline **suppressed** under domain Overview

## 4. Advanced filters / search fields

- Infra Overview: panel filter only (`reportsPanelFilterLabel`, allLabel `reportsPanelOverview`)
- Domain Reporting shell: category / subcategory / content-kind / period (pharmacy/domain label keys)

## 5. Primary / secondary / row actions

- Metric/queue taps → `applyPanel` (or in-place shortcut dialogs for pharmacy catalog/delivery/dataset)
- Dataset chip → `openCatalogDataset` / shortcut dialog
- Create report → navigate Catalog (+ optional callback)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Overview shortcut list (`openReportsOverviewShortcutDialog`) | Reports-owned |
| Report detail from shortcut | Reports-owned `openReportDetailDialog` |
| Pharmacy/domain report (`openPharmacyReportingReportDialog` / module dialog) | Wrapper → **reused** `ModuleReportingReportDialog` |

## 7. Nested / follow-on

- Shortcut item → report detail → Run/Schedule/Print/Download…
- Domain report → period/export/print-preview nested in module kit; filters dialog `openPharmacyReportingFiltersDialog` → **reused** module filters

## 8. Forms (summary)

- Domain period custom range / export format forms (module kit)
- No run/schedule forms until detail path

## 9. Print / labels / preview

- Domain: Print available; Export gated `canExportEvidence` (+ controlled log for `regulatory_log`)
- Infra Overview: no table print/export

## 10. Loading / empty / error / success

- Loading: `reportsLoadingTitle` / `reportsLoadingBody`
- Empty: `reportsOverviewEmptyTitle` / `reportsOverviewEmptyBody`
- Shortcut empty/loading: same + `reportsOverviewEmpty*`
- Domain: `reportsPharmacyReportingLoading*|Error*|Empty*|Unavailable*` (and domain label aliases)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Panel / dashboard | catalog read + pack |
| Create report CTA | ∩ `reports:write` (+ admin) |
| Domain Reporting mount | owned `ReportsDomainPack` |
| Domain Export | `evidence:export`; `regulatory_log` also `controlledRegulatoryLogRequirement` |
| Compliance panels in filter | only if compliance read/review |
