# Standardize Reports Tables

## Objective

Refactor every `AppListTable` on the Reports workspace (`/reports`, `ReportsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, repository contracts, or unrelated screen chrome unless required for compilation.

## Current State (from audit)

### Screen layout

| Item | Value |
|------|-------|
| Route | `/reports` (`AppRoutes.reports`) |
| Page | `ReportsWorkspacePage` in `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart` |
| Controller | `reportsWorkspaceControllerProvider` → `ReportsWorkspaceController` |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.reports` in controller `build()` — **preserve as-is** |
| Deep link | `?panel=<value>` via `ReportsWorkspacePanel.fromServer` |
| Workspace shell | `AppWorkspace` with `detail: _ReportsDetailPanel` (side panel) and `activity: _ReportsTimelinePanel` |

### Panel / tab matrix

`ReportsWorkspacePanel` enum (`reports_entities.dart`):

| Panel | `serverValue` | Primary table widget | Data source | Compliance? |
|-------|---------------|----------------------|-------------|-------------|
| Overview | `overview` | `_ReportItemsPanel` | `state.overview.items` | No |
| Catalog | `catalog` | `_ReportItemsPanel` | `state.overview.items` | No |
| Delivery | `delivery` | `_ReportItemsPanel` | `state.overview.items` | No |
| Dashboards | `dashboards` | `_ReportItemsPanel` | `state.overview.items` | No |
| Monitor | `monitor` | `_ReportItemsPanel` | `state.overview.items` | No |
| Activity | `activity` | `_ReportItemsPanel` | `state.overview.items` | No |
| Audit | `audit` | `_ComplianceLogPanel` | `state.complianceLogs` | Yes |
| PHI | `phi` | `_ComplianceLogPanel` | `state.complianceLogs` | Yes |
| Processing | `processing` | `_ComplianceLogPanel` | `state.complianceLogs` | Yes |

`_ReportsPrimaryPanel` switches `_ReportItemsPanel` vs `_ComplianceLogPanel` when `state.query.panel.isCompliance`.

`_ReportSchedulesPanel` renders **below** the primary panel when `!state.query.panel.isCompliance`, bound to `state.overview.schedules`.

### Table 1 — `_ReportItemsPanel`

| Attribute | Current value |
|-----------|---------------|
| File | `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart` |
| Entity | `ReportsWorkspaceItem` |
| `onRowSelected` | `controller.selectItem` — updates side panel only; **no modal dialog** |
| `displayMode` | **Missing** (defaults to table-only) |
| `columnVisibilityStorageKey` / `columnWidthStorageKey` | **Missing** |
| `columnVisibilityTitle` | **Missing** (only `columnVisibilityLabel` set) |
| `columnChoices` | **Missing** |
| Search `matcher` | `(_, _) => true` — **does not search row fields client-side** |
| Filter button label | `l10n.reportsFiltersLabel` → **"Report filters"** (should be **"Filters"**) |
| Filter modal title | `l10n.reportsFiltersLabel` → **"Report filters"** (should be **"Advanced filters"**) |
| `mobileItemBuilder` | `_ReportMobileTile` — shows title/subtitle/status; **no next-action** |

**Current columns (5 declared — at budget but wrong layout for workflow):**

| # | Label (l10n key) | Field | Cell pattern |
|---|------------------|-------|--------------|
| 1 | `reportsNameColumnLabel` | `title` + `subtitle` | `_TwoLineCell` + `_itemIcon(kind)` |
| 2 | `reportsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_status()` |
| 3 | `reportsReferenceLabel` | `reference` | `Text` |
| 4 | `reportsOwnerLabel` | `ownerLabel` | `Text` |
| 5 | `reportsUpdatedColumnLabel` | `occurredAt` | `_dateTime()` |

**Gaps vs `prompt.md`:**
- Status is column 2 instead of second-from-right (position 4).
- **No next-action column** (rightmost).
- Owner and reference should move to `columnChoices` (hidden by default); format, dataset, facility, category, description, value, errorMessage also belong in `columnChoices`.
- Search does not match hidden column fields.
- Non-standard Filters / Advanced filters labels.
- No session storage keys per table instance.
- Row tap does not open detail modal.
- No `displayMode: AppListTableDisplayMode.adaptive`.

**Workflow next-action rules** (`ReportsWorkspaceItem` getters in `reports_entities.dart`):

| Condition | Explicit label (existing l10n) | Handler (existing) |
|-----------|-------------------------------|-------------------|
| `kind == definition` && `canRun` | `reportsRunAction` | `_openRunDialog` |
| `kind == definition` && `canSchedule` (secondary in detail; primary action when not runnable) | `reportsScheduleAction` | `_openScheduleDialog` |
| `kind == run` && `canRetry` | `reportsRetryAction` | `_openRetryDialog` |
| `kind == run` && `canCancel` | `reportsCancelRunAction` | `_confirmCancelRun` |
| `kind == run` && `downloadAvailable` | `reportsDownloadAction` | `_downloadSelectedRun` |
| `kind == schedule` | `reportsScheduleAction` | `_openScheduleDialog` (reuse with selected item) |
| Other kinds (widget/kpi/analytics) | `reportsPreviewTitle` or view-only label | Open detail dialog only |

Use `AppReportActionButton` (from `frontend/lib/shared/components/app_report_actions.dart`) with `compact: true` styling in the next-action column — **not** `WorkflowActionButton` (reports are not encounter workflows).

### Table 2 — `_ComplianceLogPanel`

| Attribute | Current value |
|-----------|---------------|
| File | same as above |
| Entity | `ComplianceLogItem` |
| `onRowSelected` | `controller.selectComplianceLog` — side panel only |
| Search | Inline `AppListTableSearch` with `matcher: (_, _) => true` |
| Filter labels | Same non-standard `reportsFiltersLabel` for button and title |
| Storage keys | **Missing** |
| `displayMode` | **Missing** |
| `columnChoices` | **Missing** |

**Current columns (4 declared):**

| # | Label | Field | Cell |
|---|-------|-------|------|
| 1 | `reportsEventColumnLabel` | `title` + `subtitle` | `_TwoLineCell` |
| 2 | `reportsUserColumnLabel` | `userLabel` | `Text` |
| 3 | `reportsRecordColumnLabel` | `recordReference` | `Text` |
| 4 | `reportsTimestampColumnLabel` | `occurredAt` | `_dateTime()` |

**Gaps vs `prompt.md`:**
- No next-action column (`reportsExportEvidenceAction` when `canExportEvidence`).
- Patient, action, entity, scope, purpose, legal basis, facility, IP, details should be `columnChoices`.
- Search matcher stub; non-standard filter labels; no storage keys; no modal on row tap; mobile tile lacks export action.
- Compliance logs are read-only audit records — **no status workflow column** required; use 4 data columns + next-action (5 total).

### Table 3 — `_ReportSchedulesPanel`

| Attribute | Current value |
|-----------|---------------|
| File | same as above |
| Entity | `ReportsWorkspaceItem` (schedule rows) |
| Search chrome | **Entirely missing** — no `search:` on `AppListTable` |
| `onRowSelected` | `controller.selectItem` — side panel only |
| Storage keys | **Missing** |
| `displayMode` | **Missing** |

**Current columns (4 declared):**

| # | Label | Field | Cell |
|---|-------|-------|------|
| 1 | `reportsNameColumnLabel` | `title` + `subtitle` | `_TwoLineCell` (schedule icon) |
| 2 | `reportsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` |
| 3 | `reportsFormatColumnLabel` | `format` | `Text` |
| 4 | `reportsUpdatedColumnLabel` | `occurredAt` | `_dateTime()` |

**Gaps vs `prompt.md`:**
- No search bar at all.
- Status is column 2, not second-from-right.
- No next-action column (schedule management / view).
- No filters, settings, storage keys, adaptive mode, or detail modal.

### Existing detail UI to reuse (do not duplicate)

| Widget | Location | Actions |
|--------|----------|---------|
| `_ReportDetailPanel` | `reports_workspace_page.dart` | Run, Schedule, Retry, Cancel, Download, Print via `AppReportActionButton` |
| `_ComplianceDetailPanel` | same | Print, Export evidence |
| `_ReportPreviewBody` / `_CompliancePreviewBody` | same | Read-only field grids |
| Action dialogs | `_RunReportDialog`, `_ScheduleReportDialog`, `_confirmCancelRun`, `_confirmExportEvidence` | Already modal |

Refactor detail panels to accept `isDialog: bool` (copy `EmergencyDetailPanel` pattern in `emergency_workspace_widgets.dart`) so the same widgets render inside `AppDialog` on row tap.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` (`_MortuaryWorklist` — Filters/Settings chrome, `_matchesSearch`, `columnChoices`)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` (`emergencyNextActionColumn`, `openEmergencyDetailDialog`, `isDialog` detail panel)
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` (`_openClaimsDetailDialog` — select then `showAppDialog`)
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` | `columnWidthStorageKey` |
|--------------|-------------|--------|----------------------------------|------------------------------|-------------------------|
| `_ReportItemsPanel` | Non-compliance panels (overview…activity) | `ReportsWorkspaceItem` | name, reference, updated, status, next_action | `reports_items_${panel.serverValue}` | `reports_items_cw_${panel.serverValue}` |
| `_ComplianceLogPanel` | audit, phi, processing | `ComplianceLogItem` | event, user, record, timestamp, next_action | `reports_compliance_${panel.serverValue}` | `reports_compliance_cw_${panel.serverValue}` |
| `_ReportSchedulesPanel` | Non-compliance panels (secondary table) | `ReportsWorkspaceItem` | name, format, updated, status, next_action | `reports_schedules` | `reports_schedules_cw` |

Use `state.query.panel.serverValue` when building keys inside panel widgets.

### Column plan — `_ReportItemsPanel`

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `name` | `reportsNameColumnLabel` | `title` / `subtitle` | `AppListItemText` or existing `_TwoLineCell` + `_itemIcon(kind)` |
| 2 | `reference` | `reportsReferenceLabel` | `reference` | `Text` via `_valueOrUnknown` |
| 3 | `updated` | `reportsUpdatedColumnLabel` | `occurredAt` | `_dateTime()`; `sortComparator: appListTableCompareDateTime` |
| 4 | `status` | `reportsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` via `_status(context, item.status)` |
| 5 | `next_action` | `reportsNextActionColumnLabel` (**new key**) | computed | `AppReportActionButton` or `AppButton` with explicit verb; `alwaysVisible: true` |

**`columnChoices` (hidden by default):** columns for `ownerLabel`, `format`, `datasetKey`, `facilityLabel`, `category`, `description`, `value`, `errorMessage` — each as separate `AppListTableColumn` with stable `id`.

### Column plan — `_ComplianceLogPanel`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `event` | `reportsEventColumnLabel` | `title` / `subtitle` | `_TwoLineCell` |
| 2 | `user` | `reportsUserColumnLabel` | `userLabel` | |
| 3 | `record` | `reportsRecordColumnLabel` | `recordReference` | |
| 4 | `timestamp` | `reportsTimestampColumnLabel` | `occurredAt` | |
| 5 | `next_action` | `reportsNextActionColumnLabel` | permission-gated | `reportsExportEvidenceAction` when `_canExportEvidence(policy)`; else shrink |

**`columnChoices`:** `patientLabel`, `action`, `entity`, `scope`, `purpose`, `legalBasis`, `facilityLabel`, `ipAddress`, `details`.

### Column plan — `_ReportSchedulesPanel`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `name` | `reportsNameColumnLabel` | `title` / `subtitle` | schedule icon |
| 2 | `format` | `reportsFormatColumnLabel` | `format` | |
| 3 | `updated` | `reportsUpdatedColumnLabel` | `occurredAt` | |
| 4 | `status` | `reportsStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | `reportsNextActionColumnLabel` | `reportsScheduleAction` or view | Opens schedule dialog / detail |

### Search chrome (all three tables)

For each table, wire `AppListTableSearch` with:

- `matcher`: dedicated function (see Implementation Steps) — must include **all** default + `columnChoices` field values.
- `showAdvancedFilterButton: true`
- `advancedFilterButtonLabel: l10n.commonFiltersActionLabel` (**add key** → `"Filters"`)
- `advancedFilterTitle: l10n.commonAdvancedFiltersTitle` (**add key** → `"Advanced filters"`)
- Reuse existing `filterGroups`, `filterValue`, `hasActiveFilters`, `onFilterChanged`, date filter labels from current `_reportSearch` / compliance inline search.
- Table Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`, `columnVisibilityTitle: l10n.commonTableSettingsTitle` (**add key** → `"Table Settings"`)

**`_ReportSchedulesPanel`:** add a dedicated search bar (can share `_searchController` from parent state or a separate controller — if sharing, ensure `onSubmitted` still calls `controller.applySearch`). Schedules table search matcher must cover schedule row fields.

### Row interaction

Replace direct `onRowSelected: controller.selectItem` / `selectComplianceLog` with:

```dart
onRowSelected: (item) {
  unawaited(_openReportDetailDialog(context, ref, state, item, policy));
},
```

```dart
onRowSelected: (item) {
  unawaited(_openComplianceDetailDialog(context, ref, state, item, policy));
},
```

Implement helpers at bottom of page file (or new widgets file):

1. Call `controller.selectItem(item)` / `selectComplianceLog(item)`.
2. `showAppDialog` with `AppDialog(scrollable: true, maxWidth: 960, …)`.
3. Content: `_ReportDetailPanel` / `_ComplianceDetailPanel` with `isDialog: true`.
4. Next-action column handlers must invoke the **same** dialog functions (`_openRunDialog`, `_openScheduleDialog`, etc.) already used in detail panel actions.

Keep `AppWorkspace` `detail:` slot populated when an item is selected (existing behavior) — modal is additive for `prompt.md` §5 compliance.

### Responsiveness

Every `AppListTable`:

```dart
displayMode: AppListTableDisplayMode.adaptive,
mobileItemBuilder: (context, item) => _ReportMobileTile(..., showNextAction: true, ...),
```

Update `_ReportMobileTile`, `_ComplianceMobileTile`, and schedule mobile tile to show status badge **and** the same next-action control as desktop column 5.

## Implementation Steps

### 0. Shared helpers (recommended new file)

Create `frontend/lib/features/reports/presentation/widgets/reports_workspace_table_helpers.dart` (or keep in page if small) exporting:

- `bool matchesReportItemSearch(ReportsWorkspaceItem item, String query)`
- `bool matchesComplianceLogSearch(ComplianceLogItem item, String query)`
- `String reportNextActionLabel(AppLocalizations l10n, ReportsWorkspaceItem item)`
- `Widget reportNextActionCell(BuildContext context, WidgetRef ref, ReportsWorkspaceItem item, ReportsWorkspaceState state, AppAccessPolicy policy)`
- `List<AppListTableColumn<ReportsWorkspaceItem>> reportItemColumns(...)` — parameterized by panel if needed
- `List<AppListTableColumn<ComplianceLogItem>> complianceLogColumns(...)`
- `List<AppListTableColumn<ReportsWorkspaceItem>> scheduleColumns(...)`
- `Future<void> openReportDetailDialog(...)`
- `Future<void> openComplianceDetailDialog(...)`

Search matchers must lowercase-trim query and test all relevant string fields (mirror `_matchesSearch` in mortuary).

`matchesReportItemSearch` fields: `title`, `subtitle`, `description`, `status`, `format`, `category`, `datasetKey`, `facilityLabel`, `ownerLabel`, `reference`, `errorMessage`, formatted `occurredAt`, `value`, `count`.

`matchesComplianceLogSearch` fields: `title`, `subtitle`, `userLabel`, `patientLabel`, `action`, `entity`, `scope`, `purpose`, `legalBasis`, `recordReference`, `facilityLabel`, `ipAddress`, `details`, formatted `occurredAt`.

### 1. `_ReportItemsPanel` — `reports_workspace_page.dart`

- Import helpers / shared components.
- Add `displayMode: AppListTableDisplayMode.adaptive`.
- Set `columnVisibilityStorageKey` and `columnWidthStorageKey` using `reports_items_${state.query.panel.serverValue}`.
- Set `columnVisibilityTitle: l10n.commonTableSettingsTitle`.
- Replace `_reportColumns` with ≤5 default columns per plan; register extended columns as `columnChoices`.
- Assign stable column `id` on every `AppListTableColumn`.
- Fix `_reportSearch` / `_reportSearch` method:
  - `matcher: matchesReportItemSearch` (or top-level `_matchesReportItemSearch`)
  - `advancedFilterButtonLabel: l10n.commonFiltersActionLabel`
  - `advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
- Replace `onRowSelected` with `openReportDetailDialog`.
- Update `_ReportMobileTile` for next-action parity.

### 2. `_ComplianceLogPanel`

- Same storage keys pattern: `reports_compliance_${state.query.panel.serverValue}`.
- Add `displayMode`, `columnVisibilityTitle`, `columnChoices`.
- Expand to 5 columns with next-action export.
- Fix search labels and matcher.
- `onRowSelected` → `openComplianceDetailDialog`.
- Update `_ComplianceMobileTile`.

### 3. `_ReportSchedulesPanel`

- Add full `AppListTableSearch` (matcher over schedule fields; panel filter group optional or omit if schedules are global).
- Add `columnVisibilityStorageKey: 'reports_schedules'`, `columnWidthStorageKey: 'reports_schedules_cw'`.
- Reorder columns per plan; add next-action column.
- Add `displayMode` and mobile parity.
- `onRowSelected` → `openReportDetailDialog` (schedules are `ReportsWorkspaceItem`).

### 4. Detail panel dialog refactor

- Add `final bool isDialog` to `_ReportDetailPanel` and `_ComplianceDetailPanel`.
- When `isDialog == true`, action buttons should still work; pop navigator after destructive success if appropriate (follow emergency `isDialog` pattern).
- Extract `openReportDetailDialog` / `openComplianceDetailDialog` functions.

### 5. l10n — `frontend/lib/l10n/app_en.arb` only

Add keys (English exactly as specified):

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"reportsNextActionColumnLabel": "Next action"
```

Run code generation if the project requires it after arb edits.

### 6. Tests

Create `frontend/test/features/reports/presentation/reports_workspace_page_test.dart` with widget tests:

- Pump `ReportsWorkspacePage` with mocked `reportsWorkspaceControllerProvider`.
- Assert each table has `displayMode: adaptive`, storage keys, and ≤5 visible columns.
- Assert search `matcher` returns true/false for known field values (unit-test matcher functions directly).
- Assert `onRowSelected` triggers dialog (use `showAppDialog` pump helpers).

Existing: `frontend/test/features/reports/presentation/reports_workspace_controller_test.dart` — must still pass.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | All tables |
| `AppListTableColumnVisibilityController` | same | Already in page state — wire storage keys |
| `AppListTableDisplayMode` | `app_list_table.dart` | `.adaptive` on all three tables |
| `AppWorkspaceStatusBadge` | shared components | Status columns |
| `AppListItemText` | shared components | Optional upgrade for name/event cells |
| `AppReportActionButton` | `package:hosspi_hms/shared/components/app_report_actions.dart` | Next-action column + detail actions |
| `AppDialog` / `showAppDialog` | shared forms/layout | Detail modals |
| `AppReportPreviewPanel` | shared printing | Detail body |

Do **not** introduce parallel table implementations.

## Files to Create / Modify / Delete

| File | Action |
|------|--------|
| `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart` | **Modify** — columns, search, dialogs, mobile, storage keys |
| `frontend/lib/features/reports/presentation/widgets/reports_workspace_table_helpers.dart` | **Create** (recommended) — matchers, column builders, dialog openers |
| `frontend/lib/l10n/app_en.arb` | **Modify** — add shared + `reportsNextActionColumnLabel` keys |
| `frontend/test/features/reports/presentation/reports_workspace_page_test.dart` | **Create** — widget/matcher tests |

No other files unless required for compilation.

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- Prefer new shared keys: `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`.
- Keep existing reports-specific column labels; add `reportsNextActionColumnLabel`.
- Stop using `reportsFiltersLabel` for table chrome button/title (may remain for other UI if referenced elsewhere).

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/reports/
```

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome (no export/refresh in search bar)
- [ ] Column visibility persists for session per table storage key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables (`_ReportItemsPanel`, `_ReportSchedulesPanel`): explicit status + next-action labels per row kind/status
- [ ] Compliance table: next-action shows `Export evidence` when permitted
- [ ] Row tap opens detail dialog reusing `_ReportDetailPanel` / `_ComplianceDetailPanel`
- [ ] Mobile list shows same priority fields, status, and next action
- [ ] Realtime refresh still updates rows after mutations/events (controller unchanged)
- [ ] Permissions still gate write/export actions (`_canWriteReports`, `_canExportEvidence`)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen (`_ReportItemsPanel`, `_ComplianceLogPanel`, `_ReportSchedulesPanel`)
- [ ] Domain logic preserved (run, schedule, retry, cancel, download, export, print flows unchanged)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/reports/` passes
