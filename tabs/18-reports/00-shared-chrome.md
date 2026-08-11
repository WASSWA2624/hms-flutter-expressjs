# Reports — shared / cross-panel chrome

## Shell entry

- Route: `AppRoutes.reports` under app `ShellRoute` (`path: '/reports'`)
- Catalog entry: `RouteAccessCatalog.reportsEntry` — ∪ `reports:read` \| `compliance:read` (`AccessRequirement` `reportsEntry`)
- Workspace read helper: `reportsWorkspaceReadRequirement` — same ∪; admins also via `_isReportsAdmin` (`tenantAdmin` \| `facilityAdmin` \| `platformAdmin`)
- Active module constant: `reportsActiveModule` = `'reporting-analytics'` (platform infra; not package-gated on entry)
- If `reportsAllowedPanels` is empty: page still mounts `AppWorkspace`; primary panel/schedules/timeline omitted — **no** `AppFailureStateView` forbidden

## Page chrome

- `AsyncStateScaffold<ReportsWorkspaceState>` over `reportsWorkspaceControllerProvider`
  - Loading: `reportsLoadingTitle` / `reportsLoadingBody`
  - App bar title: `reportsTitle`
  - Retry → `refresh()`
- Body: `AppWorkspace` (`title: reportsTitle`, `leadingIcon: AppRouteIcons.reports`)
  - `showHeader: false` when domain Reporting Overview chrome is active (pharmacy or owned non-pharmacy packs)
  - Primary: `_ReportsPrimaryPanel` (overview dashboard **or** report items table **or** compliance table)
  - Sibling: `_ReportSchedulesPanel` when catalog-readable, non-compliance, and **not** domain Overview
  - Activity rail: `_ReportsTimelinePanel` when timeline non-empty (same show rules)
- Deep-link: `ReportsWorkspacePageQuery.fromUri` reads **only** `?dataset=` → `applyDataset` / Catalog prefilter
  - **No** `panel` / `section` / `search` / `status` URL sync (`syncWorkspaceLocation` unused)

## Panel strip (actual product behavior)

- **Not** `AppTabStrip` / `AppTabItem` / `AppTabCountTone`
- Panel switch = Advanced filters group key `'panel'` (`_panelFilterKey`) with choices from `reportsAllowedPanels`
- Labels via `_panelLabel` → `reportsPanelOverview|Catalog|Delivery|Dashboards|Monitor|Activity|Audit|Phi|Processing`
- Icons via `_panelIcon` (dashboard / article / outbox / dashboard_customize / bar_chart / insights / manage_search / privacy_tip / policy)
- `serverValue` = enum string: `overview|catalog|delivery|dashboards|monitor|activity|audit|phi|processing`
- Count badges: **none** on panel chrome (Overview KPI/queue counts are dashboard metrics, not tab badges)
- Panels omitted when unauthorized (`canAccessReportsPanel` / role-tailored catalog + compliance) — not disabled
- Unauthorized current panel → post-frame `applyPanel(allowedPanels.first)`

## Panel gates (AccessRequirement names)

| Name | Rule |
| --- | --- |
| `reportsWorkspaceReadRequirement` | ∪ `reports:read` \| `compliance:read` |
| `reportsCatalogReadRequirement` | ∪ `reports:read` |
| `reportsComplianceReadRequirement` | ∪ `compliance:read` \| `compliance:review` |
| `reportsWriteRequirement` | ∩ `reports:write` (+ admin overlay in `canWriteReports`) |
| `reportsDeleteRequirement` | ∩ `reports:delete` — **no UI** |
| `reportsExportRequirement` | ∪ `evidence:export` (+ admin in `canExportEvidence`) |
| `controlledRegulatoryLogRequirement` | ∪ `compliance:read` \| `compliance:review` — pharmacy `regulatory_log` export gate |
| `reportsPanelReadRequirement(panel)` | compliance → compliance req; else catalog req |

Catalog panel set further tailored by `reportsTailoredCatalogPanels` / `ReportsDomainPack`.

Default resource per panel (`ReportsWorkspaceResource.serverValue`): overview/delivery → `report-runs`; catalog → `report-definitions`; dashboards → `dashboard-widgets`; monitor → `kpi-snapshots`; activity → `analytics-events`.

## Table toolbar (shared pattern)

On list panels, search embeds Filters; Settings via column visibility; **Export/Print not explicitly gated on `AppListTable`**.

Order observed: **Search → Filters → Settings → (default Export ON, Print OFF)**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `reportsSearchLabel` / hint `reportsSearchHint` (compliance: `reportsComplianceSearchHint`); clear `reportsClearSearchLabel` | mic via shared default |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction` | panel switch lives here |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | storage `reports_items_<panel>` / `reports_items_cw_<panel>`; compliance `reports_compliance_*`; schedules `reports_schedules` / `reports_schedules_cw` |
| Export (table) | default `enableExport: true`, `canExport: true` | **not** wired to `canExportEvidence` |
| Print (table) | default `enablePrint: false` | print only in detail / domain dialogs |
| Date labels | `reportsDateFilterLabel`, `reportsDateFromLabel`, `reportsDateToLabel`, … | UI present; **from/to never applied to controller** |

Default visible columns: **4** data columns (+ `next_action` when write/export entitles).

## Shared dialogs / feedback

- Detail: `reportsPreviewTitle` / `reportsComplianceDetailTitle` (Reports-owned)
- Run/Retry/Schedule/Cancel/Export-evidence confirms (Reports-owned)
- Success: `reportsSavedMessage`; download: `reportsDownloadRequestedMessage`
- Failures: form banners / `showAppFailureSnackBar`; page-level `lastFailure` cleared without banner
- Domain Overview: **reused** `ModuleReporting*` + Reports wrappers (`openPharmacyReportingReportDialog`, domain packs)

## Sibling surfaces (not separate panels)

### Schedules (`reportsSchedulesTitle`)

- Shown under catalog panels (not Overview domain, not compliance)
- Columns: name, format, updated, status (+ Schedule next-action if write)
- Empty: `reportsNoSchedulesTitle` / `reportsNoSchedulesBody`
- Controller `pauseSelectedSchedule` / `resumeSelectedSchedule` **exist; no UI call sites**

### Timeline

- `reportsTimelineTitle` / `reportsTimelineDescription`; max 6 items; status tones
