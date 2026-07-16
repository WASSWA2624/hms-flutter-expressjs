# Standardize HR Tables

## Objective

Refactor every `AppListTable` on the HR workspace (`/hr`, `HrWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

**Scope boundary:** Restructure **table chrome, columns, and row interactions only** for the two workspace tables (`_HrStaffDirectory`, `_HrWorkQueueTable`) and their shared dialog reuses. Do **not** rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation. The **Access** tab (`HrAccessWorkspacePanel` in `hr_access_dialogs.dart`) hosts separate tables — **out of scope** for this prompt.

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

**Route:** `/hr` (`AppRoutes.hr`)  
**Page widget:** `HrWorkspacePage`  
**Primary file:** `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`  
**Controller:** `hrWorkspaceControllerProvider` → `HrWorkspaceController` (`frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`)  
**Entities:** `HrStaffProfile`, `HrWorkItem` (`frontend/lib/features/hr/domain/entities/hr_entities.dart`)  
**Deep link:** `?section=<value>` where values are `staff`, `leave-requests`, `shift-roster`, `payroll`, `access` (`HrDeskSection.routeQueryValue`)

### Tab → table binding

| Tab (`HrDeskSection`) | l10n label (actual) | Table widget | Notes |
|-----------------------|---------------------|--------------|-------|
| `staffDirectory` | `l10n.hrTitle` | `_HrStaffDirectory` | Staff list |
| `leaveRequests` | `l10n.hrLeaveRequestsSummaryLabel` | `_HrWorkQueueTable` | Auto-loads `HrQueue.leaveRequests` via `_loadDataForSection` |
| `shiftRoster` | `l10n.hrShiftsSectionTitle` | `_HrWorkQueueSwitcherRow` + `_HrWorkQueueTable` | Queue switcher (`HrQueueSwitcher`) above table |
| `payroll` | `l10n.hrPayrollDraftsSummaryLabel` | `_HrWorkQueueTable` | Auto-loads `HrQueue.payrollDrafts` |
| `access` | `l10n.hrManageAccessAction` | *(none — `HrAccessWorkspacePanel`)* | Out of scope |

**Dialog reuses (must stay in sync with table refactors):**
- `_HrStaffDirectory` → `showHrStaffDirectoryDialog` / `_HrStaffDirectoryDialogContent` (`hr_workspace_dialog_actions.dart`)
- `_HrWorkQueueTable` → `showHrWorkQueueDialog` / `_HrWorkQueuePanel` (`hr_workspace_dialog_actions.dart`)

## Current State (from audit)

### Table 1: `_HrStaffDirectory`

| Attribute | Value |
|-----------|-------|
| File | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` (~line 481) |
| Entity | `HrStaffProfile` |
| Provider data | `state.staff` via `hrWorkspaceControllerProvider` |
| Row detail | `onStaffSelected` → `_openStaffDetailDialog` → `showHrStaffDetailDialog` (`hr_workspace_dialog_actions.dart`) |
| Next-action handler | `AppButton.tertiary` calls `onStaffSelected(item)` — opens staff detail dialog |

**Current columns (5 — at budget but non-compliant):**

| # | Label (l10n) | Field(s) | Cell pattern | Issues |
|---|--------------|----------|--------------|--------|
| 1 | `hrStaffColumnLabel` | `displayName` + `staffNumber`/`displayId` | `AppCopyableIdentifierCell` | OK (one field, two-line identifier) |
| 2 | `hrRolePositionColumnLabel` | `position` + `practitionerType` | `AppListItemText` title/subtitle | **Violates §2** — two semantic fields merged |
| 3 | `hrDepartmentColumnLabel` | `departmentName` | `Text` | OK |
| 4 | `hrStatusColumnLabel` | `status` | `_StatusBadge` → `AppWorkspaceStatusBadge` | OK position (should be col 4) |
| 5 | `hrNextActionColumnLabel` | computed via `_staffNextAction` | `AppButton.tertiary` | OK explicit verbs; missing `id`, `alwaysVisible` |

**Search chrome gaps:**
- `matcher: (_, _) => true` — **does not search any column** (§1 violation)
- `advancedFilterButtonLabel`: `l10n.hrFiltersLabel` ("Filters") — OK
- `advancedFilterTitle`: `l10n.hrFiltersLabel` ("Filters") — **should be "Advanced filters"** (§1)
- Missing `columnVisibilityTitle` ("Table Settings")
- Missing `columnVisibilityStorageKey` / `columnWidthStorageKey`
- Missing `displayMode: AppListTableDisplayMode.adaptive`
- No `columnChoices` for hidden fields (`practitionerType`, `hireDate`, `userEmail`, `staffNumber` standalone, `consultationFee`)
- No column `id` values

**Mobile gaps (`_HrStaffListTile`):**
- Missing `AppWorkspaceStatusBadge` for status
- Next action shown as plain `Text`, not `AppButton.tertiary`

**Realtime:** Wired — `HrWorkspaceController` uses `RealtimeRefreshMixin` + `_syncFromRealtime` (20s interval). Table reads `ref.watch(hrWorkspaceControllerProvider)` — OK.

---

### Table 2: `_HrWorkQueueTable`

| Attribute | Value |
|-----------|-------|
| File | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` (~line 1138) |
| Entity | `HrWorkItem` |
| Provider data | `state.workItems`, `state.workItemsQuery.queue` |
| Row detail | `onRowSelected` → `_showWorkItemDialog` → `_WorkItemActions` |
| Next-action labels | `_workItemNextAction` — explicit per queue (Approve leave, Approve swap, Publish roster, Override shift, Process payroll) |

**Current columns (5 — wrong order and content):**

| # | Label (l10n) | Field(s) | Cell pattern | Issues |
|---|--------------|----------|--------------|--------|
| 1 | `hrQueueItemColumnLabel` | queue-specific composite via `_workItemTitle` | `AppCopyableIdentifierCell` | **Violates §2** — merges leave type + staff name + IDs |
| 2 | `hrQueueColumnLabel` | `queue` | `Text(hrQueueLabel(...))` | Redundant on single-queue tabs; belongs in `columnChoices` |
| 3 | `hrStatusColumnLabel` | `status` | `_StatusBadge` | Wrong position (should be col 4, not 3) |
| 4 | `hrPeriodColumnLabel` | `periodLabel` / `startAt`–`endAt` | `Text` | OK data column |
| 5 | `hrNextActionColumnLabel` | `_workItemNextAction` | plain `Text` | **Not interactive** — must be `AppButton.tertiary` opening same destination as row tap |

**Search chrome gaps:**
- **No `search` property at all** (§1 violation)
- `HrWorkItemsQuery.search` exists and API accepts `search` param (`hr_repository_impl.dart` `listWorkItems`) but **no controller method** to apply it
- Missing `columnVisibilityTitle`, storage keys, `displayMode`, `columnChoices`
- No column `id` values

**Mobile gaps (`_HrWorkItemTile`):**
- Has status badge — OK
- **Missing next-action button**

**Queue-specific column needs:** `_workItemTitle` builds different composites per `HrQueue` — refactor to `_columnsForQueue(HrQueue queue)` pattern (copy `DischargeWorkspacePage._columnsForSection`).

**Realtime:** Same provider — OK.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome, `filterGroups`, column `id`s)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, `WorkflowActionButton` (HR does **not** use `WorkflowActionButton`; use `AppButton.tertiary` like staff table today)
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — `_columnsForSection`, `_searchMatcher`, `columnVisibilityStorageKey`, interactive next-action column
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | `columnVisibilityStorageKey` | `columnWidthStorageKey` |
|--------------|-------------|--------|------------------------------|-------------------------|
| `_HrStaffDirectory` | Staff directory (+ staff directory dialog) | `HrStaffProfile` | `hr_staff_directory` | `hr_staff_directory_cw` |
| `_HrWorkQueueTable` | Leave / Shift roster / Payroll (+ work-queue dialog) | `HrWorkItem` | `hr_work_queue_${queue.name}` | `hr_work_queue_cw_${queue.name}` |

Pass `state.workItemsQuery.queue.name` when building `_HrWorkQueueTable` so column prefs persist per queue type.

### Column plan — `_HrStaffDirectory` (workflow entity: staff status)

| Position | Column `id` | Label (l10n) | Source field | Notes |
|----------|-------------|--------------|--------------|-------|
| 1 | `staff` | `hrStaffColumnLabel` | `displayName` + identifier subtitle | Keep `AppCopyableIdentifierCell` |
| 2 | `position` | `hrRolePositionColumnLabel` | `position` only | `Text` or `AppListItemText` with **no** practitioner subtitle |
| 3 | `department` | `hrDepartmentColumnLabel` | `departmentName` | |
| 4 | `status` | `hrStatusColumnLabel` | `status` | `_StatusBadge` / `AppWorkspaceStatusBadge` |
| 5 | `next_action` | `hrNextActionColumnLabel` | `_staffNextAction(context, item)` | `AppButton.tertiary`, `alwaysVisible: true`, `onPressed` → `onStaffSelected(item)` |

**`columnChoices` (hidden by default):**

| Column `id` | Label | Field |
|-------------|-------|-------|
| `practitioner_type` | `hrPractitionerTypeLabel` | `practitionerType` (use `_apiLabel`) |
| `hire_date` | `hrHireDateLabel` | `hireDate` (formatted) |
| `email` | `hrEmailLabel` | `userEmail` |
| `staff_number` | `hrStaffNumberLabel` | `staffNumber` |
| `consultation_fee` | `hrConsultationFeeLabel` | `consultationFee` + currency |

Set `columns` to the 5 defaults; pass full list (defaults + choices) as `columnChoices`.

### Column plan — `_HrWorkQueueTable` (per `HrQueue`)

Implement `List<AppListTableColumn<HrWorkItem>> _workQueueColumns(BuildContext context, HrQueue queue)` returning ≤5 defaults. Reorder so **status is column 4** and **next_action is column 5**.

**Shared default columns (all queues):**

| Position | Column `id` | Label | Source | Notes |
|----------|-------------|-------|--------|-------|
| 4 | `status` | `hrStatusColumnLabel` | `status` | `_StatusBadge` |
| 5 | `next_action` | `hrNextActionColumnLabel` | `_workItemNextAction` | `AppButton.tertiary`, `alwaysVisible: true`, opens `_showWorkItemDialog(context, ref, item)` |

**Per-queue data columns (positions 1–3):**

| Queue | Col 1 `id` | Col 1 field | Col 2 `id` | Col 2 field | Col 3 `id` | Col 3 field |
|-------|------------|-------------|------------|-------------|------------|-------------|
| `leaveRequests` | `leave_type` | `leaveType` (`_apiLabel`) | `staff` | `staffName` (+ `staffNumber` subtitle) | `period` | `periodLabel` / date range |
| `swapRequests` | `shift` | `shiftType` (`_apiLabel`) | `staff` | `staffName` / `staffNumber` | `period` | date range |
| `rosterDrafts` | `roster` | `periodLabel` or `rosterId` | `assignments` | `assignmentCount` | `period` | date range |
| `unassignedShifts`, `overdueShifts` | `shift` | `shiftType` | `shift_id` | `shiftId` | `period` | date range |
| `payrollDrafts` | `payroll` | `periodLabel` | `run_id` | `payrollRunId` / `displayId` | `period` | date range |

**`columnChoices` (hidden by default, vary by queue):**
- `queue` (`hrQueueColumnLabel`) — especially useful when `HrQueueSwitcher` is visible; default hidden on single-queue tabs
- `staff_position` (`hrPositionLabel`) → `staffPosition`
- `reason` → `reason` (where present)
- `effective_id` → `effectiveId`

Refactor `_workItemTitle` — use only in mobile subtitle or retire in favor of per-column builders.

### Staff next-action labels (`_staffNextAction` — preserve logic)

| Condition | l10n key |
|-----------|----------|
| No department | `hrNextActionAssignDepartment` |
| No position | `hrNextActionAssignPosition` |
| Otherwise | `hrNextActionReviewProfile` |

### Work-item next-action labels (`_workItemNextAction` — preserve logic)

| `HrQueue` | l10n key |
|-----------|----------|
| `leaveRequests` | `hrApproveLeaveAction` |
| `swapRequests` | `hrApproveSwapAction` |
| `rosterDrafts` | `hrPublishRosterAction` |
| `unassignedShifts`, `overdueShifts` | `hrOverrideShiftAction` |
| `payrollDrafts` | `hrProcessPayrollAction` |

### Search chrome (per table)

**Staff directory (`_HrStaffDirectory`):**
- Add `static bool _staffSearchMatcher(HrStaffProfile item, String query)` matching: `displayName`, `staffNumber`, `displayId`, `id`, `position`, `departmentName`, `departmentDisplayId`, `practitionerType` (raw + `_apiLabel`), `status`, `userEmail`, `userFullName`, and all `columnChoices` fields
- Wire `matcher: _staffSearchMatcher`; keep `onSubmitted` → `controller.applyStaffSearch`
- `advancedFilterButtonLabel`: prefer new shared `l10n.commonFiltersActionLabel` ("Filters") or keep `hrFiltersLabel`
- `advancedFilterTitle`: `l10n.commonAdvancedFiltersTitle` ("Advanced filters") — **add key if missing**
- `columnVisibilityLabel`: `l10n.commonTableSettingsActionLabel`
- `columnVisibilityTitle`: `l10n.commonTableSettingsTitle` ("Table Settings") — **add key if missing**
- Keep existing `filterGroups` (department, practitioner type) and `textFilters` (position)

**Work queue (`_HrWorkQueueTable`):**
- Add `late final TextEditingController _workQueueSearchController` in `_HrWorkspaceContentState` (init from `state.workItemsQuery.search`, dispose in `dispose`, sync in `didUpdateWidget`)
- Add `AppListTableSearch<HrWorkItem>` with:
  - `matcher: _workItemSearchMatcher` (client-side match across all column + choice fields)
  - `onSubmitted` / `onClear` → new `controller.applyWorkItemsSearch`
  - `showAdvancedFilterButton: true` with status/date filters as appropriate (minimum: status filter using `controller.applyWorkItemsScope`)
  - Same Filters/Settings labels as staff table
- Pass `search:` into `_HrWorkQueueTable` (add constructor param + wire from parent)

### Row interaction

| Table | `onRowSelected` | Detail dialog | Follow-up actions |
|-------|-----------------|---------------|-------------------|
| Staff | `onStaffSelected` / `_openStaffDetailDialog` | `showHrStaffDetailDialog` → `_HrStaffDetailPanel` | `HrStaffDetailActions` (assign dept/position, leave, payroll, offboard, etc.) |
| Work queue | `_showWorkItemDialog` | `AppDialog` + `_WorkItemActions` | `AppPermissionActionItem` list per queue (approve/reject leave, publish roster, process payroll, etc.) |

Next-action column buttons must open the **same** dialog as row tap (staff detail / work item dialog), not navigate to module home.

### Responsiveness

Both tables:
```dart
displayMode: AppListTableDisplayMode.adaptive,
```

**`_HrStaffListTile` mobile parity:** Show staff identifier, position, department (subtitle), `AppWorkspaceStatusBadge`, and `AppButton.tertiary` for next action.

**`_HrWorkItemTile` mobile parity:** Show queue-relevant title/subtitle, `AppWorkspaceStatusBadge`, and `AppButton.tertiary` for `_workItemNextAction`.

## Implementation Steps

### 0. Shared l10n (`frontend/lib/l10n/app_en.arb` only)

Add if missing:
```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen: `cd frontend && dart run intl_utils:generate` (or project-standard l10n generation command).

### 1. Controller — work-queue search

**File:** `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`

Add `applyWorkItemsSearch(String value)` mirroring `applyStaffSearch`:
- Update `workItemsQuery.search` and reset to first page
- Set `isRefreshingWorkItems: true`
- Call `_refreshWorkItems(showLoading: true)`

### 2. `_HrStaffDirectory`

**File:** `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`

1. Add `_staffSearchMatcher` static method (see Search chrome above)
2. On `AppListTable<HrStaffProfile>`:
   - `displayMode: AppListTableDisplayMode.adaptive`
   - `columnVisibilityStorageKey: 'hr_staff_directory'`
   - `columnWidthStorageKey: 'hr_staff_directory_cw'`
   - `columnVisibilityTitle: l10n.commonTableSettingsTitle`
   - `matcher: _staffSearchMatcher`
   - `advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
   - Split position/practitioner columns per plan; add `columnChoices`
   - Add `id` to every `AppListTableColumn`
   - `next_action` column: `alwaysVisible: true`
3. Update `_HrStaffListTile` for status badge + action button parity
4. Extract column builders to top-level or static helpers if needed for search matcher reuse

### 3. `_HrWorkQueueTable`

**File:** `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`

1. Add constructor params: `TextEditingController searchController` (or inline search config from parent)
2. Add `_workItemSearchMatcher` and `_workQueueColumns(context, queue)`
3. On `AppListTable<HrWorkItem>`:
   - `displayMode: AppListTableDisplayMode.adaptive`
   - `columnVisibilityStorageKey: 'hr_work_queue_${state.workItemsQuery.queue.name}'`
   - `columnWidthStorageKey: 'hr_work_queue_cw_${state.workItemsQuery.queue.name}'`
   - `columnVisibilityTitle: l10n.commonTableSettingsTitle`
   - `search: AppListTableSearch<HrWorkItem>(...)`
   - `columns` + `columnChoices` per queue
   - Replace next-action `Text` with `AppButton.tertiary`
4. Update `_HrWorkItemTile` — add next-action button
5. Wire `_workQueueSearchController` from `_HrWorkspaceContentState` into all `_HrWorkQueueTable` call sites (leave, shift roster, payroll tabs)

### 4. Dialog reuses

**File:** `frontend/lib/features/hr/presentation/pages/hr_workspace_dialog_actions.dart`

- `showHrStaffDirectoryDialog`: pass storage keys or accept that dialog uses ephemeral controller (OK if dialog creates fresh `AppListTableColumnVisibilityController` — no change required unless dialog should persist keys; use `hr_staff_directory_dialog` key if adding persistence)
- `showHrWorkQueueDialog` / `_HrWorkQueuePanel`: add search controller wired to `workItemsQuery.search`; pass through to `_HrWorkQueueTable`

### 5. Imports

Ensure these are available (via `shared/components/components.dart` or direct):
- `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableDisplayMode`
- `AppListTableColumnVisibilityController`
- `AppWorkspaceStatusBadge`, `AppListItemText`, `AppButton`
- `appListTableCompareText`, `appListTableCompareDateTime`

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/app_list_table.dart` | Both tables |
| `AppListTableColumn` | same | Column definitions with `id` |
| `AppListTableSearch` | same | Search chrome |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableDisplayMode` | same | `.adaptive` |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/components/components.dart` | Status column + mobile |
| `AppListItemText` | same | Two-line cells (staff name, staff in work queue) |
| `AppCopyableIdentifierCell` | same | Staff column |
| `AppButton.tertiary` | same | Next-action columns (not `WorkflowActionButton`) |
| `showHrStaffDetailDialog` | `hr_workspace_dialog_actions.dart` (part of page) | Staff row/next-action |
| `_showWorkItemDialog` | `hr_workspace_page.dart` | Work queue row/next-action |

## Files to Create / Modify / Delete

| Action | File |
|--------|------|
| Modify | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` |
| Modify | `frontend/lib/features/hr/presentation/pages/hr_workspace_dialog_actions.dart` |
| Modify | `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | Generated l10n outputs if codegen does not run in CI |
| Optional test updates | `frontend/test/features/hr/presentation/hr_workspace_controller_test.dart` (add `applyWorkItemsSearch` case) |

**No new files required.** **No deletions.**

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonTableSettingsTitle`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`
- Keep existing HR column labels (`hrStaffColumnLabel`, `hrStatusColumnLabel`, `hrNextActionColumnLabel`, etc.)

## Database Migrations

No database migrations required — schema unchanged. Search/filter changes use existing `HrStaffQuery` / `HrWorkItemsQuery` API parameters.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/hr/
```

## Testing Requirements

- [ ] Staff table: search matches name, staff number, department, position, hidden columns
- [ ] Staff table: Filters + Settings only in search chrome (no export/refresh in table chrome)
- [ ] Staff table: column visibility persists per `hr_staff_directory` key for the session
- [ ] Staff table: ≤5 default columns; row number is automatic
- [ ] Staff table: status badge + explicit next-action button (`Assign department` / `Assign position` / `Review profile`)
- [ ] Staff table: row tap and next-action both open `showHrStaffDetailDialog`
- [ ] Staff table: mobile list shows status + action button
- [ ] Work queue table: search bar present; submits via `applyWorkItemsSearch`
- [ ] Work queue table: Filters + Settings only in chrome
- [ ] Work queue table: column visibility persists per `hr_work_queue_<queue>` key
- [ ] Work queue table: columns reorder per queue; status col 4, next-action col 5
- [ ] Work queue table: next-action is `AppButton.tertiary` opening work item dialog
- [ ] Work queue table: mobile shows status + action button
- [ ] Leave / Shift roster / Payroll tabs and work-queue dialog still function
- [ ] `HrQueueSwitcher` still switches queues without breaking column prefs
- [ ] Realtime refresh still updates rows after mutations (controller `_syncFromRealtime`)
- [ ] `HrStaffDetailActions` permission gating unchanged

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for `_HrStaffDirectory` and `_HrWorkQueueTable` on `/hr`
- [ ] Dialog reuses (`showHrStaffDirectoryDialog`, `showHrWorkQueueDialog`) remain functional
- [ ] Domain logic, permissions, and API contracts preserved
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/hr/` passes
