# Standardize Emergency Tables

## Objective

Refactor every `AppListTable` on the Emergency workspace (`/emergency`, `EmergencyWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, unrelated screen chrome (tab strip, Quick arrival, Refresh toolbar actions), or repository/controller mutation logic unless required for compilation.

---

## Current State (from audit)

### Screen inventory

| Field | Value |
|-------|-------|
| Route | `/emergency` |
| Page widget | `EmergencyWorkspacePage` |
| Content state | `_EmergencyWorkspaceContentState` |
| Primary file | `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart` |
| Entity | `EmergencyCaseSummary` |
| Provider | `emergencyWorkspaceControllerProvider` (`EmergencyWorkspaceController`) |
| Detail dialog | `openEmergencyDetailDialog` in `emergency_workspace_widgets.dart` |
| Deep link | `?scope=<tabName>` (`active`, `critical`, `ambulance`, `handoff`, `closed`, `all`); also `?id=`, `?search=`, `?panel=` |

There is **one** `AppListTable<EmergencyCaseSummary>` instance in `_EmergencyWorkspaceContentState.build()`. Tab switches call `_columnsForTab(_currentTab)` and filter rows via `_buildRows(state)` — not separate table widgets.

### Tabs (`EmergencyBoardTab`)

| Tab | Label (`emergencyTabLabel`) | Row filter | Toolbar primary |
|-----|----------------------------|------------|-----------------|
| `active` | `EmergencyText.activeCases` | `item.isOpen` | Quick arrival |
| `critical` | `EmergencyText.critical` | `item.isOpen && item.isCritical` | Quick arrival |
| `ambulance` | `EmergencyText.ambulance` | `item.hasAmbulanceActivity` | Quick arrival |
| `handoff` | `EmergencyText.handoffReady` | `item.isReadyForHandoff` | Quick arrival |
| `closed` | `EmergencyText.closed` | `!item.isOpen` | *(none)* |
| `all` | `EmergencyText.all` | all items | Quick arrival |

Refresh stays in `AppTabStrip.secondaryActions` (`commonRefreshActionLabel`) — **do not** move it into table search chrome.

### Per-tab columns today (all exceed or misalign with `prompt.md`)

#### `active`, `critical`, `all` — **6 columns** (violates ≤5)

| # | id | Label | Builder | Notes |
|---|-----|-------|---------|-------|
| 1 | `patient` | Patient | `emergencyPatientColumn()` → `EmergencyCaseCell` | Two-line name + MRN/case id — **allowed** |
| 2 | `priority` | Priority | `emergencyPriorityColumn()` → `severityStatus` badge | Severity, not case workflow status |
| 3 | `arrival` | Arrival | `emergencyArrivalColumn()` | Should be `columnChoices` |
| 4 | `response` | Response | `emergencyResponseColumn()` → `responseStatus` badge | Duplicates workflow signal; should be hidden choice |
| 5 | `location` | Location | `emergencyLocationColumn()` | |
| 6 | `next_action` | **Next** | `emergencyNextActionColumn()` → `WorkflowActionButton` | Generic column header; missing case **status** column |

#### `ambulance` — **6 columns**, no next-action column

| # | id | Label | Notes |
|---|-----|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `dispatch_status` | Dispatch status | Inline in page — extract to widgets |
| 4 | `ambulance` | Ambulance | |
| 5 | `trip_status` | Trip status | Hardcoded `'Trip status'` / `'No trip'` — needs l10n |
| 6 | `arrival` | Arrival | Should be hidden choice |

#### `handoff` — **5 columns** but wrong workflow layout

| # | id | Label | Notes |
|---|-----|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `triage_level` | Triage | Status-like badge in data slot |
| 4 | `response` | Response | Should be hidden choice |
| 5 | `next_action` | Next | Missing dedicated case **status** column |

#### `closed` — **5 data columns** (no workflow next-action — acceptable)

| # | id | Label | Notes |
|---|-----|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `arrival` | Arrival | |
| 4 | `handoff_destination` | Destination | Inline in page |
| 5 | `closed_at` | Closed at | Uses `updatedAt`; hardcoded label |

### Search chrome gaps

| Requirement | Current state |
|-------------|---------------|
| Filters button → **Advanced filters** modal | **Missing** — no `showAdvancedFilterButton` |
| Settings → **Table Settings** modal | Partial — `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` present; **`columnVisibilityTitle` missing** |
| Session column visibility | Present — `AppListTableColumnVisibilityController` + `columnVisibilityStorageKey: 'emergency_${_currentTab.name}'` |
| Column width persistence | Present — `columnWidthStorageKey: 'emergency_cw_${_currentTab.name}'` |
| `columnChoices` for hidden columns | **Missing** |
| Search matches all columns | **Incomplete** — `EmergencyCaseSummary.matchesSearch` omits `facilityLabel`, `currentLocation`, `handoff?.destination`, formatted status labels, `nextAction`, trip status text |

Current search wiring:

```dart
search: AppListTableSearch<EmergencyCaseSummary>(
  controller: _searchController,
  semanticLabel: 'Search emergency cases',
  hintText: EmergencyText.searchHint,
  matcher: (item, query) => item.matchesSearch(query),
  onSubmitted: controller.applySearch,
  onClear: () => controller.applySearch(''),
),
```

### Row interaction (already correct — preserve)

```dart
onRowSelected: (summary) {
  unawaited(openEmergencyDetailDialog(context, ref, state, summary, _writeRequirement));
},
```

Deep-link case open also uses `openEmergencyDetailDialog` in `_applyDeepLink`.

### Mobile gaps

`_mobileItemBuilder` shows `EmergencyCaseCell`, severity badge, response badge, location|arrival text — **missing** case status badge and `WorkflowActionButton` (next action).

### Workflow / next-action mapping (preserve logic)

`emergencyNextStepCode(EmergencyCaseSummary item)` in `emergency_workspace_widgets.dart`:

| Condition | `nextStep` code | Typical `WorkflowActionButton` label (from registry) |
|-----------|-----------------|------------------------------------------------------|
| `latestTriage == null` | `EMERGENCY_TRIAGE` | `l10n.opdRecordVitalsAction` (alias for triage route) |
| `latestResponse == null` | `EMERGENCY_STABILIZE` | `l10n.opdDoctorReviewAction` |
| Closed / cancelled | `DISPOSITION` | Disposition action from registry |

`EmergencyCaseSummary.nextAction` getter provides human-readable fallback text (`Record triage`, `Mark response`, `Receive ambulance`, `Handoff`, etc.) — use for sorting and search, not as column header.

### Realtime (already correct — preserve)

`EmergencyWorkspaceController` uses `listenForRealtimeRefresh` with `RealtimeEventGroups.emergencyWorkspace` and `WorkspaceRefreshProfile.emergency`. Table reads `state.board.items` via provider — do not mutate table widgets directly.

### Database migrations

**No database migrations required — schema unchanged.**

---

## Reference Implementation

Copy patterns from these files (read before editing):

| File | Pattern to copy |
|------|-----------------|
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable`, `AppListTableSearch`, `columnChoices`, `displayMode` (default `adaptive`) |
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | `_MortuaryWorklist` — Filters + Settings search chrome, `columnVisibilityController`, `showAdvancedFilterButton` |
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Client-side `filterGroups` + `_filterValue` state for tab-scoped advanced filters |
| `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` | `emergencyNextActionColumn`, `WorkflowActionButton`, `caseStatus`, column helpers |
| `prompt.md` | Normative contract |

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` |
|--------------|-------------|--------|----------------------------------|------------------------------|
| `AppListTable<EmergencyCaseSummary>` in `_EmergencyWorkspaceContentState` | `active` | `EmergencyCaseSummary` | patient, priority, location, status, next_action | `emergency_active` |
| Same instance | `critical` | `EmergencyCaseSummary` | patient, priority, arrival, status, next_action | `emergency_critical` |
| Same instance | `ambulance` | `EmergencyCaseSummary` | patient, priority, ambulance, status, next_action | `emergency_ambulance` |
| Same instance | `handoff` | `EmergencyCaseSummary` | patient, priority, triage, status, next_action | `emergency_handoff` |
| Same instance | `closed` | `EmergencyCaseSummary` | patient, priority, status, handoff_destination, closed_at | `emergency_closed` |
| Same instance | `all` | `EmergencyCaseSummary` | patient, priority, location, status, next_action | `emergency_all` |

### Shared column helpers (create in `emergency_workspace_widgets.dart`)

| Function | id | Label | Source |
|----------|-----|-------|--------|
| `emergencyPatientColumn()` | `patient` | Patient | *(existing)* |
| `emergencyPriorityColumn()` | `priority` | Priority | *(existing)* |
| `emergencyArrivalColumn()` | `arrival` | Arrival | *(existing)* |
| `emergencyResponseColumn()` | `response` | Response | *(existing)* |
| `emergencyLocationColumn()` | `location` | Location | *(existing)* |
| `emergencyCaseStatusColumn()` | `status` | Status | **NEW** — `AppWorkspaceStatusBadge(status: caseStatus(item))` |
| `emergencyTriageColumn()` | `triage` | Triage | **NEW** — extract inline handoff `triage_level` column |
| `emergencyFacilityColumn()` | `facility` | Facility | **NEW** — `item.facilityLabel ?? ''` |
| `emergencyAmbulanceColumn()` | `ambulance` | Ambulance | **NEW** — extract ambulance tab inline column |
| `emergencyAmbulanceWorkflowStatusColumn()` | `status` | Status | **NEW** — single field: active trip status if `activeTrip != null`, else `latestDispatch?.status` formatted via `apiLabel` + `ambulanceTone` |
| `emergencyDispatchStatusColumn()` | `dispatch_status` | Dispatch status | **NEW** — extract ambulance tab inline column |
| `emergencyTripStatusColumn()` | `trip_status` | Trip status | **NEW** — extract ambulance tab inline column |
| `emergencyHandoffDestinationColumn()` | `handoff_destination` | Destination | **NEW** — extract closed tab inline column |
| `emergencyClosedAtColumn()` | `closed_at` | Closed at | **NEW** — extract closed tab inline column |
| `emergencyNextActionColumn()` | `next_action` | Next action | **UPDATE** label from `EmergencyText.next` (`"Next"`) to explicit label (see below) |

### Column plan per tab

#### `active`, `all` (workflow — open cases)

| Position | Column id | Label | Notes |
|----------|-----------|-------|-------|
| 1 | `patient` | Patient | priority data |
| 2 | `priority` | Priority | severity badge |
| 3 | `location` | Location | triage context for open board |
| 4 | `status` | Status | `caseStatus(item)` — workflow status |
| 5 | `next_action` | Next action | `WorkflowActionButton` with `emergencyNextStepCode(item)` |

`columnChoices` (hidden by default): `arrival`, `response`, `triage`, `facility`, `dispatch_status`, `ambulance`, `handoff_destination`, `closed_at`

#### `critical` (workflow — time-sensitive)

| Position | Column id | Label | Notes |
|----------|-----------|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `arrival` | Arrival | time-critical on critical tab |
| 4 | `status` | Status | `caseStatus(item)` |
| 5 | `next_action` | Next action | `WorkflowActionButton` |

`columnChoices`: `location`, `response`, `triage`, `facility`, others as above

#### `ambulance` (workflow — dispatch/trip)

| Position | Column id | Label | Notes |
|----------|-----------|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `ambulance` | Ambulance | `latestDispatch?.ambulanceLabel ?? activeTrip?.ambulanceLabel` |
| 4 | `status` | Status | unified ambulance workflow status (trip in transit vs dispatch status) |
| 5 | `next_action` | Next action | Contextual: use `WorkflowActionButton` when workflow step applies; otherwise compact `AppButton` opening the same dialog/action as `EmergencyActionPanel` would (`Dispatch`, `Start trip`, `Complete trip`, `Update dispatch status`) — **never** generic `"Next"` |

`columnChoices`: `dispatch_status`, `trip_status`, `arrival`, `location`, `response`

#### `handoff` (workflow — ready for handoff)

| Position | Column id | Label | Notes |
|----------|-----------|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `triage` | Triage | `triageStatus(item.triageLevel)` |
| 4 | `status` | Status | `caseStatus(item)` or handoff-ready badge |
| 5 | `next_action` | Record handoff | `WorkflowActionButton` / action opening `HandoffDialog` — label **`EmergencyText.recordHandoff`** |

`columnChoices`: `response`, `arrival`, `location`, `facility`

#### `closed` (no active workflow — data columns only)

| Position | Column id | Label | Notes |
|----------|-----------|-------|-------|
| 1 | `patient` | Patient | |
| 2 | `priority` | Priority | |
| 3 | `status` | Status | `caseStatus(item)` — Closed/Cancelled |
| 4 | `handoff_destination` | Destination | `apiLabel(item.handoff?.destination ?? '')` |
| 5 | `closed_at` | Closed at | `dateTimeLabel(context, item.updatedAt)` |

`columnChoices`: `arrival`, `location`, `triage`, `response`

### Search chrome (all tabs)

Wire on the single `AppListTableSearch<EmergencyCaseSummary>`:

```dart
search: AppListTableSearch<EmergencyCaseSummary>(
  controller: _searchController,
  semanticLabel: l10n.emergencySearchSemanticLabel,
  hintText: l10n.emergencySearchHint,
  clearLabel: l10n.emergencyClearSearchAction,
  matcher: (item, query) => emergencyTableSearchMatcher(item, query),
  onSubmitted: controller.applySearch,
  onClear: () => controller.applySearch(''),
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.emergencyFiltersLabel,       // "Filters"
  advancedFilterTitle: l10n.emergencyAdvancedFiltersTitle,   // "Advanced filters"
  advancedFilterApplyLabel: l10n.emergencyApplyFiltersAction,
  advancedFilterResetLabel: l10n.emergencyResetFiltersAction,
  enableDateFilter: false,
  allFieldsLabel: l10n.emergencyAllFieldsFilterLabel,
  filterGroups: _filterGroupsForTab(_currentTab, state),
  filterValue: _filterValue,
  hasActiveFilters: _filterValue.isActive,
  onFilterChanged: (value) => setState(() => _filterValue = value),
),
```

On `AppListTable`:

```dart
columns: _defaultColumnsForTab(context, _currentTab),
columnChoices: _columnChoicesForTab(context),
columnVisibilityController: _columnVisibilityController,
columnVisibilityStorageKey: 'emergency_${_currentTab.name}',
columnWidthStorageKey: 'emergency_cw_${_currentTab.name}',
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.emergencyTableSettingsTitle,  // "Table Settings"
displayMode: AppListTableDisplayMode.adaptive,
```

**Advanced filters** are **client-side** (like Reception): filter `_buildRows` output with `_filterValue` before passing to `items:`. Suggested filter groups per tab:

| Tab | Filter group key | Choices source |
|-----|----------------|----------------|
| `active`, `critical`, `all` | `severity` | Distinct `item.severity` values → `apiLabel` |
| `active`, `critical`, `all`, `handoff` | `triage` | Distinct `item.triageLevel` or "Triage pending" |
| `ambulance` | `dispatch_status` | Distinct `item.latestDispatch?.status` |
| `closed` | `destination` | Distinct `item.handoff?.destination` |
| All tabs | `case_status` | Distinct `item.status` |

Apply filters in a new method `_filteredRows(EmergencyWorkspaceState state)` that composes `_buildRows` + `_filterValue`.

### Search matcher (must cover all columns including hidden)

Add `emergencyTableSearchMatcher(EmergencyCaseSummary item, String query)` in `emergency_workspace_widgets.dart` (or extend `matchesSearch`) to search:

- `id`, `displayId`, `caseLabel`
- `patientDisplayId`, `patientDisplayName`, `displayTitle`
- `severity`, `status` (raw + `apiLabel`)
- `facilityLabel`, `currentLocation`
- `triageLevel`, `responseStatus`, `nextAction`
- `latestDispatch?.ambulanceLabel`, `latestDispatch?.status`
- `activeTrip?.ambulanceLabel`, trip active/complete text
- `handoff?.destination`
- Formatted `createdAt` / `updatedAt` via `dateTimeLabel` when query looks date-like (optional; at minimum raw ISO substrings)

### Row interaction (preserve)

- `onRowSelected` → `openEmergencyDetailDialog(context, ref, state, summary, _writeRequirement)`
- Next-action column handlers must open the **same** dialogs/routes as `EmergencyActionPanel` / `WorkflowActionButton` — never navigate to generic `/emergency` home without case context

### Mobile builder

Replace `_mobileItemBuilder` with `emergencyMobileListItem(context, ref, item, writeRequirement: _writeRequirement)` in widgets file showing:

1. `EmergencyCaseCell` (patient)
2. Row of badges: `severityStatus`, `caseStatus`
3. Priority context line (location or arrival depending on tab — pass `EmergencyBoardTab`)
4. `WorkflowActionButton` (compact) or tab-appropriate action button

---

## Implementation Steps

### 1. Add l10n keys — `frontend/lib/l10n/app_en.arb`

Add (English only per locale rule):

```json
"emergencySearchSemanticLabel": "Search emergency cases",
"emergencySearchHint": "Search patient, case, ambulance, or status",
"emergencyClearSearchAction": "Clear search",
"emergencyFiltersLabel": "Filters",
"emergencyAdvancedFiltersTitle": "Advanced filters",
"emergencyApplyFiltersAction": "Apply filters",
"emergencyResetFiltersAction": "Reset filters",
"emergencyAllFieldsFilterLabel": "All fields",
"emergencyTableSettingsTitle": "Table Settings",
"emergencyStatusColumnLabel": "Status",
"emergencyNextActionColumnLabel": "Next action",
"emergencyTripStatusColumnLabel": "Trip status",
"emergencyNoTripLabel": "No trip",
"emergencyInTransitLabel": "In transit",
"emergencyTripCompleteLabel": "Complete",
"emergencyClosedAtColumnLabel": "Closed at",
"emergencySeverityFilterLabel": "Priority",
"emergencyTriageFilterLabel": "Triage",
"emergencyCaseStatusFilterLabel": "Case status",
"emergencyDispatchStatusFilterLabel": "Dispatch status",
"emergencyDestinationFilterLabel": "Destination"
```

Run codegen if the project requires it after arb edits. Update `EmergencyText` constants to reference l10n where the executing agent wires UI, or keep `EmergencyText` for static tests and add parallel l10n for new labels.

### 2. Column helpers — `emergency_workspace_widgets.dart`

1. Add `emergencyCaseStatusColumn()`, `emergencyTriageColumn()`, `emergencyFacilityColumn()`, ambulance/closed column extractors listed above.
2. Update `emergencyNextActionColumn()`:
   - Set `label` to `EmergencyText.recordHandoff` is **wrong globally** — use `l10n.emergencyNextActionColumnLabel` (`"Next action"`) as column header; the **button** inside `WorkflowActionButton` shows the explicit verb.
   - Ensure `sortComparator` uses `item.nextAction`.
3. Add `emergencyTableSearchMatcher`.
4. Add `emergencyMobileListItem(...)`.

### 3. Refactor page — `emergency_workspace_page.dart`

1. Add state: `AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;`
2. Reset `_filterValue` when tab changes in `onTabTapped`.
3. Split `_columnsForTab` into:
   - `_defaultColumnsForTab(BuildContext context, EmergencyBoardTab tab)` → ≤5 columns
   - `_columnChoicesForTab(BuildContext context)` → all optional columns not in defaults for that tab
4. Pass `columnChoices` to `AppListTable`.
5. Wire full search chrome (Filters + Settings titles).
6. Set `columnVisibilityTitle`.
7. Use `_filteredRows` for `items:`.
8. Add `_filterGroupsForTab` helper.
9. Remove inline column definitions from `_columnsForTab` switch branches — call widget helpers.
10. Delete the old 6-column switch bodies once replaced.

### 4. Extend entity search — `emergency_entities.dart`

Expand `matchesSearch` to include fields listed in search matcher section (or delegate to `emergencyTableSearchMatcher` from the page).

### 5. Tests — `frontend/test/features/emergency/`

Create `emergency_workspace_table_test.dart`:

- Each `EmergencyBoardTab`: `_defaultColumnsForTab` returns ≤5 columns.
- Default columns include `status` + `next_action` for workflow tabs (`active`, `critical`, `ambulance`, `handoff`, `all`).
- `closed` tab has no `next_action` in defaults.
- `emergencyNextActionColumn` label is not `"Next"`.
- `emergencyTableSearchMatcher` matches hidden fields (e.g. `facilityLabel`, `currentLocation`).
- Filter groups non-empty for ambulance tab.

Keep existing `emergency_workspace_toolbar_test.dart` passing (Refresh on all tabs, Quick arrival matrix).

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | same | Status columns |
| `AppListItemText` | same | Two-line cells if needed |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-action column |
| `caseStatus`, `severityStatus`, `triageStatus`, `responseStatus` | `emergency_workspace_widgets.dart` | Status badges |
| `openEmergencyDetailDialog` | `emergency_workspace_widgets.dart` | Row selection |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterValue` | `package:hosspi_hms/shared/components/components.dart` | Advanced filters |

**Do not** create parallel table, search, or filter implementations.

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart` |
| Modify | `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` |
| Modify | `frontend/lib/features/emergency/domain/entities/emergency_entities.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Create | `frontend/test/features/emergency/emergency_workspace_table_test.dart` |
| Modify | `frontend/test/features/emergency/emergency_workspace_toolbar_test.dart` *(only if needed for new exports)* |

No files to delete.

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- Reuse `commonTableSettingsActionLabel` for the Settings **button** label.
- Use new `emergencyTableSettingsTitle` for the Settings **modal** title (`"Table Settings"`).
- Filters button: `emergencyFiltersLabel` (`"Filters"`); modal title: `emergencyAdvancedFiltersTitle` (`"Advanced filters"`).

---

## Database Migrations

No database migrations required — schema unchanged.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/emergency/
```

Manual smoke (web or emulator):

1. `/emergency` → each tab shows ≤5 default columns + automatic row numbers.
2. Search chrome shows only **Filters** and **Settings** (no Refresh/Export in search bar).
3. Settings toggles hidden columns; preference persists when switching away and back to the same tab.
4. Row tap opens emergency case detail dialog with action panel.
5. Next-action button opens triage/response/handoff flow (not generic module home).
6. Narrow viewport shows mobile cards with status + action.
7. After triage/response mutation, row updates without full page reload.

---

## Testing Requirements

- [ ] Each tab: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per `emergency_<tab>` key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tabs: explicit status (`caseStatus`) + next-action (`WorkflowActionButton` or explicit verb button)
- [ ] Row tap opens `openEmergencyDetailDialog`
- [ ] Mobile list shows patient, status badges, and next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `AppPermissions.emergencyWrite` still gates write actions via `AppAccessActionGate` / `WorkflowActionButton`
- [ ] Deep links `?scope=critical`, `?id=<caseId>` still work

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the Emergency worklist table on every tab
- [ ] Domain logic preserved (tab filters, counts, Quick arrival, Refresh, deep links, permissions)
- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test test/features/emergency/` passes
