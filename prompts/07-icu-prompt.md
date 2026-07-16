# Standardize ICU Tables

## Objective

Refactor every `AppListTable` on the ICU workspace (`/icu`, `IcuWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation. Refresh stays in the tab toolbar (`AppTabToolbarAction`); do not move it into table search chrome.

## Current State (from audit)

### Screen layout

| Item | Value |
|------|-------|
| Route | `/icu` (`AppRoutes.icu`) |
| Page | `IcuWorkspacePage` — `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` |
| Controller | `icuWorkspaceControllerProvider` — `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart` |
| Entity (board) | `IcuPatientSummary` — `frontend/lib/features/icu/domain/entities/icu_entities.dart` |
| Board data | `state.board` (`AppPage<IcuPatientSummary>`), scoped by `IcuBoardQuery.scope` via tab → `applyScope` |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.icu` + adaptive polling (8s) — already wired; preserve |
| Write gate | `_IcuWorkspaceContent.writeRequirement` — `clinicalWrite` or `emergencyWrite` + `icu-critical-care` module |
| Row detail | `_openIcuDetailDialog` → `AppDialog` + `_IcuDetailPanel` (inline in same file) |
| Bed board tab | `IcuBedBoardPanel` — **not** an `AppListTable`; out of scope |

### Tabs (`IcuWorkspaceSection`)

| Tab id | l10n label | `IcuBoardScope` | Server filter (repository) |
|--------|------------|-----------------|----------------------------|
| `active` | `icuActiveIcuLabel` | `active` | default active ICU |
| `critical` | `icuCriticalAlertsLabel` | `critical` | `has_critical_alert=true` |
| `transfers` | `icuTransfersLabel` | `transfer` | `transfer_status=REQUESTED` |
| `discharge` | `icuDischargeReadyLabel` | `discharge` | `stage=DISCHARGE_PLANNED` |
| `ended` | `icuEndedStaysLabel` | `ended` | `icu_status=ENDED` |
| `all` | `icuAllIcuLabel` | `all` | no extra scope filter |
| `beds` | `icuViewBedBoard` | *(none — bed board panel)* | N/A |

Deep links: `?section=<tabId>` (not `scope`), `?id=<admissionDisplayId>`, `?panel=<vitals|alerts|observations|orders|transfer|discharge>`.

### Table 1: `_IcuBoardPanel`

| Attribute | Current value |
|-----------|---------------|
| Widget | `_IcuBoardPanel` (private, same file as page) |
| File | `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` (lines ~384–550) |
| Entity | `IcuPatientSummary` |
| Shown on | All board tabs except `beds` |
| `columnVisibilityStorageKey` | `'icu_board'` ✓ |
| `columnWidthStorageKey` | `'icu_cw_board'` ✓ |
| `columnVisibilityLabel` | `l10n.commonTableSettingsActionLabel` ✓ |
| `columnVisibilityTitle` | **missing** |
| `columnVisibilityController` | Created in `_IcuWorkspaceContentState`, passed in ✓ |
| `displayMode` | **missing** (defaults to adaptive — set explicitly) |
| `columnChoices` | **missing** |
| `onRowSelected` | `_openIcuDetailDialog` ✓ |
| `rowColorBuilder` | Critical-alert highlight ✓ — preserve |

**Current columns (7 — exceeds budget of 5):**

| # | Label (l10n) | id today | Field(s) | Cell pattern | Gap |
|---|--------------|----------|----------|--------------|-----|
| 1 | `opdPatientColumnLabel` | *(none)* | `displayTitle` + `displayId` | `_IcuPatientCell` two-line | OK (one field, two tiers) |
| 2 | `icuColumnBedLabel` | *(none)* | `locationLabel` | `Text` | OK |
| 3 | `icuColumnSourceLabel` | *(none)* | `sourceLabel` | `Text(apiLabel(...))` | OK |
| 4 | `icuColumnAlertLabel` | *(none)* | `criticalSeverity` / `hasCriticalAlert` | `AppWorkspaceStatusBadge(alertStatus)` | Duplicate status semantics |
| 5 | `opdStatusColumnLabel` | *(none)* | `icuStatus` | `AppWorkspaceStatusBadge(icuStatus)` | Should be sole status column (pos 4) |
| 6 | `icuColumnStartLabel` | *(none)* | `boardIcuStartAt` | `dateTimeLabel` | Move to `columnChoices` |
| 7 | `icuColumnTransferLabel` | *(none)* | `transferStatus` / `nextStep` | plain `Text` | Should be next-action button, not data column |

**Search chrome gaps:**

| Issue | Detail |
|-------|--------|
| Broken matcher | `matcher: (_, _) => true` — search does not filter rows |
| No Filters | `showAdvancedFilterButton` not set |
| No Settings title | `columnVisibilityTitle` not set to **Table Settings** |
| No `onClear` | Missing `onClear: () => controller.applySearch('')` |
| Entity has matcher | `IcuPatientSummary.matchesSearch(String)` already implements full-field search — use it |

**Mobile gaps:**

- Shows patient + alert badge + icu status + location/admitted — **missing explicit next-action control**
- No parity with desktop priority columns per tab

**Workflow / next-action gaps:**

- No `WorkflowActionButton` or ICU inline action button
- Transfer column shows raw `transferStatus ?? nextStep` text instead of verb label
- `WorkflowActionRegistry` has IPD codes (`ASSIGN_BED`, `APPROVE_TRANSFER`, `RECORD_NURSING_NOTE`, etc.) but **no ICU-specific registrations**; ICU board rows come from IPD flow API (`include_icu=true`) with `nextStep` on `IcuPatientSummary`
- `_IcuActionPanel` already defines the canonical ICU action set and dialog openers (`_openObservationDialog`, `_openManageTransferDialog`, `_confirmAction` for start/end stay, etc.)

**Per-tab column gap:**

- `_IcuBoardPanel` does **not** receive `IcuWorkspaceSection`; same 7 columns render on every tab instead of tab-prioritized defaults (see nursing pattern).

---

## Reference Implementation

Copy patterns from:

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, `AppListTableColumn`, `AppListTableColumnVisibilityController`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters + Settings chrome, `columnVisibilityTitle`, `showAdvancedFilterButton`
- `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart` — scope-aware columns, filters, mobile parity, detail dialog on row select
- `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_columns.dart` — `nursingColumnsForScope` / `nursingColumnChoicesForScope`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton`
- `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` — `WorkflowActionButton` with `sourceModule: 'ipd'`, `admissionId`, `nextStep`
- `frontend/lib/features/icu/presentation/widgets/icu_format.dart` — `icuStatus`, `alertStatus`, `apiLabel`, `dateTimeLabel`
- `prompt.md`

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `IcuBoardPanel` (extract from `_IcuBoardPanel`) | `active`, `critical`, `transfers`, `discharge`, `ended`, `all` | `IcuPatientSummary` | Scope-specific (see below) | `icu_board` |
| *(none)* | `beds` | — | `IcuBedBoardPanel` — not `AppListTable` | — |

Pass `IcuWorkspaceSection section` into the board panel so columns can vary per tab (mirror `NursingWorklistPanel` + `scope`).

### Column plan — default visible columns per tab

Row number is automatic. Every column must have a stable `id`. Positions 4–5 are **status** then **next action** (workflow entity).

#### `active` / `all`

| Position | id | Label | Source | Notes |
|----------|-----|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | `displayTitle` / `displayId` | `_IcuPatientCell` |
| 2 | `bed` | `icuColumnBedLabel` | `locationLabel` | |
| 3 | `source` | `icuColumnSourceLabel` | `sourceLabel` | `apiLabel` when non-empty |
| 4 | `status` | `opdStatusColumnLabel` | `icuStatus` | `AppWorkspaceStatusBadge(icuStatus(item))` |
| 5 | `next_action` | `icuNextActionColumnLabel` *(new)* | `nextStep` + eligibility | `IcuNextActionButton` — see § Next action |

#### `critical`

| Position | id | Label | Source | Notes |
|----------|-----|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | patient | `_IcuPatientCell` |
| 2 | `bed` | `icuColumnBedLabel` | `locationLabel` | |
| 3 | `alert` | `icuColumnAlertLabel` | `criticalSeverity` | `AppWorkspaceStatusBadge(alertStatus(l10n, item))` — triage priority |
| 4 | `status` | `opdStatusColumnLabel` | `icuStatus` | workflow status |
| 5 | `next_action` | `icuNextActionColumnLabel` | — | Prefer **Acknowledge alert** when `hasCriticalAlert`; else `IcuNextActionButton` |

#### `transfers`

| Position | id | Label | Source | Notes |
|----------|-----|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | patient | |
| 2 | `bed` | `icuColumnBedLabel` | location | |
| 3 | `transfer` | `icuColumnTransferLabel` | `transferStatus` | `apiLabel(transferStatus)` — single semantic field |
| 4 | `status` | `opdStatusColumnLabel` | `icuStatus` | |
| 5 | `next_action` | `icuNextActionColumnLabel` | — | **Manage transfer** when `hasOpenTransfer`; else **Request transfer** |

#### `discharge`

| Position | id | Label | Source | Notes |
|----------|-----|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | patient | |
| 2 | `bed` | `icuColumnBedLabel` | location | |
| 3 | `admitted` | `icuAdmittedLabel` | `admittedAt` | `dateTimeLabel` — discharge tab prioritizes timeline |
| 4 | `status` | `opdStatusColumnLabel` | `icuStatus` / discharge | Include discharge-planned tone when `isDischargePlanned` |
| 5 | `next_action` | `icuNextActionColumnLabel` | — | **Discharge readiness** or **Open discharge clearance** per state |

#### `ended`

| Position | id | Label | Source | Notes |
|----------|-----|-------|--------|-------|
| 1 | `patient` | `opdPatientColumnLabel` | patient | |
| 2 | `bed` | `icuColumnBedLabel` | last location | |
| 3 | `icu_start` | `icuColumnStartLabel` | `boardIcuStartAt` | |
| 4 | `status` | `opdStatusColumnLabel` | `icuStatus` | typically ENDED |
| 5 | `next_action` | `icuNextActionColumnLabel` | — | **Open in IPD** (`icuActionOpenIpd`) — deep-link `AppRoutes.ipd` with admission id |

### `columnChoices` (hidden by default — all tabs)

Expose via Settings; include every field searchable by `matchesSearch`:

| id | Label | Field |
|----|-------|-------|
| `alert` | `icuColumnAlertLabel` | alert severity *(if not default on tab)* |
| `source` | `icuColumnSourceLabel` | source |
| `icu_start` | `icuColumnStartLabel` | `boardIcuStartAt` |
| `transfer` | `icuColumnTransferLabel` | `transferStatus` |
| `admitted` | `icuAdmittedLabel` | `admittedAt` |
| `encounter` | *(reuse `icuAdmissionLabel` or add `icuEncounterColumnLabel`)* | `encounterId` / `displayId` |

Do not duplicate columns already in the tab's default five.

### Search chrome (per table)

```dart
search: AppListTableSearch<IcuPatientSummary>(
  controller: searchController,
  semanticLabel: l10n.icuSearchHint,
  hintText: l10n.icuSearchHint,
  matcher: (IcuPatientSummary item, String query) => item.matchesSearch(query),
  onSubmitted: controller.applySearch,
  onClear: () => controller.applySearch(''),
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.icuAdvancedFiltersLabel,       // "Filters"
  advancedFilterTitle: l10n.icuAdvancedFiltersTitle,             // "Advanced filters"
  advancedFilterApplyLabel: l10n.icuApplyFiltersLabel,
  advancedFilterResetLabel: l10n.icuResetFiltersLabel,
  // client-side filters on current page (no API change):
  filterGroups: icuBoardFilterGroups(l10n),
  filterValue: filterValue,
  hasActiveFilters: filterValue.hasActiveSelection,
  onFilterChanged: onBoardFilterChanged,
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.icuTableSettingsTitle,                 // "Table Settings"
displayMode: AppListTableDisplayMode.adaptive,
```

**Advanced filter groups** (`icu_board_filters.dart`) — client-side refinement within the active tab's loaded page (do not change `IcuBoardQuery` / API):

| Group id | Label | Options | Match logic |
|----------|-------|---------|-------------|
| `alert` | `icuColumnAlertLabel` | All / Has alert / No alert | `hasCriticalAlert` |
| `bed` | `icuColumnBedLabel` | All / Has bed / No bed | `hasActiveBed` |
| `source` | `icuColumnSourceLabel` | All / Emergency / Other | `sourceLabel` contains `EMERGENCY` |

Wire `filterValue` + `onBoardFilterChanged` in `_IcuWorkspaceContentState` (mirror nursing's `AppSearchBarFilterValue` pattern). Apply client-side filter in the panel by filtering `page.items` before passing to `AppListTable`, **or** use `AppListTableSearch` built-in filter application if the table supports it — match nursing's approach.

### Next action — `IcuNextActionButton`

Create `frontend/lib/features/icu/presentation/widgets/icu_next_action_button.dart`.

**Resolution order** (first match wins; use existing l10n action labels — never generic "Action" / "Next step"):

| Condition | Label (l10n) | Handler |
|-----------|--------------|---------|
| `summary.nextStep` maps to IPD `WorkflowActionRegistry` code | registry label | `WorkflowActionButton(encounterId: summary.encounterId ?? summary.id, patientId: summary.patientId, admissionId: summary.admissionId, nextStep: summary.nextStep, stage: summary.stage, sourceModule: 'ipd', compact: true)` |
| No active stay + eligible (`icuStatus != ACTIVE`, admission not discharged) | `icuActionStartStay` | Select patient → `_confirmAction` / `controller.startIcuStay` |
| `hasCriticalAlert` | `icuActionAcknowledgeAlert` | Select patient → `controller.acknowledgeLatestAlert` confirm |
| `hasOpenTransfer` | `icuActionManageTransfer` | Select patient → `_openManageTransferDialog` |
| `isDischargePlanned` | `icuActionOpenDischargeClearance` | Deep-link IPD discharge panel |
| `!hasActiveBed` | `icuActionAssignBed` | Select patient → `_openAssignBedDialog` |
| `isEndedIcu` | `icuActionOpenIpd` | `AppRoutes.ipd` with `displayId` |
| Active stay, default | `icuActionRecordObservation` or API `nextStep` display | Select patient → `_openObservationDialog` or detail dialog |

Wrap in `AppAccessActionGate(requirement: writeRequirement)` for write actions. Use `GestureDetector` / `AppButton` compact style matching `WorkflowActionButton` compact mode. **Stop propagation** so row tap does not also fire.

Extract shared dialog openers from `icu_workspace_page.dart` into `frontend/lib/features/icu/presentation/widgets/icu_action_dialogs.dart` (or similar) so the button and detail panel reuse the same functions — do not duplicate dialog UIs.

### Row interaction

- Keep `onRowSelected` → `_openIcuDetailDialog(context, ref, state, summary, writeRequirement)`
- Next-action button must open the **same** dialog/handler as the matching item in `_IcuActionPanel`
- Preserve deep-link flow in `IcuWorkspacePage._handleDeepLink`

### Mobile `mobileItemBuilder`

Per tab, mirror desktop priority:

1. `_IcuPatientCell`
2. `Wrap` with: priority data chip/text for tab (bed, alert, transfer, etc.)
3. `AppWorkspaceStatusBadge(icuStatus(item))`
4. `IcuNextActionButton` (compact)

---

## Implementation Steps

### 1. Extract board panel and column modules

**Create** `frontend/lib/features/icu/presentation/widgets/icu_board_panel.dart`:

- Move `_IcuBoardPanel` → public `IcuBoardPanel`
- Add parameters: `IcuWorkspaceSection section`, `AppSearchBarFilterValue filterValue`, `ValueChanged<AppSearchBarFilterValue> onFilterChanged`, `AccessRequirement writeRequirement`
- Import column/filter/next-action widgets

**Create** `frontend/lib/features/icu/presentation/widgets/icu_board_columns.dart`:

- `List<AppListTableColumn<IcuPatientSummary>> icuColumnsForSection(AppLocalizations l10n, IcuWorkspaceSection section, {required AccessRequirement writeRequirement})`
- `List<AppListTableColumn<IcuPatientSummary>> icuColumnChoicesForSection(AppLocalizations l10n, IcuWorkspaceSection section, {required AccessRequirement writeRequirement})`
- Move `_IcuPatientCell` here (or `icu_patient_cell.dart`)

**Create** `frontend/lib/features/icu/presentation/widgets/icu_board_filters.dart`:

- `List<AppSearchBarFilterGroup> icuBoardFilterGroups(AppLocalizations l10n)`
- Client-side filter application helper

**Create** `frontend/lib/features/icu/presentation/widgets/icu_next_action_button.dart`:

- `IcuNextActionButton` widget per § Next action

**Create** `frontend/lib/features/icu/presentation/widgets/icu_action_dialogs.dart`:

- Extract dialog openers + `_openIcuDetailDialog` from page (keep page thin)

### 2. Refactor `icu_workspace_page.dart`

- Replace inline `_IcuBoardPanel` with `IcuBoardPanel(section: _section, ...)`
- Add `AppSearchBarFilterValue _boardFilterValue` state + handler in `_IcuWorkspaceContentState`
- Remove moved widgets; import new files
- Keep `_IcuDetailPanel`, `_IcuActionPanel`, and tab strip unchanged except imports

### 3. Wire compliant `AppListTable` in `IcuBoardPanel`

- `columns: icuColumnsForSection(l10n, section, writeRequirement: writeRequirement)`
- `columnChoices: icuColumnChoicesForSection(...)`
- Fix search matcher to `item.matchesSearch(query)`
- Add Filters + Settings chrome per § Search chrome
- `displayMode: AppListTableDisplayMode.adaptive`
- Update `mobileItemBuilder` with next-action parity
- Preserve `rowColorBuilder`, pagination, `onRowSelected`, storage keys

### 4. l10n (`frontend/lib/l10n/app_en.arb` only)

Add keys (English exactly as required by `prompt.md`):

```json
"icuAdvancedFiltersLabel": "Filters",
"icuAdvancedFiltersTitle": "Advanced filters",
"icuApplyFiltersLabel": "Apply filters",
"icuResetFiltersLabel": "Reset filters",
"icuTableSettingsTitle": "Table Settings",
"icuNextActionColumnLabel": "Next action"
```

Run codegen: `cd frontend && flutter gen-l10n` (or project-standard l10n command).

### 5. Tests

Update `frontend/test/features/icu/presentation/icu_workspace_page_test.dart`:

- Assert ≤5 default column headers visible (not 7)
- Assert **Filters** and **Settings** trailing controls in search chrome
- Assert search matcher filters rows (pump search text, expect row count change)
- Assert row tap still opens detail dialog
- Assert `IcuBoardPanel` receives section (switch to Critical tab → alert column prioritized)

Add widget tests for `icuColumnsForSection` if extracted as pure functions (optional but preferred).

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | Board table shell |
| `AppListTableSearch` | same | Search + Filters chrome |
| `AppListTableColumn` | same | Column definitions |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableDisplayMode` | same | `adaptive` |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Status column |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | IPD `nextStep` codes |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission-gated actions |
| `AppSearchBarFilterValue` / filter groups | `package:hosspi_hms/shared/components/components.dart` | Advanced filters |
| `icuStatus` / `alertStatus` | `package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart` | Status badges |
| `IcuPatientSummary.matchesSearch` | `icu_entities.dart` | Search matcher |

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| **Create** | `frontend/lib/features/icu/presentation/widgets/icu_board_panel.dart` |
| **Create** | `frontend/lib/features/icu/presentation/widgets/icu_board_columns.dart` |
| **Create** | `frontend/lib/features/icu/presentation/widgets/icu_board_filters.dart` |
| **Create** | `frontend/lib/features/icu/presentation/widgets/icu_next_action_button.dart` |
| **Create** | `frontend/lib/features/icu/presentation/widgets/icu_action_dialogs.dart` |
| **Modify** | `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` |
| **Modify** | `frontend/lib/l10n/app_en.arb` |
| **Modify** | `frontend/test/features/icu/presentation/icu_workspace_page_test.dart` |
| **Do not modify** | `IcuBedBoardPanel`, `icu_workspace_controller.dart`, repository/API layer |

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only
- Reuse `commonTableSettingsActionLabel` for Settings button label
- New keys listed in § Implementation step 4
- Prefer `icuBoardFiltersTitle` only if repurposed; new `icuAdvancedFiltersTitle` must be exactly **Advanced filters**

---

## Database Migrations

**No database migrations required — schema unchanged.** Advanced filters are client-side refinements on the loaded board page; tab scope continues to drive server queries via existing `IcuBoardQuery.scope` / `listIcuBoard` parameters.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/icu/
```

Manual smoke (web or device):

1. `/icu` → Active tab: 5 columns + row numbers; Filters + Settings only in search bar
2. Critical tab: alert column visible by default; Acknowledge action on critical rows
3. Transfers tab: Manage transfer action on open transfers
4. Settings: toggle hidden columns; refresh page — visibility persists (`icu_board` key)
5. Search "Ada" — filters rows; clear restores
6. Row tap → ICU stay dialog with action panel
7. Next-action button → same dialog as row action (no navigation to generic `/icu` home)
8. Narrow viewport: mobile cards show patient, status, next action
9. Trigger refresh / wait for realtime — board updates without reload

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per table key (`icu_board`)
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels (no raw API codes in action column)
- [ ] Row tap opens detail dialog (`icuStayDialogTitle`)
- [ ] Mobile list shows same priority fields + next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions (`writeRequirement`)
- [ ] Tab toolbar Refresh unchanged; Start ICU stay primary action unchanged

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every `AppListTable` on this screen (`IcuBoardPanel` only)
- [ ] Domain logic preserved (scope tabs, counts, deep links, dialogs, permissions, realtime)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/icu/` passes
