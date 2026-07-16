# Standardize Nursing Tables

## Objective

Refactor every `AppListTable` on the Nursing workspace (`/nursing`, `NursingWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, tab toolbar actions (Shift context, Add note, Refresh), deep-link routing, or unrelated screen chrome unless required for compilation.

---

## Current State (from audit)

### Screen topology

| Field | Value |
|-------|-------|
| Route | `/nursing` (`AppRoutes.nursing`) |
| Page widget | `NursingWorkspacePage` |
| Primary file | `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart` |
| Content widget | `_NursingWorkspaceContent` (owns tab state `_scope`, search controller, filter value) |
| Worklist widget | `NursingWorklistPanel` |
| Entity | `NursingWorkItem` (= `NursingPatientSummary`) |
| Provider | `nursingWorkspaceControllerProvider` (`NursingWorkspaceController`) |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.nursing` in controller `build()` |

**Table count:** Exactly **one** `AppListTable` instance (`NursingWorklistPanel`). Column sets vary per tab scope via `nursingColumnsForScope(l10n, scope)` — not separate table widgets.

### Tabs (7)

| Tab id (URL `scope`) | `NursingQueueScope` | l10n label key |
|----------------------|---------------------|----------------|
| `all` | `all` | `nursingScopeAllLabel` |
| `assigned-ward` | `assignedWard` | `nursingScopeAssignedWardLabel` |
| `urgent` | `urgent` | `nursingScopeUrgentLabel` |
| `medication-due` | `medicationDue` | `nursingScopeMedicationDueLabel` |
| `handover-pending` | `handoverPending` | `nursingScopeHandoverPendingLabel` |
| `transfer-pending` | `transferPending` | `nursingScopeTransferPendingLabel` |
| `discharge-pending` | `dischargePending` | `nursingScopeDischargePendingLabel` |

Deep-link query aliases accepted: `scope`, `section`, `filter`, `queue` (see `NursingWorkspaceQuery.fromUri`). Patient deep links: `?id=<admissionId>&panel=vitals|medication|handover|discharge`.

### Current columns per scope (5 each — at budget but wrong layout)

All defined in `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_columns.dart`. **None** set explicit `id` on columns (keys fall back to label strings). **No** `next_action` column on any scope.

| Scope | Col 1 | Col 2 | Col 3 | Col 4 | Col 5 |
|-------|-------|-------|-------|-------|-------|
| `all` / `assignedWard` | Patient (`NursingPatientCell`) | Location | Task type | Priority (badge) | Status (`nursingSummaryStatus`) |
| `urgent` | Patient | Priority (badge) | Location | Status | Due time |
| `medicationDue` | Patient | Med due count | Location | Due time | Status |
| `handoverPending` | Patient | Responsible nurse | Location | Status | Observations |
| `transferPending` | Patient | Location | Transfer status (badge) | Admission | Status |
| `dischargePending` | Patient | Location | Discharge status (badge) | Admission | Due time |

Hidden extras via `nursingColumnChoicesForScope`: admission, due time, responsible nurse, observations, task type, priority, location (when not in defaults).

### Search chrome (current)

File: `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart`

| Aspect | Current | Gap vs `prompt.md` |
|--------|---------|-------------------|
| Search matcher | `item.matchesSearchField(state.query.searchField, query)` | Does not search hidden `columnChoices` fields when no field filter active; should use a unified matcher covering all column-mapped attributes |
| Filters button | `advancedFilterButtonLabel: l10n.nursingAdvancedFiltersLabel` (`Filters`) | OK |
| Filters modal title | `advancedFilterTitle: l10n.nursingAdvancedFiltersTitle` (`Nursing worklist filters`) | Must be **Advanced filters** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` | OK |
| Settings modal title | Not set | Must set `columnVisibilityTitle` to **Table Settings** |
| Column visibility persistence | `columnVisibilityStorageKey: 'nursing_${scope.name}'` only | Missing explicit `AppListTableColumnVisibilityController`; add controller owned by `_NursingWorkspaceContent` (pattern: `discharge_workspace_page.dart`) |
| `displayMode` | Default (`adaptive`) | Set explicitly: `displayMode: AppListTableDisplayMode.adaptive` |
| Extra search chrome actions | None | OK |

### Row interaction (current)

- `onRowSelected` → `openNursingPatientDetailDialog(context, ref, item)` in `nursing_worklist_panel.dart` ✓
- Detail dialog: `NursingPatientDetailDialog` (`nursing_patient_detail_dialog.dart`) with vitals, medication, handover, transfer, discharge, escalation actions ✓
- **Gap:** No per-row next-action control in table or mobile list

### Mobile (current)

`mobileItemBuilder` shows `NursingPatientCell`, priority badge, status badge, and joined location/task/due text. **Missing:** explicit next-action button matching desktop column.

### Workflow / next-action mapping (domain)

`NursingPatientSummary` has `stage`, `nextStep`, `taskTypeCode` (computed), and scope-specific flags (`hasMedicationDue`, `pendingHandoverCount`, `hasPendingTransfer`, `isDischargePending`, `isUrgent`).

Per-scope primary actions already defined in `nursing_scope_navigation.dart`:

| Scope | Label key | Opens |
|-------|-----------|-------|
| `all`, `assignedWard`, `urgent` | `nursingActionRecordVitals` | `NursingVitalsDialog` |
| `medicationDue` | `nursingActionAdministerMedication` | `NursingMedicationDialog` |
| `handoverPending` | `nursingActionCreateHandover` | `NursingHandoverDialog` |
| `transferPending` | `nursingActionAcknowledgeTransfer` | `NursingTransferDialog` |
| `dischargePending` | `nursingActionDischargeClearance` | `NursingDischargeClearanceDialog` |

For `all`/`assignedWard` tabs, resolve row-level next action from `item.taskTypeCode`:

| `taskTypeCode` | Action label key | Dialog |
|----------------|------------------|--------|
| `MEDICATION_DUE` | `nursingActionAdministerMedication` | `NursingMedicationDialog` |
| `HANDOVER_PENDING` | `nursingActionCreateHandover` | `NursingHandoverDialog` |
| `TRANSFER_PENDING` | `nursingActionAcknowledgeTransfer` | `NursingTransferDialog` |
| `DISCHARGE_PENDING` | `nursingActionDischargeClearance` | `NursingDischargeClearanceDialog` |
| default | `nursingActionRecordVitals` | `NursingVitalsDialog` |

Use `WorkflowActionButton` only when `item.nextStep` maps to a registered workflow code (e.g. `RECORD_VITALS`); otherwise use a compact `AppButton` / `TextButton` that opens the nursing dialog directly (pattern: IPD `_BedActionMenu` in `ipd_bed_board_panel.dart`). Always `selectPatient` before opening detail-dependent dialogs (same as `openNursingPatientDetailDialog`).

---

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — column visibility controller, search chrome, adaptive layout
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` Filters/Settings wiring
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, `WorkflowActionButton`
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — `_columnVisibilityController`, status + next-action columns
- `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart` — module-specific compact action in next-action column
- `prompt.md`

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `NursingWorklistPanel` | Per `NursingQueueScope` tab | `NursingWorkItem` | See column plan below | `nursing_${scope.name}` |
| | | | | `columnWidthStorageKey`: `nursing_cw_${scope.name}` |

### Column plan (per scope)

Apply layout: **3 priority data columns + status (col 4) + next_action (col 5, `alwaysVisible: true`)**. Move displaced columns to `columnChoices`.

Add stable column `id` on every column (required for visibility persistence across l10n changes).

#### `all` / `assignedWard`

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | `displayTitle` + subtitle IDs | `NursingPatientCell` (allowed two-line) |
| 2 | `location` | `nursingLocationColumnLabel` | `locationLabel` | |
| 3 | `task_type` | `nursingTaskTypeColumnLabel` | `taskTypeCode` | `nursingTaskTypeLabel` |
| 4 | `status` | `opdStatusColumnLabel` | `stage` / `admissionStatus` | `AppWorkspaceStatusBadge` via `nursingSummaryStatus` |
| 5 | `next_action` | `nursingNextActionColumnLabel` | resolved action | `nursingNextActionColumn(scope)` |

Move to `columnChoices`: `priority`, `admission`, `due_time`, `responsible_nurse`, `observations`, `medication_due_count`, `transfer_status`, `discharge_status`.

#### `urgent`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | Patient | | |
| 2 | `priority` | `nursingPriorityColumnLabel` | `priorityCode` | Badge — triage-critical for this tab |
| 3 | `location` | Location | | |
| 4 | `status` | Status | `nursingSummaryStatus` | |
| 5 | `next_action` | Next action | `nursingActionRecordVitals` or `nursingActionEscalate` when `hasCriticalAlert` | |

Move to choices: `due_time`, `task_type`, `admission`, `observations`.

#### `medicationDue`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | Patient | | |
| 2 | `medication_due_count` | `nursingMedicationDueSummaryLabel` | `medicationDueCount` | |
| 3 | `location` | Location | | |
| 4 | `status` | Status | medication-specific status or `nursingSummaryStatus` | |
| 5 | `next_action` | Next action | `nursingActionAdministerMedication` | Opens `NursingMedicationDialog` |

Move to choices: `due_time`, `task_type`, `priority`, `admission`.

#### `handoverPending`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | Patient | | |
| 2 | `responsible_nurse` | `nursingResponsibleNurseColumnLabel` | handover state | |
| 3 | `location` | Location | | |
| 4 | `status` | Status | handover pending badge | |
| 5 | `next_action` | Next action | `nursingActionCreateHandover` or `nursingActionAcceptHandover` when applicable | |

Move to choices: `observations`, `due_time`, `admission`, `priority`.

#### `transferPending`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | Patient | | |
| 2 | `location` | Location | | |
| 3 | `transfer_status` | `nursingTransferPendingSummaryLabel` | `transferStatus` | Badge |
| 4 | `status` | Status | `nursingSummaryStatus` | Admission/workflow status |
| 5 | `next_action` | Next action | `nursingActionAcknowledgeTransfer` | Opens `NursingTransferDialog` |

Move to choices: `admission`, `due_time`, `priority`, `task_type`.

#### `dischargePending`

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `patient` | Patient | | |
| 2 | `location` | Location | | |
| 3 | `discharge_status` | `dischargeStatusFilterLabel` | `dischargeStatus` | Badge |
| 4 | `status` | Status | `nursingSummaryStatus` | |
| 5 | `next_action` | Next action | `nursingActionDischargeClearance` | Opens `NursingDischargeClearanceDialog` |

Move to choices: `admission`, `due_time`, `priority`, `task_type`.

### Search chrome (per table)

In `NursingWorklistPanel`:

```dart
search: AppListTableSearch<NursingWorkItem>(
  // ...existing filter wiring...
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel, // or keep nursingAdvancedFiltersLabel if already "Filters"
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,   // "Advanced filters"
  matcher: nursingWorklistSearchMatcher, // new: matches all column + choice fields
),
columnVisibilityController: columnVisibilityController,
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle, // "Table Settings"
columnVisibilityStorageKey: 'nursing_${scope.name}',
displayMode: AppListTableDisplayMode.adaptive,
```

Implement `nursingWorklistSearchMatcher(NursingWorkItem item, String query)` in `nursing_worklist_filters.dart` (or `nursing_helpers.dart`) that delegates to `item.matchesSearch(query)` plus any choice-only fields (`assignedNurse`, `shift`, filter group values) so hidden columns remain searchable.

### Row interaction

- Keep `onRowSelected` → `openNursingPatientDetailDialog`
- New `nursingNextActionColumn(NursingQueueScope scope)` in `nursing_worklist_columns.dart`:
  - `id: 'next_action'`, `alwaysVisible: true`
  - `cellBuilder` renders compact action button with explicit verb label
  - `onPressed`: call shared helper `nursingExecuteRowAction(context, ref, item, scope)` that selects patient then opens the same dialog as the tab primary action
  - Gate write actions with same `AccessRequirement` as `_NursingWorkspaceContent.writeRequirement`

### Mobile parity

Refactor `mobileItemBuilder` to extract `_NursingMobileListItem` widget showing:
1. `NursingPatientCell`
2. Priority + status badges (when in default or choice-visible set for active scope)
3. Location / scope-relevant subtitle
4. Trailing compact next-action control (same handler as column)

---

## Implementation Steps

### 1. Add column visibility controller to page state

**File:** `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

- In `_NursingWorkspaceContentState`, add:
  ```dart
  late final AppListTableColumnVisibilityController<NursingWorkItem> _columnVisibilityController;
  ```
- Initialize in `initState`, dispose in `dispose` (copy `_DischargeWorkspaceContentState` pattern).
- Pass `_columnVisibilityController` to `NursingWorklistPanel`.

### 2. Add next-action column and reorder columns

**File:** `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_columns.dart`

- Add `id` to every existing column factory.
- Add `nursingNextActionColumn(BuildContext context, WidgetRef ref, NursingQueueScope scope)`.
- Add `nursingResolveNextActionLabel(AppLocalizations l10n, NursingWorkItem item, NursingQueueScope scope)`.
- Rewrite `nursingColumnsForScope` per target column plans above (≤5 defaults each).
- Update `nursingColumnChoicesForScope` to include all non-default columns without duplicating defaults.

**New file (optional, if cleaner):** `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_actions.dart`
- `Future<void> nursingExecuteRowAction(BuildContext context, WidgetRef ref, NursingWorkItem item, NursingQueueScope scope)`
- Reuse dialog open helpers from `nursing_workspace_page.dart` (extract shared openers to `nursing_helpers.dart` or the new file to avoid duplication).

### 3. Standardize search chrome and wire controller

**File:** `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart`

- Accept `AppListTableColumnVisibilityController<NursingWorkItem> columnVisibilityController`.
- Wire `columnVisibilityController`, `columnVisibilityTitle`, `displayMode`.
- Replace filter modal title with shared l10n key.
- Replace search `matcher` with full-field matcher.
- Update `mobileItemBuilder` to `_NursingMobileListItem` with next-action parity.

### 4. Unified search matcher

**File:** `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_filters.dart`

- Add `bool nursingWorklistSearchMatcher(NursingWorkItem item, String query)` using `item.matchesSearch(query)` (already covers most fields on `NursingPatientSummary`).

### 5. l10n

**File:** `frontend/lib/l10n/app_en.arb`

Add keys (English only per locale rule):

```json
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"nursingNextActionColumnLabel": "Next action"
```

- Update `nursing_worklist_panel.dart` to use `commonAdvancedFiltersTitle` for `advancedFilterTitle`.
- Run codegen: `cd frontend && flutter gen-l10n` (or project-standard l10n command).

### 6. Update tests

**Files:**
- `frontend/test/features/nursing/presentation/nursing_workspace_navigation_test.dart` — update `nursingColumnsForScope` expectations: every scope includes `nursingNextActionColumnLabel`; scopes that lost a default column no longer assert removed labels.
- `frontend/test/features/nursing/presentation/nursing_workspace_page_test.dart` — verify Settings/ Filters labels, row tap opens dialog, next-action button present.
- Add tests for `nursingResolveNextActionLabel` per `taskTypeCode` if extracted.

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | Worklist table |
| `AppListTableColumn` | same | Column definitions |
| `AppListTableSearch` | same | Search + Filters chrome |
| `AppListTableColumnVisibilityController` | `app_list_table.dart` | Session column visibility |
| `AppListTableDisplayMode` | same | `adaptive` |
| `AppWorkspaceStatusBadge` | same | Status column (col 4) |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | When `nextStep` matches registry (optional fallback) |
| `AppButton` / `TextButton` | `components.dart` | Compact nursing-specific next actions |
| `NursingPatientCell` | `nursing_patient_cell.dart` | Patient column two-line cell |
| `openNursingPatientDetailDialog` | `nursing_worklist_panel.dart` | Row selection |
| `NursingPatientDetailDialog` | `nursing_patient_detail_dialog.dart` | Detail modal |

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart` |
| Modify | `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart` |
| Modify | `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_columns.dart` |
| Modify | `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_filters.dart` |
| Create (optional) | `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_actions.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/nursing/presentation/nursing_workspace_navigation_test.dart` |
| Modify | `frontend/test/features/nursing/presentation/nursing_workspace_page_test.dart` |

No files to delete.

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- Prefer new shared keys: `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`.
- Add module key: `nursingNextActionColumnLabel`.
- Keep `commonTableSettingsActionLabel` for the Settings **button** label.
- Use `commonAdvancedFiltersTitle` for the Filters **modal title** (not `nursingAdvancedFiltersTitle`).

---

## Database Migrations

No database migrations required — schema unchanged. All changes are Flutter presentation-layer table chrome, columns, and row interactions.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/nursing/
```

Manual smoke (web or device):

1. Open `/nursing` — All tab shows ≤5 data columns + row number; Settings opens **Table Settings**; Filters opens **Advanced filters**.
2. Switch each tab — column set changes; storage keys differ per scope (`nursing_urgent`, etc.).
3. Row tap opens `NursingPatientDetailDialog`.
4. Next-action column shows explicit verb (e.g. **Record vitals**, **Administer medication**); press opens correct dialog without navigating to module home.
5. Narrow viewport — mobile cards show patient, status, and next action.
6. Trigger vitals save — worklist refreshes via provider (no manual refresh required).

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per table key (`nursing_<scope>`)
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status (col 4) + next-action (col 5) labels
- [ ] Row tap opens detail dialog
- [ ] Mobile list shows same priority fields and next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions (`AppAccessActionGate` / `writeRequirement`)

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every scope variant of `NursingWorklistPanel`
- [ ] Domain logic preserved (tab counts, filters, deep links, dialogs, permissions)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/nursing/` passes
