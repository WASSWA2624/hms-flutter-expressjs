# Standardize OPD Tables

## Objective

Refactor every `AppListTable` on the OPD workspace (`/opd`, `OpdWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, unrelated screen chrome (tab strip, toolbar refresh/start-walk-in), or routing unless required for compilation.

**Primary file:** `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` (~3150 lines; table, filter, dialog, and row-mapping logic live here).

## Current State (from audit)

### Screen overview

| Field | Value |
|-------|-------|
| Route | `/opd` |
| Page widget | `OpdWorkspacePage` |
| Feature module | `frontend/lib/features/opd/` |
| Data provider | `opdWorkspaceControllerProvider` (`frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`) |
| Realtime | `listenForRealtimeRefresh` + `OpdRealtimeDeltaApplier` on `RealtimeEventGroups.opd` |
| Deep links | `OpdWorkspaceQuery.fromUri`: `section`/`tab`, `panel`/`stage`/`filter`/`queue`, `flowId`/`encounter`/`id`, `search`/`q`/`patient` — **not** `scope` |

### Table inventory (single widget, tab-driven column sets)

| Table widget | Tab / panel | Entity | Default columns today | Detail on row select |
|--------------|-------------|--------|----------------------|----------------------|
| `_OpdMainTable` | All (`OpdWorkspaceSection.all`) | `_OpdTableItem` | 5: `patientNumber`, `patientName`, `queueStatus`, `nextStep`, `provider` | `_openTableItemActions` → `FlowActionsDialog` (flow) or `_OpdPatientActionsDialog` (appointment/queue) |
| `_OpdMainTable` | Arrivals | `_OpdTableItem` | 5: `patientNumber`, `patientName`, `visitType`, `arrivalTime`, `nextStep` | same |
| `_OpdMainTable` | Queue | `_OpdTableItem` | 5: `patientNumber`, `patientName`, `queueStatus`, `provider`, `nextStep` | same |
| `_OpdMainTable` | Triage | `_OpdTableItem` | **6** (violates budget): `patientNumber`, `patientName`, `queueStatus`, `waitingTime`, `provider`, `nextStep` | same |
| `_OpdMainTable` | Active | `_OpdTableItem` | **6** (violates budget): `patientNumber`, `patientName`, `queueStatus`, `nextStep`, `provider`, `encounter` | same |

**Column enum:** `_OpdTableColumnId` — `patientNumber`, `patientName`, `arrivalMode`, `visitType`, `queueStatus`, `provider`, `waitingTime`, `arrivalTime`, `nextStep`, `encounter`.

**Hidden column pool (`columnChoices`):** all of `_availableOpdTableColumns` (10 ids); duplicates full set including defaults.

### `_OpdTableItem` fields (worklist row model)

Built in `_tableItems()` from `OpdWorkspaceState`: merges `OpdFlowSummary` (triage + active flows), `OpdQueueEntry`, `OpdAppointment`. Key fields: `patientName`, `patientNumber`, `category` (`ARRIVAL`/`QUEUE`/`TRIAGE`/`ACTIVE_FLOW`), `status`, `visitType`, `queue`, `provider`, `encounterId`, `billing`/`billingState`, `nextStep`, `time`, `urgencyRank`, nested `appointment` / `queueEntry` / `flow`.

### Search chrome (current)

In `_OpdMainTable.build`:

- `AppListTableSearch` with `matcher: item.matches(query, field: filter.searchField)` — global search OK when `searchField` is null (searches all `_searchValuesForField` values).
- **Filters button:** `advancedFilterButtonLabel: l10n.opdFilterAction` (`"Filters"`) — label OK.
- **Filters modal title:** `advancedFilterTitle: l10n.opdFiltersLabel` (`"Filters"`) — **wrong**; must be **Advanced filters**.
- **Settings:** `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (`"Settings"`) — OK.
- **Settings modal title:** `columnVisibilityTitle` **not set** — must be **Table Settings**.
- `showAdvancedFilterButton: true`, rich `filterGroups` via `_opdTableFilterGroups`, `searchFields` via `_opdTableSearchFields` — preserve filter behavior.
- Refresh lives in tab toolbar (`AppTabToolbarAction`) — correct per `prompt.md`.
- Storage keys: `columnVisibilityStorageKey: 'opd_${section.name}'`, `columnWidthStorageKey: 'opd_cw_${section.name}'` — OK.

### Status and next-action (current gaps)

- **Status column** uses id `queueStatus` with `_QueueStatusCell` → `AppStatusText` (not `AppWorkspaceStatusBadge`). Triage uses `appTriageToneForValue`; others use `_stageTone`.
- **Next-action column** uses id `nextStep` with label `l10n.opdNextStepColumnLabel` (`"Next step"` — generic header). Cell is `_NextStepCell`: `WorkflowActionButton` only when `encounterId` is non-empty; otherwise plain `Text` via `_nextStepLabel`. Appointments/queue rows without flow show text only (e.g. `opdStartWalkInAction`).
- Column order does not consistently place **status second-from-right** and **next-action rightmost** (e.g. All tab: status pos 3, next pos 4, provider pos 5).

### Row selection (current — mostly compliant)

- `onRowSelected` → `_openTableItemActions` opens modal:
  - `item.flow != null` → `FlowActionsDialog` (`frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`)
  - else → `_OpdPatientActionsDialog` with appointment check-in / queue start / `QueueActionsDialog` nested actions
- Deep-link `flowId` opens `FlowActionsDialog` directly via `_openFlowById`.

### Responsiveness (current gaps)

- `displayMode` not set — defaults to `AppListTableDisplayMode.adaptive` (OK).
- `_OpdTableMobileRow` uses `AppListItemRow` with `AppStatusText` + plain `Text` for next step — **missing** `AppWorkspaceStatusBadge` and `WorkflowActionButton` parity.

### Patient column (content gap)

- `patientNumber` and `patientName` are **separate columns** — should be **one** `patient` column with `AppListItemText` (name primary, MRN subtitle) per `prompt.md` §2.

### Realtime (current — compliant, preserve)

- Table reads `OpdWorkspaceState` from parent; controller patches via WebSocket deltas and `refresh()`. Do not mutate table data locally after mutations — keep using `opdWorkspaceControllerProvider.notifier` actions.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, `AppListTableColumn`, `AppListTableColumnVisibilityController`, `displayMode`, `columnVisibilityTitle`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings chrome, `AppWorkspaceStatusBadge` in status column
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` with `WorkflowActionButton` (`id: 'next_action'`, `alwaysVisible: true`)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — per-tab ≤5 columns, `AppWorkspaceStatusBadge` + `WorkflowActionButton` on desk rows
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `_OpdMainTable` | all | `_OpdTableItem` | patient, category, provider, status, next_action | `opd_all` |
| `_OpdMainTable` | arrivals | `_OpdTableItem` | patient, visit_type, arrival_time, status, next_action | `opd_arrivals` |
| `_OpdMainTable` | queue | `_OpdTableItem` | patient, provider, waiting_time, status, next_action | `opd_queue` |
| `_OpdMainTable` | triage | `_OpdTableItem` | patient, waiting_time, provider, status, next_action | `opd_triage` |
| `_OpdMainTable` | active | `_OpdTableItem` | patient, provider, visit_type, status, next_action | `opd_active` |

Rename enum `_OpdTableColumnId` values to match column ids above (`patient` replaces `patientNumber`+`patientName`; `queueStatus` → `status`; `nextStep` → `next_action`). Keep legacy field mappings in `_opdDataColumn` switch.

### Column plan (per table)

#### All tab

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | `patientName` + `patientNumber` | `AppListItemText` two-line |
| 2 | `category` | `opdCategoryFilterLabel` | `category` | `_categoryLabel(context, item.category)` |
| 3 | `provider` | `opdProviderColumnLabel` | `provider` | plain Text |
| 4 | `status` | `opdStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge`; triage → triage tone helpers |
| 5 | `next_action` | `commonNextActionLabel` or new `opdNextActionColumnLabel` | `nextStep` / flow stage | `WorkflowActionButton`; see § Next-action wiring |

**columnChoices (hidden):** `arrival_mode`, `visit_type`, `waiting_time`, `arrival_time`, `encounter`

#### Arrivals tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | name + MRN | `AppListItemText` |
| 2 | `visit_type` | `opdVisitTypeColumnLabel` | `visitType` | |
| 3 | `arrival_time` | `opdTimeColumnLabel` | `time` | `_formatDateTime` |
| 4 | `status` | `opdStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | next-action label | `nextStep` | explicit verb via `WorkflowActionButton` or appointment action |

**columnChoices:** `arrival_mode`, `provider`, `waiting_time`, `encounter`, `category`

#### Queue tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | name + MRN | |
| 2 | `provider` | `opdProviderColumnLabel` | `provider` | |
| 3 | `waiting_time` | `opdWaitingTimeColumnLabel` | `time` | `_waitingTimeLabel` |
| 4 | `status` | `opdStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | next-action label | `nextStep` | `WorkflowActionButton` with `queueEntryId` when no flow |

**columnChoices:** `visit_type`, `arrival_time`, `arrival_mode`, `encounter`

#### Triage tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | name + MRN | |
| 2 | `waiting_time` | `opdWaitingTimeColumnLabel` | `time` | drops provider from defaults (was 6th column) |
| 3 | `provider` | `opdProviderColumnLabel` | `provider` | |
| 4 | `status` | `opdStatusColumnLabel` | `status` / triage level | `AppWorkspaceStatusBadge` + `appTriageToneForValue` when triage |
| 5 | `next_action` | next-action label | `nextStep` | `WorkflowActionButton` |

**columnChoices:** `visit_type`, `arrival_mode`, `arrival_time`, `encounter`, `queue` (if needed)

#### Active tab

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | name + MRN | |
| 2 | `provider` | `opdProviderColumnLabel` | `provider` | |
| 3 | `visit_type` | `opdVisitTypeColumnLabel` | `visitType` | replaces `encounter` in defaults |
| 4 | `status` | `opdStatusColumnLabel` | `status` / `flow.stage` | `AppWorkspaceStatusBadge` via `opdStatusDisplayLabel` |
| 5 | `next_action` | next-action label | `nextStep` | `WorkflowActionButton` |

**columnChoices:** `encounter`, `waiting_time`, `arrival_time`, `arrival_mode`

### Search chrome (per table)

Update `_OpdMainTable` `AppListTableSearch`:

- **Filters button label:** `l10n.commonFiltersActionLabel` if added, else keep `l10n.opdFilterAction` (already `"Filters"`).
- **Filters modal title:** `l10n.commonAdvancedFiltersTitle` — add to `app_en.arb` as `"Advanced filters"` if missing; do not use `opdFiltersLabel` for modal title.
- **Settings button:** `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
- **Settings modal title:** `columnVisibilityTitle: l10n.commonTableSettingsTitle` — add to `app_en.arb` as `"Table Settings"` if missing.
- Extend `matcher` / `_OpdTableItem.matches` so search covers **all** column ids including hidden `columnChoices` fields (`arrival_mode`, `encounter`, `waiting_time`, etc.) when no `searchField` is selected.
- Preserve existing `filterGroups`, `searchFields`, date presets, and `_OpdTableFilter` logic.

### Status column wiring

Replace `_QueueStatusCell` with a helper (e.g. `_opdStatusBadge(BuildContext, _OpdTableItem)`) that returns:

```dart
AppWorkspaceStatusBadge(
  status: AppWorkspaceStatus(
    label: _queueStatusLabel(context, item), // existing formatter
    tone: item.category == _opdCategoryTriage
        ? appTriageToneForValue(item.status)
        : _stageTone(item.status ?? item.flow?.stage),
  ),
)
```

Use column id `status`, label `l10n.opdStatusColumnLabel`. Remove separate `queueStatus` id.

### Next-action wiring

Replace `_NextStepCell` with `_opdNextActionColumn` pattern (mirror `emergencyNextActionColumn`):

- Column id: `next_action`
- `alwaysVisible: true`
- Label: prefer `l10n.commonNextActionLabel` (`"Next"`) or add `opdNextActionColumnLabel`: `"Next action"` — **not** `"Next step"`.
- Cell builder:

```dart
WorkflowActionButton(
  encounterId: flow?.publicId ?? flow?.id ?? item.encounterId ?? item.id,
  patientId: flow?.patientId ?? appointment?.patientId ?? queueEntry?.patientId,
  queueEntryId: queueEntry?.id,
  stage: flow?.stage ?? item.status,
  nextStep: item.nextStep,
  displayNextStep: flow?.displayNextStep,
  assignedStaffId: flow?.providerUserId,
  sourceModule: 'opd',
  compact: true,
)
```

For rows **without** a resolvable workflow action (e.g. scheduled appointment before check-in), show an explicit labeled button (not generic `"Action"`) that opens the same destination as row tap — e.g. `AppButton` with `l10n.opdCheckInAction` or `l10n.opdStartWalkInAction` calling the same handler as `_OpdPatientActionsDialog` primary action. Stop propagation so row tap is not double-fired.

### Row interaction

- Keep `onRowSelected` → `_openTableItemActions`.
- Ensure next-action column buttons open **the same dialogs** as row tap ( `FlowActionsDialog`, `_OpdPatientActionsDialog`, nested `QueueActionsDialog` / `OpdRescheduleAppointmentDialog` ).
- Do not navigate to generic `/opd` home from action buttons.

### Mobile row (`_OpdTableMobileRow`)

Refactor to mirror desktop priority fields:

- Title: patient name; subtitle: MRN | arrival mode | waiting time (use `AppListItemText` or existing `_joinDisplay`).
- Details row: `AppWorkspaceStatusBadge` + compact `WorkflowActionButton` (same params as table column).
- Preserve chevron / row tap → `_openTableItemActions`.

## Implementation Steps

### 1. Add shared l10n keys (`frontend/lib/l10n/app_en.arb` only)

Add if absent:

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"opdNextActionColumnLabel": "Next action"
```

Run codegen: `cd frontend && flutter gen-l10n` (or project-standard l10n command).

### 2. Refactor `_OpdTableColumnId` and column builders

**File:** `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

- Replace `patientNumber` + `patientName` with single `patient` id; implement via `AppListItemText` (`frontend/lib/shared/components/app_list_item_text.dart`).
- Rename `queueStatus` → `status`, `nextStep` → `next_action`.
- Update `_opdDefaultColumnsForSection` to the Target Architecture tables (≤5 each).
- Update `_availableOpdTableColumns` / `columnChoices` to exclude ids already in defaults for that tab (avoid duplicate choices) — follow `AppListTable` pattern from reception/mortuary.
- Update `_opdTableColumnLabel`, `_opdSortComparator`, `_opdDataColumn` switches for new ids.
- Mark `next_action` column `alwaysVisible: true`.

### 3. Status badge migration

- Delete or repurpose `_QueueStatusCell`; use `AppWorkspaceStatusBadge` from `frontend/lib/shared/components/components.dart`.
- Import `appTriageToneForValue` if not already available via shared triage helpers.

### 4. Next-action column migration

- Refactor `_NextStepCell` to always show an explicit action control ( `WorkflowActionButton` or contextual `AppButton` ).
- Set `sourceModule: 'opd'` on `WorkflowActionButton`.
- Pass `queueEntryId` for queue-only rows.

### 5. Search chrome standardization

In `_OpdMainTable`:

```dart
columnVisibilityTitle: l10n.commonTableSettingsTitle,
// AppListTableSearch:
advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
advancedFilterButtonLabel: l10n.commonFiltersActionLabel, // or opdFilterAction
```

Verify `flutter test` still finds `find.byTooltip('Filters')` and Settings icon.

### 6. Mobile parity

Update `_OpdTableMobileRow` with status badge + workflow action button as described above.

### 7. Preserve non-table behavior

Do **not** change:

- `OpdWorkspaceController` / repository / realtime applier
- Tab strip labels (`opdSectionAllLabel`, etc.) — validated against `OpdWorkspaceSection` enum
- Toolbar primary `opdStartWalkInAction` and secondary Refresh
- `_OpdTableFilter`, `_opdFilterForPanel`, deep-link `OpdWorkspaceQuery` handling
- `_OpdPatientActionsDialog`, `QueueActionsDialog`, permission gates (`opdFrontDeskActionRequirement`, `opdEncounterPermissionRequirement`)
- Row color `_opdTableRowColor`, pagination `_tablePage`, sort order in `_tableItems`

### 8. Update tests

**File:** `frontend/test/features/opd/presentation/opd_workspace_page_test.dart`

- Adjust column-related expectations if tests assert column headers.
- Add/adjust tests: Settings opens with title **Table Settings**; Filters modal title **Advanced filters**; triage/active tabs render ≤5 default data columns (excluding auto row-number); mobile layout shows status + action.
- Keep existing tab filter, deep-link, and search tests passing.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Patient name + MRN column |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `components.dart` | Status column (pos 4) |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-action column (pos 5) |
| `FlowActionsDialog` | `package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart` | Flow row detail |
| `opdStageDisplayLabel` / `opdNextStepDisplayLabel` / `opdStatusDisplayLabel` | `package:hosspi_hms/shared/opd_actions/opd_status_display.dart` | Status/action labels |
| `appTriageToneForValue` | shared triage display helper (already used in file) | Triage status tones |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/opd/presentation/opd_workspace_page_test.dart` |
| Modify | Generated l10n outputs (via codegen) |
| Delete | None expected |

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`, `commonNextActionLabel`.
- Replace `opdNextStepColumnLabel` usage in table header with `opdNextActionColumnLabel` or `commonNextActionLabel`.

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/opd/
```

## Testing Requirements

- [ ] Each tab: search chrome shows only Filters and Settings (no export/refresh in search bar)
- [ ] Filters modal title is **Advanced filters**; Settings modal title is **Table Settings**
- [ ] Column visibility persists per `opd_<section>` storage key
- [ ] ≤5 default columns per tab; row number is automatic only
- [ ] Patient column is single field with two-line name/MRN
- [ ] Status column uses `AppWorkspaceStatusBadge`; next-action uses explicit `WorkflowActionButton` or contextual labeled button
- [ ] Row tap opens `FlowActionsDialog` or `_OpdPatientActionsDialog`
- [ ] Mobile list shows same priority fields, status badge, and action control
- [ ] Realtime refresh still updates rows after controller mutations
- [ ] Permissions still gate write actions in dialogs and workflow buttons

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for `_OpdMainTable` on every `OpdWorkspaceSection` tab
- [ ] Domain logic, routing, filters, and permissions preserved
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/opd/` passes
