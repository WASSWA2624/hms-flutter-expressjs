# Standardize Discharge Tables

## Objective

Refactor every `AppListTable` on the Discharge workspace (`/discharge`, `DischargeWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, tab toolbar actions (Start discharge plan / Manage clearance / Print discharge summary, Refresh), or repository/controller mutation logic unless required for compilation.

---

## Current State (from audit)

### Screen inventory

| Field | Value |
|-------|-------|
| Route | `/discharge` (`AppRoutes.discharge`) |
| Page widget | `DischargeWorkspacePage` |
| Content state | `_DischargeWorkspaceContentState` |
| Primary file | `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` |
| Entity | `IpdAdmissionSummary` |
| Controller | `dischargeWorkspaceControllerProvider` → `DischargeWorkspaceController` |
| Detail dialog | `_openDischargeDetailDialog` (same file, ~line 771) |
| Planning dialog | `showDischargePlanningDialog` in `frontend/lib/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart` |
| Deep link | `?section=<tab>` (`all`, `planned`, `pending`, `completed`); admission focus via `?id=` / `?admission=` / `?admissionId=` / `?admission_id=`; search via `?search=` / `?q=` |

There is **one** `AppListTable<IpdAdmissionSummary>` instance in `_DischargeWorkspaceContentState.build()`. Tab switches update `_section` (`DischargeDeskSection`), call `_columnsForSection(l10n)`, and filter rows via `_buildRows(state)` — not separate table widgets.

**Note:** `DischargeWorklistQuery.fromUri` reads `section` from the URL but does **not** parse a `status` query param. Status filtering is applied only through the Advanced filters modal (`controller.applyStatus`). Do not break that behavior.

### Tabs (`DischargeDeskSection`)

| Tab enum | URL `section` | Label l10n key | Row filter | Toolbar primary |
|----------|---------------|----------------|------------|-----------------|
| `all` | `all` | `dischargeSectionAll` | all queue items | `dischargeStartPlanAction` |
| `planned` | `planned` | `dischargeSectionPlanned` | `isPlannedDischarge(item)` | `dischargeManageClearanceAction` |
| `pendingClearance` | `pending` (also `pending_clearance`, `pending-clearance`, `pendingclearance`) | `dischargeSectionPendingClearance` | not completed and not planned | `dischargeManageClearanceAction` |
| `completed` | `completed` (also `discharged`) | `dischargeSectionCompleted` | `isCompletedDischarge(item)` | `dischargePrintSummaryAction` |

Refresh stays in `AppTabStrip.secondaryActions` (`commonRefreshActionLabel`) — **do not** move it into table search chrome.

### Per-tab columns today

#### `all` — **5 columns** (workflow layout wrong: status col 3, next_action col 4, target col 5)

| # | id | Label l10n | Field / builder | Notes |
|---|-----|------------|-----------------|-------|
| 1 | `patient_name` | `dischargePatientColumnLabel` | `_QueuePatientCell` (name + admission id) | OK: one semantic field, two-line |
| 2 | `location` | `dischargeLocationColumnLabel` | `item.location` (ward + bed) | Priority data |
| 3 | `status` | `dischargeStatusColumnLabel` | `_statusFor` → `AppWorkspaceStatusBadge` | Workflow status — **wrong position** (should be col 4) |
| 4 | `next_action` | `dischargeNextActionColumnLabel` | `WorkflowActionButton` | **wrong position** (should be col 5) |
| 5 | `target_date` | `dischargeTargetColumnLabel` | `item.dischargedAt` formatted | Priority data — **wrong position**; sort uses `dischargedAt` |

#### `planned` — **5 columns** (missing dedicated status column; clearance phase used as data)

| # | id | Label l10n | Field / builder | Notes |
|---|-----|------------|-----------------|-------|
| 1 | `patient_name` | `dischargePatientColumnLabel` | `_QueuePatientCell` | |
| 2 | `location` | `dischargeLocationColumnLabel` | `item.location` | |
| 3 | `clearance_phase` | `ipdDischargeClearancePhaseLabel` | `clearancePhase` → `AppWorkspaceStatusBadge` | Sub-status data — keep as col 3 |
| 4 | `next_action` | `dischargeNextActionColumnLabel` | `WorkflowActionButton` | Missing status column before this |
| 5 | `target_date` | `dischargeTargetColumnLabel` | `dischargedAt` | Move to `columnChoices` |

#### `pendingClearance` — **4 columns** (missing status column)

| # | id | Label l10n | Field / builder | Notes |
|---|-----|------------|-----------------|-------|
| 1 | `patient_name` | `dischargePatientColumnLabel` | `_QueuePatientCell` | |
| 2 | `location` | `dischargeLocationColumnLabel` | `item.location` | |
| 3 | `blocking_item` | `dischargeStatusSummaryPending` | `clearancePhase` / `nextStep` / `stage` badge | Key triage field for this tab |
| 4 | `next_action` | `dischargeNextActionColumnLabel` | `WorkflowActionButton` | Missing status column (col 4) |

#### `completed` — **3 columns** (no workflow status/next-action columns)

| # | id | Label l10n | Field / builder | Notes |
|---|-----|------------|-----------------|-------|
| 1 | `patient_name` | `dischargePatientColumnLabel` | `_QueuePatientCell` | |
| 2 | `location` | `dischargeLocationColumnLabel` | `item.location` | |
| 3 | `discharged_at` | `ipdDischargedAtLabel` | `dischargedAt` formatted | |

Completed rows still have `_dischargeNextStepCode` → `DISPOSITION` and toolbar Print action; table should expose explicit next-action column for parity.

### Search chrome today

| Requirement | Current state |
|-------------|---------------|
| Filters button → **Advanced filters** modal | Partial — `showAdvancedFilterButton: true`, `advancedFilterButtonLabel: l10n.dischargeFiltersLabel` (`"Filters"`) OK |
| Filters modal title **Advanced filters** | **Wrong** — `advancedFilterTitle: l10n.dischargeFiltersLabel` (`"Filters"`) |
| Settings → **Table Settings** modal | Partial — `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` OK; **`columnVisibilityTitle` missing** |
| Session column visibility | Present — `AppListTableColumnVisibilityController` + `columnVisibilityStorageKey: 'discharge_${_section.name}'` |
| Column width persistence | Present — `columnWidthStorageKey: 'discharge_cw_${_section.name}'` |
| `columnChoices` for hidden columns | **Missing** |
| Search matches all columns | **Incomplete** — `_searchMatcher` only checks `displayTitle`, `displayId`, `location`; omits status labels, clearance phase, blocking text, formatted dates, `dischargeStatus`, `stage`, `nextStep`, next-action labels |

Current search wiring:

```dart
search: AppListTableSearch<IpdAdmissionSummary>(
  controller: _searchController,
  semanticLabel: l10n.dischargeQueueSearchLabel,
  hintText: l10n.dischargeQueueSearchHint,
  matcher: _searchMatcher,
  onSubmitted: (value) => controller.applySearch(value),
  onClear: () => controller.applySearch(''),
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.dischargeFiltersLabel,
  advancedFilterTitle: l10n.dischargeFiltersLabel, // wrong
  filterGroups: [/* DischargeStatusFilter choices */],
  filterValue: _dischargeFilterValue(state.query),
  hasActiveFilters: state.query.status != DischargeStatusFilter.all,
  onFilterChanged: (value) => controller.applyStatus(...),
),
```

Status filter group key: `_dischargeStatusFilterKey` (`'status'`). Choices map to `DischargeStatusFilter` enum values via `_dischargeStatusFilterChoices`.

### Row interaction (already correct — preserve)

```dart
onRowSelected: (IpdAdmissionSummary item) {
  setState(() => _selectedAdmission = item);
  unawaited(_openDischargeDetailDialog(context, ref, state, item));
},
```

Deep-link admission open in `_DischargeWorkspacePageState._handleDeepLink` also calls `_openDischargeDetailDialog`.

Detail dialog actions in `_DischargeDetailContent`: Start/edit plan, Manage clearance, Request billing, Request pharmacy, Complete discharge (`clinicalDispositionActionLabel`), Print summary.

### Mobile gaps (`_MobileQueueItem`)

Shows `_QueuePatientCell`, `_statusFor` badge, location text, and plain-text `_nextActionLabel` — **missing** `WorkflowActionButton` (next-action parity with desktop).

`displayMode` not set explicitly (defaults to `AppListTableDisplayMode.adaptive` — set explicitly for clarity).

### Workflow / status / next-action mapping (preserve logic)

**Section-level status** (`_statusFor`):

| Condition | Label l10n | Tone |
|-----------|------------|------|
| `isCompletedDischarge(item)` | `dischargeStatusCompleted` | success |
| `isPlannedDischarge(item)` | `dischargeStatusPlanned` | info |
| else | `dischargeStatusSummaryPending` | warning |

**Next-action labels** (`_nextActionLabel`):

| Condition | Label l10n |
|-----------|------------|
| completed | `dischargeNextActionCompleted` |
| planned | `dischargeNextActionClearance` |
| else (summary pending) | `dischargeNextActionStartPlan` |

**WorkflowActionButton params** (`_nextActionColumn`):

| Condition | `nextStep` code | `sourceModule` |
|-----------|---------------|----------------|
| completed | `DISPOSITION` | `'discharge'` |
| planned | `FINALIZE_DISCHARGE` | `'discharge'` |
| else | `DISCHARGE_PLANNING` | `'discharge'` |

`encounterId: item.encounterId ?? item.id`, `admissionId: item.id`, `stage: item.stage`, `compact: true`.

When `encounterId` is empty, falls back to plain `Text(_nextActionLabel(...))` — preserve fallback.

### Realtime (already correct — preserve)

`DischargeWorkspaceController` uses `listenForRealtimeRefresh` with `RealtimeEventGroups.discharge` and defers while `_isSyncing` or `isSaving`. Table reads `state.queue.items` via provider — do not mutate table widgets directly.

### Database migrations

**No database migrations required — schema unchanged.**

---

## Reference Implementation

Copy patterns from these files (read before editing):

| File | Pattern to copy |
|------|-----------------|
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable`, `AppListTableSearch`, `columnChoices`, `displayMode` (default `adaptive`) |
| `frontend/lib/shared/components/app_list_item_text.dart` | `AppListItemText` for two-line patient cells |
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | `_MortuaryWorklist` — Filters + Settings search chrome, `columnVisibilityController`, `showAdvancedFilterButton` |
| `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` | `emergencyNextActionColumn()`, `WorkflowActionButton` |
| `prompts/05-ipd-prompt.md` | Shared l10n keys (`commonAdvancedFiltersTitle`, `commonTableSettingsTitle`), column reorder pattern |
| `prompt.md` | Normative contract |

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` |
|--------------|-------------|--------|----------------------------------|------------------------------|
| `AppListTable<IpdAdmissionSummary>` in `_DischargeWorkspaceContentState` | `all` | `IpdAdmissionSummary` | patient, location, target_date, status, next_action | `discharge_all` |
| Same instance | `planned` | `IpdAdmissionSummary` | patient, location, clearance_phase, status, next_action | `discharge_planned` |
| Same instance | `pendingClearance` | `IpdAdmissionSummary` | patient, location, blocking_item, status, next_action | `discharge_pendingClearance` |
| Same instance | `completed` | `IpdAdmissionSummary` | patient, location, discharged_at, status, next_action | `discharge_completed` |

### Shared column helpers (extract in `discharge_workspace_page.dart` or new `discharge_workspace_widgets.dart`)

| Function / column | id | Label l10n | Source | Notes |
|-------------------|-----|------------|--------|-------|
| `_patientColumn` | `patient` | `dischargePatientColumnLabel` | `displayTitle` / `displayId` | Refactor `_QueuePatientCell` to use `AppListItemText`; `alwaysVisible: true` |
| `_locationColumn` | `location` | `dischargeLocationColumnLabel` | `item.location` | |
| `_statusColumn` | `status` | `dischargeStatusColumnLabel` | `_statusFor` | `AppWorkspaceStatusBadge`; `alwaysVisible: true` on workflow tabs |
| `_nextActionColumn` | `next_action` | `dischargeNextActionColumnLabel` | `WorkflowActionButton` | `alwaysVisible: true` |
| `_targetDateColumn` | `target_date` | `dischargeTargetColumnLabel` | `dischargedAt` | Keep field mapping; document in code comment if API has no separate target date on summary |
| `_clearancePhaseColumn` | `clearance_phase` | `ipdDischargeClearancePhaseLabel` | `clearancePhase` | Planned tab col 3 |
| `_blockingItemColumn` | `blocking_item` | `dischargeStatusSummaryPending` | blocker phase/step | Pending tab col 3 |
| `_dischargedAtColumn` | `discharged_at` | `ipdDischargedAtLabel` | `dischargedAt` | Completed tab col 3 |

Rename column ids from `patient_name` → `patient` for consistency with other modules (update storage keys only if you migrate — prefer keeping existing `discharge_${_section.name}` keys to preserve session prefs).

### Per-tab column plan

#### `all`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `location` | |
| 3 | `target_date` | |
| 4 | `status` | |
| 5 | `next_action` | |

**`columnChoices` (hidden):** `clearance_phase`, `discharged_at`, `admitted_at` (add `admitted_at` column using `item.admittedAt` + `dischargeTargetDateLabel` or reuse IPD admitted-at label if shared key exists)

#### `planned`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `location` | |
| 3 | `clearance_phase` | |
| 4 | `status` | planned badge |
| 5 | `next_action` | |

**`columnChoices`:** `target_date`, `discharged_at`, `admitted_at`

#### `pendingClearance`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `location` | |
| 3 | `blocking_item` | |
| 4 | `status` | summary-pending badge |
| 5 | `next_action` | `DISCHARGE_PLANNING` / start summary |

**`columnChoices`:** `clearance_phase`, `target_date`, `admitted_at`

#### `completed`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `location` | |
| 3 | `discharged_at` | |
| 4 | `status` | completed badge |
| 5 | `next_action` | `WorkflowActionButton` with `nextStep: 'DISPOSITION'`; same destination as Print in detail dialog |

**`columnChoices`:** `clearance_phase`, `target_date`, `admitted_at`

Register on `AppListTable`:

```dart
final List<AppListTableColumn<IpdAdmissionSummary>> allColumns =
    _dischargeTableColumns(context, section: _section);
final List<AppListTableColumn<IpdAdmissionSummary>> defaultColumns =
    _dischargeDefaultColumns(context, section: _section);

AppListTable<IpdAdmissionSummary>(
  columns: defaultColumns,
  columnChoices: allColumns,
  // ...
)
```

### Search chrome (per table)

- Filters button label: keep `l10n.dischargeFiltersLabel` (`"Filters"`)
- Filters modal title: `l10n.commonAdvancedFiltersTitle` (add shared key `"Advanced filters"` if absent — see l10n section)
- Settings button: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`
- Settings modal title: `columnVisibilityTitle: l10n.commonTableSettingsTitle` (add shared key `"Table Settings"` if absent)
- Preserve existing `filterGroups`, `filterValue`, `hasActiveFilters`, `onFilterChanged` → `controller.applyStatus`
- Preserve `onSubmitted` / `onClear` → `controller.applySearch` (server-side search); extend client `matcher` for in-page refinement

**Matcher** — implement `_dischargeMatchesSearch(IpdAdmissionSummary item, String query, BuildContext context)`:

- Start with `item.matchesSearch(query)` from `IpdAdmissionSummary` (covers id, displayId, patient fields, stage, dischargeStatus, clearancePhase, etc.)
- Additionally match: `_locationLabel`, `_statusFor(...).label`, `_nextActionLabel`, formatted `_dateLabel` for `dischargedAt` and `admittedAt`, `_apiLabel(clearancePhase)`, `_apiLabel(nextStep)`, blocking-item display text
- Wire: `matcher: (item, query) => _dischargeMatchesSearch(item, query, context)`

### Row interaction

| Handler | Behavior |
|---------|----------|
| `onRowSelected` | Keep `_openDischargeDetailDialog(context, ref, state, item)` |
| Next-action column | `WorkflowActionButton` opens workflow route/dialog — same family of actions as detail dialog (`showDischargePlanningDialog`, disposition) |
| Completed tab toolbar Print | Keep in `AppTabStrip.primaryAction`; table next-action should offer equivalent print/view when `WorkflowActionButton` cannot |

### Mobile (`_MobileQueueItem`)

Mirror desktop priority fields per active tab:

- Row 1: patient (`AppListItemText`) + status badge
- Row 2: location
- Row 3: tab-specific third field when visible (clearance phase, blocking item, or date)
- Row 4: `WorkflowActionButton` (same params as `_nextActionColumn`) — not plain text label

---

## Implementation Steps

### 1. Shared l10n keys — `frontend/lib/l10n/app_en.arb`

Add if absent (may already be planned by other module prompts):

```json
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen (`flutter gen-l10n` or project equivalent). Do **not** add per-locale files beyond `app_en.arb`.

---

### 2. Column refactor — `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`

1. Extract `_dischargeTableColumns(BuildContext context, {required DischargeDeskSection section})` returning **all** column definitions with stable ids.
2. Extract `_dischargeDefaultColumns(...)` returning the five defaults per tab per Target Architecture.
3. Replace `_columnsForSection` with the default-columns helper; pass full list as `columnChoices`.
4. Reorder **all** tab defaults so `status` is column 4 and `next_action` is column 5.
5. Add `status` + `next_action` to `pendingClearance` and `completed` tabs.
6. Refactor `_QueuePatientCell` to use `AppListItemText(title: item.displayTitle, subtitle: item.displayId ?? l10n.profileUnknownValue)`.
7. On `AppListTable`:
   - `displayMode: AppListTableDisplayMode.adaptive`
   - `columnVisibilityTitle: l10n.commonTableSettingsTitle`
   - `columnChoices: allColumns`
8. Update `AppListTableSearch`:
   - `advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
   - `matcher: (item, query) => _dischargeMatchesSearch(item, query, context)`
9. Update `_MobileQueueItem` to accept `DischargeDeskSection section` (or read from parent) and render `WorkflowActionButton` with same mapping as `_nextActionColumn`.
10. Optionally move column builders to `frontend/lib/features/discharge/presentation/widgets/discharge_workspace_widgets.dart` if the page file grows too large — follow Emergency module layout.

---

### 3. Tests — `frontend/test/features/discharge/presentation/discharge_workspace_page_test.dart`

Update/add expectations:

- Each tab renders ≤5 default column headers (excluding automatic row number)
- `Filters` and `Settings` present in table search chrome (Refresh remains in tab toolbar)
- Advanced filters modal opens with title **Advanced filters** (after l10n key added)
- Settings opens modal titled **Table Settings**
- Row tap still opens `AppDialog` / detail (`dischargeDetailTitle`)
- Mobile width (`390×844`) still renders queue items and tab strip
- Column visibility storage keys remain `discharge_<section.name>` and `discharge_cw_<section.name>`
- Search with patient name still filters client-side (`Bob` hides other rows)

Add widget test for **Pending clearance** tab: expect status + next-action column headers when tab selected.

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell, columns, search |
| `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Session column visibility |
| `AppListTableDisplayMode` | `package:hosspi_hms/shared/components/app_list_table.dart` | `adaptive` |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Patient two-line cell |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/components/components.dart` | Status column |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-action column |
| `AppDialog` | `package:hosspi_hms/shared/components/components.dart` | Detail dialog shell |
| `showDischargePlanningDialog` | `package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart` | Planning/clearance follow-up |

---

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` |
| Modify (optional) | `frontend/lib/features/discharge/presentation/widgets/discharge_workspace_widgets.dart` (new file if extracting columns/mobile) |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/discharge/presentation/discharge_workspace_page_test.dart` |
| Delete | None |

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only
- Prefer shared keys: `commonTableSettingsActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`
- Keep existing discharge-specific keys: `dischargeFiltersLabel`, `dischargePatientColumnLabel`, `dischargeStatusColumnLabel`, `dischargeNextActionColumnLabel`, etc.
- Do not change tab labels (`dischargeSectionAll`, etc.) — tests depend on them

---

## Database Migrations

No database migrations required — schema unchanged.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/discharge/
```

---

## Testing Requirements

- [ ] Each tab: search, Filters, Settings only in chrome (Refresh in tab toolbar only)
- [ ] Column visibility persists for session per `discharge_<section>` key
- [ ] ≤5 default columns per tab; row number automatic
- [ ] Workflow tabs: explicit status (col 4) + next-action (col 5) labels
- [ ] Completed tab: status + print/disposition next-action
- [ ] Row tap opens `_openDischargeDetailDialog`
- [ ] Mobile list shows same priority fields + `WorkflowActionButton`
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `AppAccessActionGate` on toolbar primary actions unchanged
- [ ] Advanced status filter (`DischargeStatusFilter`) still applies via Filters modal

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the Discharge worklist table on every tab
- [ ] Domain logic preserved (tab filters, clearance workflow, permissions, deep links, dialogs)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/discharge/` passes
