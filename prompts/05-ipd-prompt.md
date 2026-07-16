# Standardize IPD Tables

## Objective

Refactor every `AppListTable` on the IPD workspace (`/ipd`, `IpdWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, tab toolbar actions (refresh, start admission, manage beds), or unrelated screen chrome unless required for compilation.

## Current State (from audit)

### Screen layout

| Item | Value |
|------|-------|
| Route | `/ipd` (`AppRoutes.ipd`) |
| Page widget | `IpdWorkspacePage` |
| Primary file | `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` |
| Controller | `ipdWorkspaceControllerProvider` → `IpdWorkspaceController` |
| Deep-link query | `?section=<tab>` (`admission-queue`, `active`, `transfers`, `discharge`, `bed-board`); `?panel=<value>` on admission detail; `focusAdmissionId` via route query |

**Tabs** (`AppTabStrip` in `_IpdWorkspaceContent`):

| Tab enum | URL `section` | Label l10n key | Table widget |
|----------|---------------|----------------|--------------|
| `IpdWorkspaceSection.admissionQueue` | `admission-queue` | `ipdAdmissionQueueTabLabel` | `_IpdBoardPanel` |
| `IpdWorkspaceSection.activePatients` | `active` | `ipdActivePatientsTabLabel` | `_IpdBoardPanel` |
| `IpdWorkspaceSection.transferPending` | `transfers` | `ipdTransfersTabLabel` | `_IpdBoardPanel` |
| `IpdWorkspaceSection.dischargePlanned` | `discharge` | `ipdDischargeTabLabel` | `_IpdBoardPanel` |
| `IpdWorkspaceSection.bedBoard` | `bed-board` | `ipdBedBoardTab` | `IpdBedBoardPanel` |

All four admission worklist tabs share one `_IpdBoardPanel` instance; only `IpdQueueScope` / `state.query.scope` and pagination data differ. Column layout is identical across those tabs today.

---

### Table 1 — `_IpdBoardPanel` (admission worklists)

| Field | Value |
|-------|-------|
| Widget | `_IpdBoardPanel` |
| File | `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` (lines ~438–614) |
| Entity | `IpdAdmissionSummary` |
| Provider data | `state.admissions` (`AppPage<IpdAdmissionSummary>`), `state.isRefreshing` |
| Visibility controller | `_tableColumnController` in `_IpdWorkspaceContentState` |
| Storage keys | `columnVisibilityStorageKey: 'ipd_${section.name}'`, `columnWidthStorageKey: 'ipd_cw_${section.name}'` |
| Row detail | `onRowSelected` → `_openIpdDetailDialog` (lines ~864–896) |
| Detail UI | `AppDialog` + `_IpdDetailPanel`; actions in `_IpdDetailActions` |

**Current columns (7 — exceeds budget):**

| # | Label l10n | Field / builder | Sort | Notes |
|---|------------|-----------------|------|-------|
| 1 | `opdPatientColumnLabel` | `displayTitle` + `displayId` via `_IpdPatientCell` | `displayTitle` | OK: one semantic field, two-line |
| 2 | `opdStatusColumnLabel` | `stage` → `AppWorkspaceStatusBadge` via `_stageStatus` | `stage` | Workflow status — wrong position (should be col 4) |
| 3 | `ipdLocationColumnLabel` | `location` (ward + bed) | `location` | Priority data |
| 4 | `ipdPendingActionColumnLabel` | `WorkflowActionButton` or `_nextStepLabel` | `nextStep` | Next action — wrong position (should be col 5) |
| 5 | `settingsWorkspaceModuleRole` | `_ipdOwnerRoleLabel(stage)` | owner role | Extra — move to `columnChoices` |
| 6 | `ipdAdmittedAtColumnLabel` | `admittedAt` formatted | `admittedAt` | Extra — move to `columnChoices` |
| 7 | `ipdLengthOfStayColumnLabel` | computed LOS from `admittedAt` | `admittedAt` | Extra — move to `columnChoices` |

**Search chrome today:**

- `AppListTableSearch` with `matcher: (_, _) => true` (no client match); search text sent server-side via `controller.applySearch`
- `advancedFilterButtonLabel: l10n.ipdFiltersLabel` (`"Filters"`) — button OK
- `advancedFilterTitle: l10n.ipdFiltersLabel` (`"Filters"`) — **wrong**; must be `"Advanced filters"`
- `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` — OK
- `columnVisibilityTitle` — **missing**; must be `"Table Settings"`
- Ward filter via `filterGroups` + `controller.applyWard` — OK
- No `columnChoices` registered

**Mobile (`_IpdMobileAdmissionRow`):** shows patient, status badge, and a subtitle joining location / `_nextStepLabel` / owner role as plain text. **Missing** `WorkflowActionButton` for next-action parity.

**Workflow stages** (`_stageLabel` / `_stageStatus`):

| Stage constant | Label key |
|----------------|-----------|
| `ADMISSION_REQUESTED` | `ipdStatusAdmissionRequested` (via `_stageLabel`; add if missing in switch) |
| `ADMITTED_PENDING_BED` | `ipdStatusAdmittedPendingBed` |
| `ADMITTED_IN_BED` | `ipdStatusAdmittedInBed` |
| `IN_PROCEDURE_OT` | `ipdStatusInProcedureOt` |
| `TRANSFER_REQUESTED` | `ipdStatusTransferRequested` |
| `TRANSFER_IN_PROGRESS` | `ipdStatusTransferInProgress` |
| `DISCHARGE_PLANNED` | `ipdStatusDischargePlanned` |
| `DISCHARGED` | `ipdStatusDischarged` |
| `CANCELLED` | `ipdStatusCancelled` |

**Next-step codes** (`_nextStepLabel` / `WorkflowActionButton.nextStep`):

| Code | Label key |
|------|-----------|
| `ASSIGN_BED` | `ipdNextAssignBed` |
| `RECORD_NURSING_NOTE` | `ipdNextRecordNursingNote` |
| `APPROVE_TRANSFER` | `ipdNextApproveTransfer` |
| `START_TRANSFER` | `ipdNextStartTransfer` |
| `COMPLETE_TRANSFER` | `ipdNextCompleteTransfer` |
| `COMPLETE_THEATRE_HANDOVER` | `ipdNextCompleteTheatreHandover` |
| `FINALIZE_DISCHARGE` | `ipdNextFinalizeDischarge` |
| default | `ipdNextContinueCare` |

**Gaps vs `prompt.md`:**

1. Seven declared columns (max five).
2. Status and next-action columns not in positions 4 and 5.
3. No `columnChoices` for owner role, admitted-at, length-of-stay.
4. No stable column `id` values on `AppListTableColumn` entries.
5. `advancedFilterTitle` uses `"Filters"` instead of `"Advanced filters"`.
6. Missing `columnVisibilityTitle` (`"Table Settings"`).
7. Search `matcher` is a no-op; hidden columns won't participate in client refinement. Extend `IpdAdmissionSummary.matchesSearch` (or a dedicated `_ipdAdmissionSearchMatcher`) to include owner-role label, formatted admitted-at, and length-of-stay strings so search covers visible + hidden columns. Keep server `applySearch` for paginated fetch; use matcher for in-page filtering consistency (same pattern as Mortuary `_matchesSearch`).
8. Mobile row lacks explicit next-action control (`WorkflowActionButton`).
9. `displayMode` not set explicitly (defaults to `adaptive` — set explicitly for clarity).

**Realtime:** `IpdWorkspaceController` uses `listenForRealtimeRefresh` with `RealtimeEventGroups.ipd` and `WorkspaceRefreshProfile.admissions`. Preserve this wiring.

---

### Table 2 — `IpdBedBoardPanel` (bed board)

| Field | Value |
|-------|-------|
| Widget | `IpdBedBoardPanel` / `_IpdBedBoardPanelState` |
| File | `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart` |
| Entity | `IpdBedBoardEntry` |
| Provider data | `state.bedBoard` (client-filtered by `_search` + ward/status filters) |
| Storage keys | `columnVisibilityStorageKey: 'ipd_bed_board'`, `columnWidthStorageKey: 'ipd_bed_board_cw'` |
| Row detail | **Missing `onRowSelected`**. Occupied beds open admission only via next-action menu (`onOpenAdmission` → `_openIpdDetailDialogById` in parent). |
| Bed actions | `_BedActionMenu` (`PopupMenuButton`) — module-specific next-action equivalent |

**Current columns (6 — exceeds budget):**

| # | Label l10n | Field / builder | Notes |
|---|------------|-----------------|-------|
| 1 | `ipdBedColumnLabel` | `bedLabel` | Priority data |
| 2 | `ipdWardColumnLabel` | `wardDisplayName` | Priority data |
| 3 | `ipdRoomColumnLabel` | `roomDisplayName` | Lower priority — move to `columnChoices` |
| 4 | `opdStatusColumnLabel` | bed `status` → `AppWorkspaceStatusBadge` | Status — correct relative order intent |
| 5 | `ipdCurrentPatientColumnLabel` | occupant name + admission id (`_BedOccupantCell`) | Priority data |
| 6 | `ipdNextActionColumnLabel` | `_BedActionMenu` | Next action |

**Search chrome today:**

- Client-side: items pre-filtered with `bed.matchesSearch(_search)` before passing to table
- `matcher: (_, _) => true` on `AppListTableSearch` — redundant; wire matcher to `IpdBedBoardEntry.matchesSearch` and drop manual `.where` pre-filter (or keep both consistent)
- `advancedFilterTitle: l10n.ipdFiltersLabel` — **wrong** (`"Filters"` not `"Advanced filters"`)
- Missing `columnVisibilityTitle`
- Ward + bed-status `filterGroups` — OK

**Bed next-action labels** (`_bedActionsFor`):

| Status | Primary actions |
|--------|-----------------|
| Occupied | `ipdBedActionOpenAdmission` |
| Available | `ipdBedActionReserve`, `ipdBedActionBlock`, `ipdBedActionMaintenance` |
| Reserved / Cleaning | `ipdBedActionMarkAvailable` |
| Maintenance / Blocked / Out of service | `ipdBedActionReturnToService` |

**Gaps vs `prompt.md`:**

1. Six declared columns (max five); drop `room` from defaults into `columnChoices`.
2. Reorder defaults to: bed, ward, current patient, status, next action.
3. No `onRowSelected` — add: when `occupantAdmissionId != null`, call parent `onOpenAdmission`; otherwise no dialog (or optional bed summary snackbar — do not navigate away).
4. `advancedFilterTitle` and `columnVisibilityTitle` non-standard.
5. No `columnChoices`.
6. No column `id` values.
7. `displayMode` not explicit (set `adaptive`).

**Realtime:** bed board refreshed via `controller.loadBedBoard()` on section switch and realtime sync in `IpdWorkspaceController`. Preserve.

---

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`, default `displayMode: adaptive`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings chrome, `columnVisibilityTitle`, `columnChoices`, search `matcher`, `mobileItemBuilder`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton` pattern
- `prompt.md`

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|----------------------------------|----------------------------|
| `_IpdBoardPanel` | Admission queue | `IpdAdmissionSummary` | patient, location, admitted_at, status, next_action | `ipd_admissionQueue` |
| `_IpdBoardPanel` | Active patients | `IpdAdmissionSummary` | patient, location, admitted_at, status, next_action | `ipd_activePatients` |
| `_IpdBoardPanel` | Transfers | `IpdAdmissionSummary` | patient, location, admitted_at, status, next_action | `ipd_transferPending` |
| `_IpdBoardPanel` | Discharge | `IpdAdmissionSummary` | patient, location, admitted_at, status, next_action | `ipd_dischargePlanned` |
| `IpdBedBoardPanel` | Bed board | `IpdBedBoardEntry` | bed, ward, current_patient, status, next_action | `ipd_bed_board` |

Hidden via `columnChoices` (not in default `columns`):

| Table | Hidden columns |
|-------|----------------|
| `_IpdBoardPanel` | `owner_role`, `length_of_stay` (keep `admitted_at` visible; owner role uses `_ipdOwnerRoleLabel`) |
| `IpdBedBoardPanel` | `room` |

---

### Column plan — `_IpdBoardPanel`

| Position | Column id | Label l10n | Source field | Notes |
|----------|-----------|------------|--------------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | `displayTitle` / `displayId` | `_IpdPatientCell`; `alwaysVisible: true` |
| 2 | `location` | `ipdLocationColumnLabel` | `location` | ward + bed joined |
| 3 | `admitted_at` | `ipdAdmittedAtColumnLabel` | `admittedAt` | `_dateTimeLabel` |
| 4 | `status` | `opdStatusColumnLabel` | `stage` | `AppWorkspaceStatusBadge` + `_stageStatus`; `alwaysVisible: true` |
| 5 | `next_action` | `ipdNextActionColumnLabel` | `nextStep` | `WorkflowActionButton` (`sourceModule: 'ipd'`, `compact: true`); fallback `_nextStepLabel` when no `encounterId`; `alwaysVisible: true` |

**`columnChoices` (hidden by default):**

| Column id | Label l10n | Source |
|-----------|------------|--------|
| `owner_role` | `settingsWorkspaceModuleRole` | `_ipdOwnerRoleLabel(stage)` |
| `length_of_stay` | `ipdLengthOfStayColumnLabel` | `_lengthOfStayLabel` |

Register on `AppListTable`:

```dart
final List<AppListTableColumn<IpdAdmissionSummary>> allColumns = _ipdAdmissionColumns(context);
// columns: first 5 defaults; columnChoices: allColumns;
```

---

### Column plan — `IpdBedBoardPanel`

| Position | Column id | Label l10n | Source field | Notes |
|----------|-----------|------------|--------------|-------|
| 1 | `bed` | `ipdBedColumnLabel` | `bedLabel` | bold primary |
| 2 | `ward` | `ipdWardColumnLabel` | `wardDisplayName` | |
| 3 | `current_patient` | `ipdCurrentPatientColumnLabel` | occupant | `_BedOccupantCell` (name + admission id) |
| 4 | `status` | `opdStatusColumnLabel` | bed `status` | `AppWorkspaceStatusBadge` + `bedStatusLabel` / `_bedStatusTone` |
| 5 | `next_action` | `ipdNextActionColumnLabel` | derived | `_BedActionMenu` (keep; not workflow entity) |

**`columnChoices`:**

| Column id | Label l10n | Source |
|-----------|------------|--------|
| `room` | `ipdRoomColumnLabel` | `roomDisplayName` |

---

### Search chrome (per table)

**Both tables:**

- Filters button label: `l10n.ipdFiltersLabel` (`"Filters"`) — keep
- Filters modal title: `l10n.commonAdvancedFiltersTitle` (add shared key `"Advanced filters"`) — do **not** reuse `ipdFiltersLabel` for title
- Settings button: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`
- Settings modal title: `columnVisibilityTitle: l10n.commonTableSettingsTitle` (add shared key `"Table Settings"`)

**`_IpdBoardPanel` matcher** — implement `_ipdAdmissionMatchesSearch(IpdAdmissionSummary admission, String query)`:

- Delegate to `admission.matchesSearch(query)` and additionally match formatted owner role, admitted-at string, and length-of-stay string so hidden columns are searchable
- Wire: `matcher: _ipdAdmissionMatchesSearch`, `onSubmitted: controller.applySearch`, `onClear: () => controller.applySearch('')`

**`IpdBedBoardPanel` matcher:**

- `matcher: (IpdBedBoardEntry bed, String query) => bed.matchesSearch(query)`
- Remove redundant `.where((bed) => bed.matchesSearch(_search))` pre-filter if matcher + `AppListTableSearch` handle it; or keep single code path

---

### Row interaction

| Table | `onRowSelected` behavior |
|-------|--------------------------|
| `_IpdBoardPanel` | Keep `_openIpdDetailDialog(context, ref, state, admission)` |
| `IpdBedBoardPanel` | Add `onRowSelected`: if `bed.occupantAdmissionId != null`, call `widget.onOpenAdmission(bed)`; else no-op |

Next-action column must open the same destination as detail follow-ups (`_IpdDetailActions` / `_BedActionMenu` primary action).

---

## Implementation Steps

### 1. Shared l10n keys — `frontend/lib/l10n/app_en.arb`

Add (if absent):

```json
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen (`flutter gen-l10n` or project equivalent). Use these keys on both IPD tables.

---

### 2. `_IpdBoardPanel` — `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`

1. Extract column definitions into a private function `_ipdAdmissionTableColumns(BuildContext context)` returning **all** columns (defaults + choices) with stable `id` values per plan above.
2. Set `columns` to the five defaults; pass full list as `columnChoices`.
3. Reorder: patient → location → admitted_at → status → next_action.
4. Rename pending-action column to use `ipdNextActionColumnLabel` and id `next_action`.
5. On `AppListTable`:
   - `columnVisibilityTitle: l10n.commonTableSettingsTitle`
   - `displayMode: AppListTableDisplayMode.adaptive`
   - `columnChoices: allColumns` (or equivalent visibility API)
6. Update `AppListTableSearch`:
   - `advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
   - `matcher: _ipdAdmissionMatchesSearch`
7. Update `_IpdMobileAdmissionRow`:
   - Keep patient + status row
   - Show location as subtitle line
   - Add `WorkflowActionButton` (same params as desktop column) aligned like Emergency mobile rows
8. Extend search helper to include hidden column display strings.

---

### 3. `IpdBedBoardPanel` — `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart`

1. Extract `_ipdBedBoardColumns(BuildContext context)` with ids; five defaults + `room` in `columnChoices`.
2. Reorder columns per plan (room hidden by default).
3. On `AppListTable`:
   - `columnVisibilityTitle: l10n.commonTableSettingsTitle`
   - `displayMode: AppListTableDisplayMode.adaptive`
   - `onRowSelected: (bed) { if (bed.occupantAdmissionId != null) widget.onOpenAdmission(bed); }`
4. Update search:
   - `advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
   - `matcher: (bed, query) => bed.matchesSearch(query)` — unify with `_search` state
5. Confirm `_BedBoardMobileRow` still shows bed, status, ward/room/occupant summary, and `_BedActionMenu`.

---

### 4. Tests — `frontend/test/features/ipd/presentation/ipd_workspace_page_test.dart`

Update/add expectations:

- Each worklist tab renders ≤5 default column headers (excluding automatic row number)
- Bed board renders 5 default columns
- Settings and Filters controls present in table search chrome (not tab toolbar)
- Tapping an admission row opens detail dialog (`ipdAdmissionDetailTitle`)
- Bed board row with occupant triggers detail dialog when tapped
- Column visibility keys remain `ipd_<section.name>` and `ipd_bed_board`

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Both tables |
| `AppListTableColumnVisibilityController` | same barrel | Session column visibility |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/layout.dart` | Status columns |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Admission next-action column + mobile |
| `AppListItemText` | `components.dart` (if simplifying cells) | Optional two-line cells |
| `_openIpdDetailDialog` / `_openIpdDetailDialogById` | `ipd_workspace_page.dart` | Row select + bed occupant |
| `IpdStartAdmissionDialog` | `presentation/widgets/ipd_start_admission_dialog.dart` | Unchanged — toolbar only |
| `bedStatusLabel` | `ipd_bed_board_panel.dart` | Bed status labels |

Do **not** introduce new table, search, or filter widgets.

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` |
| Modify | `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/ipd/presentation/ipd_workspace_page_test.dart` |
| Modify | Generated l10n outputs if not auto-generated in CI |
| Delete | None |

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only
- Add `commonAdvancedFiltersTitle` and `commonTableSettingsTitle` (shared across modules)
- Keep `ipdFiltersLabel` for the Filters **button** label
- Use `commonTableSettingsActionLabel` for Settings **button** label
- Prefer `ipdNextActionColumnLabel` over `ipdPendingActionColumnLabel` for the admission table next-action header (align with bed board)

---

## Database Migrations

No database migrations required — schema unchanged. Table layout and UI chrome only.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/ipd/
```

Manual smoke (web or device):

1. Open `/ipd` — verify all five tabs load
2. Admission queue / active / transfers / discharge: 5 data columns + auto row number; Filters opens **Advanced filters**; Settings opens **Table Settings**
3. Toggle hidden columns (owner role, length of stay) via Settings; search finds values in hidden columns
4. Row tap opens admission detail dialog; next-action button matches detail actions
5. Bed board: 5 columns; room available via Settings; occupied row tap opens admission detail
6. Mutate an admission (or receive realtime event) — table refreshes without manual reload

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome (refresh stays in tab toolbar)
- [ ] Column visibility persists for session per table storage key
- [ ] ≤5 default columns; row number automatic
- [ ] Admission tables: explicit status badge + `WorkflowActionButton` next action
- [ ] Bed board: status badge + `_BedActionMenu` next action
- [ ] Row tap opens detail dialog (admissions always; bed board when occupied)
- [ ] Mobile list shows same priority fields, status, and next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions (`_ipdOperationalWriteRequirement`, `_ipdBedManageRequirement`)

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved (scopes, pagination, bed mutations, workflow actions, permissions)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/ipd/` passes
