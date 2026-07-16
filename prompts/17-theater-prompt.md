# Standardize Theater Tables

## Objective

Refactor every `AppListTable` on the Theater workspace (`/theater`, `TheaterWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, unrelated screen chrome (tab strip, Schedule case / Refresh toolbar actions), repository/controller mutation logic, or recovery-tab filter semantics unless required for compilation.

---

## Current State (from audit)

### Screen inventory

| Field | Value |
|-------|-------|
| Route | `/theater` |
| Page widget | `TheaterWorkspacePage` |
| Content state | `_TheaterWorkspaceContentState` |
| Primary file | `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart` |
| Table widget | `_TheaterCaseBoard` (L431–675) |
| Entity | `TheaterCase` |
| Provider | `theaterWorkspaceControllerProvider` (`TheaterWorkspaceController`) |
| Detail dialog | `_openTheaterCaseDialog` (L751–788) |
| Deep link | `?section=<tab>` (`scheduled`, `in-theater`, `recovery`, `all`); also `?id=`, `?panel=` (`checklist`, `anesthesia`, `postop`, `resources`), schedule dialog query params |

There is **one** `AppListTable<TheaterCase>` instance in `_TheaterCaseBoard`. Tab switches in `_TheaterWorkspaceContentState` call `_applyTabFilter(TheaterSection)` (L217–230) which updates **server query filters** only — columns are identical across all tabs today.

### Tabs (`TheaterSection`)

| Tab | l10n label key | URL `section` | Controller filter |
|-----|----------------|---------------|-------------------|
| `scheduled` | `theaterScheduledSummaryLabel` | `scheduled` | `applyStatus('SCHEDULED', clearStage: true)` |
| `inTheater` | `theaterInTheaterSummaryLabel` | `in-theater` | `applyStatus('IN_PROGRESS', clearStage: true)` |
| `recovery` | `theaterRecoverySectionLabel` | `recovery` | `applyStage('POST_OP', clearStatus: true)` |
| `all` | `theaterAllCasesSummaryLabel` | *(omitted)* | `clearFilters()` |

Refresh and **Schedule case** stay in `AppTabStrip` toolbar (`commonRefreshActionLabel`, `theaterScheduleCaseAction`) — **do not** move them into table search chrome.

### Current columns — **9 declared** (violates ≤5; no `columnChoices`)

All columns are in `columns` only (L572–668). No `id` fields declared (keys fall back to `label`).

| # | Implicit key | Label key | Source field(s) | Cell pattern | Gap |
|---|--------------|-----------|-----------------|--------------|-----|
| 1 | `Case` | `theaterCaseIdColumnLabel` | `effectiveDisplayId` | `Text` | Move to `columnChoices` |
| 2 | `Procedure` | `theaterProcedureColumnLabel` | `procedureName` | `Text` | Keep as priority data |
| 3 | `Patient` | `theaterPatientColumnLabel` | `patientDisplayName`, `patientDisplayId`, `encounterDisplayId` | `_TwoLineCell` | OK (one patient-context field) |
| 4 | `Time` | `theaterTimeColumnLabel` | `scheduledAt` | `_formatDateTime` | Tab-dependent priority |
| 5 | `Room` | `theaterRoomColumnLabel` | `roomDisplayLabel`, `roomDisplayId` | `_roomLabel` (joined) | Tab-dependent priority |
| 6 | `Status` | `theaterStatusColumnLabel` | `status` | `_TheaterStatusBadge` → `AppStatusBadge` | Use `AppWorkspaceStatusBadge` per `prompt.md` |
| 7 | `Readiness` | `theaterReadinessColumnLabel` | `checklistCompleted` / `checklistTotal` | `_readinessLabel` | Move to `columnChoices` |
| 8 | `Owner` | `theaterResponsibleRoleColumnLabel` | `responsibleRoleLabel` | `_responsibleRoleLabel` | Move to `columnChoices` |
| 9 | `Next action` | `theaterNextActionColumnLabel` | `_nextActionLabel` | **`Text` only** | Must be pressable explicit action |

### Search chrome gaps

| Requirement | Current state |
|-------------|---------------|
| Filters button → **Advanced filters** modal | Partial — `showAdvancedFilterButton: true` but `advancedFilterTitle: l10n.theaterFiltersLabel` (**"Filters"**) instead of **"Advanced filters"** |
| Settings → **Table Settings** modal | Partial — `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` present; **`columnVisibilityTitle` missing** |
| Session column visibility | Partial — `AppListTableColumnVisibilityController` created (L142–153) but **`columnVisibilityStorageKey` missing** on `AppListTable` |
| Column width persistence | **Missing** — no `columnWidthStorageKey` |
| `columnChoices` for hidden columns | **Missing** |
| Search matches all columns | **FAIL** — `matcher: (_, _) => true` (L464); server search via `onSubmitted` only |
| Extra search chrome controls | **OK** — no export/refresh in search bar |

Current filter wiring (preserve behavior):

- Filter group keys: `_theaterStatusFilterKey`, `_theaterStageFilterKey`
- Text filters: `_theaterRoomFilterKey`, `_theaterSurgeonFilterKey`, `_theaterAnesthetistFilterKey`
- `onFilterChanged` → `applyStatus`, `applyStage`, `applyScheduledDate`, `applyResourceFilters`

### Row interaction (already correct — preserve)

```dart
onRowSelected: (TheaterCase item) {
  unawaited(_openTheaterCaseDialog(context, ref, state, item, canWrite));
},
```

`_openTheaterCaseDialog` calls `controller.selectCase`, then `showAppDialog` with `_TheaterCaseDetail` including `_TheaterActionBar` (L962–1022).

### Mobile gaps

`_TheaterCaseListTile` (L1308–1351) shows patient, status badge, time, room/stage/readiness — **missing** explicit next-action control matching desktop.

### Workflow / next-action mapping (preserve logic)

`_nextActionLabel` (L2362–2383) drives labels:

| Condition | l10n key / label | Dialog (same as `_TheaterActionBar`) |
|-----------|------------------|--------------------------------------|
| `status == CANCELLED` | `theaterStatusCancelled` | Non-actionable (terminal) |
| `status == COMPLETED` | `theaterStatusCompleted` | Non-actionable (terminal) |
| `!isReady` | `theaterUpdateReadinessAction` | `_showChecklistDialog` |
| `status == SCHEDULED` | `theaterStartCaseAction` | `_showStageDialog` |
| `!hasFinalAnesthesia` | `theaterAnesthesiaAction` | `_showAnesthesiaDialog` |
| `!hasFinalPostOp` | `theaterPostOpAction` | `_showPostOpDialog` |
| else | `theaterHandoverAction` | `_showHandoverDialog` |

`WorkflowActionRegistry._theatreActions` (L995+) only defines cross-module **route** actions (`THEATRE_SCHEDULING`, `THEATRE_IN_PROGRESS`) — **not** intra-theater row actions. Do **not** force `WorkflowActionButton` where it cannot open the correct theater dialog; use a compact module action button instead (see Target Architecture).

### Case statuses and workflow stages

- Statuses (`theaterCaseStatuses`): `SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED` — labels via `_caseStatusLabel` (L2307–2314)
- Stages (`theaterWorkflowStages`): `PRE_OP` … `COMPLETED` — labels via `_stageLabel` (L2319–2330)
- Responsible role by stage: `TheaterCase.responsibleRoleLabel` (entities L772–780)

### Realtime (already correct — preserve)

`TheaterWorkspaceController.build` uses `listenForRealtimeRefresh(events: RealtimeEventGroups.theater, includeCrudMutations: true)` and `_syncFromRealtime`. Table reads `state.cases` from provider — do not mutate table widgets directly.

### Domain note (preserve unless product asks otherwise)

Recovery tab filters `stage=POST_OP` only. `recoveryCount` includes `POST_OP | PACU_HANDOFF` — do not change filter semantics in this refactor.

### Database migrations

**No database migrations required — schema unchanged.**

---

## Reference Implementation

Copy patterns from these files (read before editing):

| File | Pattern to copy |
|------|-----------------|
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable`, `AppListTableSearch`, `columnChoices`, `displayMode` |
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | `_MortuaryWorklist` — Filters + Settings search chrome, `columnVisibilityController` |
| `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` | `emergencyNextActionColumn`, compact action button pattern |
| `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` | `_statusColumn` with `AppWorkspaceStatusBadge`, `_nextActionColumn` with pressable action |
| `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart` | Hybrid server `applySearch` + client `matcher`; `columnVisibilityStorageKey: 'claims_${section.name}'` |
| `prompt.md` | Normative contract |

---

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` |
|--------------|-------------|--------|----------------------------------|------------------------------|
| `_TheaterCaseBoard` | `scheduled` | `TheaterCase` | patient, procedure, time, status, next_action | `theater_scheduled` |
| `_TheaterCaseBoard` | `inTheater` | `TheaterCase` | patient, procedure, room, status, next_action | `theater_inTheater` |
| `_TheaterCaseBoard` | `recovery` | `TheaterCase` | patient, procedure, room, status, next_action | `theater_recovery` |
| `_TheaterCaseBoard` | `all` | `TheaterCase` | patient, procedure, time, status, next_action | `theater_all` |

Pass `TheaterSection section` from `_TheaterWorkspaceContentState.build` into `_TheaterCaseBoard` so column defaults and storage keys vary per tab (match Emergency/Claims pattern).

### Shared column helpers (add to `theater_workspace_page.dart` or new `theater_workspace_widgets.dart`)

Prefer extracting to `frontend/lib/features/theater/presentation/widgets/theater_workspace_widgets.dart` if the page file grows too large — mirror Emergency's split.

| Function | id | Label | Source | Notes |
|----------|-----|-------|--------|-------|
| `theaterCaseIdColumn` | `case_id` | `theaterCaseIdColumnLabel` | `effectiveDisplayId` | `columnChoices` only |
| `theaterProcedureColumn` | `procedure` | `theaterProcedureColumnLabel` | `procedureName` | priority data |
| `theaterPatientColumn` | `patient` | `theaterPatientColumnLabel` | patient name + ID/encounter subtitle | `_TwoLineCell` |
| `theaterTimeColumn` | `time` | `theaterTimeColumnLabel` | `scheduledAt` | |
| `theaterRoomColumn` | `room` | `theaterRoomColumnLabel` | `roomDisplayLabel` primary, `roomDisplayId` subtitle via `_TwoLineCell` | Split joined label into one-field two-line |
| `theaterStatusColumn` | `status` | `theaterStatusColumnLabel` | `status` | `AppWorkspaceStatusBadge` with `_caseStatusLabel` + `_statusTone`; `alwaysVisible: true` |
| `theaterReadinessColumn` | `readiness` | `theaterReadinessColumnLabel` | checklist progress | `columnChoices` only |
| `theaterOwnerColumn` | `owner` | `theaterResponsibleRoleColumnLabel` | `responsibleRoleLabel` | `columnChoices` only |
| `theaterNextActionColumn` | `next_action` | `theaterNextActionColumnLabel` | `_nextActionLabel` | `_TheaterNextActionButton`; `alwaysVisible: true` |

### Column plan per tab

#### `scheduled`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | triage who is on the list |
| 2 | `procedure` | what is scheduled |
| 3 | `time` | `scheduledAt` |
| 4 | `status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | typically `theaterStartCaseAction` or `theaterUpdateReadinessAction` |

`columnChoices`: `case_id`, `room`, `readiness`, `owner`

#### `inTheater`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `procedure` | |
| 3 | `room` | active OR location |
| 4 | `status` | |
| 5 | `next_action` | stage-appropriate dialog action |

`columnChoices`: `case_id`, `time`, `readiness`, `owner`

#### `recovery`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `procedure` | |
| 3 | `room` | |
| 4 | `status` | |
| 5 | `next_action` | anesthesia / post-op / handover per `_nextActionLabel` |

`columnChoices`: `case_id`, `time`, `readiness`, `owner`

#### `all`

| Position | Column id | Notes |
|----------|-----------|-------|
| 1 | `patient` | |
| 2 | `procedure` | |
| 3 | `time` | |
| 4 | `status` | |
| 5 | `next_action` | |

`columnChoices`: `case_id`, `room`, `readiness`, `owner`

Implement `_defaultColumnsForSection(BuildContext context, TheaterSection section)` and `_columnChoicesForSection(BuildContext context)` returning the union of all column helpers not in the active default set.

### `_TheaterNextActionButton` (new widget)

Create a `ConsumerWidget` in the theater widgets file:

```dart
class _TheaterNextActionButton extends ConsumerWidget {
  const _TheaterNextActionButton({
    required this.theaterCase,
    required this.canWrite,
    this.compact = true,
  });

  final TheaterCase theaterCase;
  final bool canWrite;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = _nextActionLabel(context, theaterCase);
    final bool isTerminal = theaterCase.normalizedStatus == 'CANCELLED' ||
        theaterCase.normalizedStatus == 'COMPLETED';
    if (isTerminal || !canWrite) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return AppButton(
      label: label,
      size: compact ? AppButtonSize.small : AppButtonSize.medium,
      onPressed: () => _runTheaterNextAction(context, ref, theaterCase),
    );
  }
}
```

Add `_runTheaterNextAction(BuildContext context, WidgetRef ref, TheaterCase theaterCase)` that mirrors `_nextActionLabel` branches and calls the **same** dialog functions as `_TheaterActionBar`:

- `!isReady` → `_showChecklistDialog`
- `SCHEDULED` → `_showStageDialog`
- `!hasFinalAnesthesia` → `_showAnesthesiaDialog`
- `!hasFinalPostOp` → `_showPostOpDialog`
- else → `_showHandoverDialog`

Gate `onPressed` with `canWrite` and `state.isMutating` where applicable (read from provider).

### Search chrome

Update `AppListTableSearch<TheaterCase>` in `_TheaterCaseBoard`:

```dart
search: AppListTableSearch<TheaterCase>(
  controller: searchController,
  semanticLabel: l10n.theaterSearchLabel,
  hintText: l10n.theaterSearchHint,
  clearLabel: l10n.theaterClearFiltersAction,
  matcher: (TheaterCase item, String query) =>
      theaterTableSearchMatcher(context, item, query),
  onSubmitted: controller.applySearch,
  onClear: () => controller.applySearch(''),
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.theaterFiltersLabel,
  advancedFilterTitle: l10n.theaterAdvancedFiltersTitle,
  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
  advancedFilterResetLabel: l10n.theaterClearFiltersAction,
  // ... preserve existing dateFilter, textFilters, filterGroups, onFilterChanged ...
),
```

On `AppListTable`:

```dart
columns: _defaultColumnsForSection(context, section),
columnChoices: _columnChoicesForSection(context),
columnVisibilityController: columnVisibilityController,
columnVisibilityStorageKey: 'theater_${section.name}',
columnWidthStorageKey: 'theater_cw_${section.name}',
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.theaterTableSettingsTitle,
displayMode: AppListTableDisplayMode.adaptive,
```

Keep server-side search: `onSubmitted` / `onClear` continue calling `controller.applySearch`. The matcher provides local filtering parity on the current page (required by `prompt.md` and tests).

### Search matcher (must cover all columns including hidden)

Add `theaterTableSearchMatcher(BuildContext context, TheaterCase item, String query)` searching:

- `effectiveDisplayId`, `procedureName`
- `patientDisplayName`, `patientDisplayId`, `encounterDisplayId`
- Formatted `scheduledAt` via `_formatDateTime`
- `roomDisplayLabel`, `roomDisplayId`, `_roomLabel`
- `status` raw + `_caseStatusLabel`
- `workflowStage` raw + `_stageLabel`
- `_readinessLabel`, `_responsibleRoleLabel`
- `_nextActionLabel`
- Surgeon/anesthetist display IDs if present on `TheaterCase`

Use case-insensitive substring match (follow Claims/Emergency matcher style).

### Row interaction (preserve)

- `onRowSelected` → `_openTheaterCaseDialog(context, ref, state, item, canWrite)`
- Next-action button must open the **same** dialog as the corresponding `_TheaterActionBar` action — never navigate to generic `/theater` home

### Mobile builder

Update `_TheaterCaseListTile` to accept `canWrite` and include `_TheaterNextActionButton(compact: true)` aligned with desktop. Show `AppWorkspaceStatusBadge` instead of `_TheaterStatusBadge` for parity.

Signature change:

```dart
mobileItemBuilder: (BuildContext context, TheaterCase item) {
  return _TheaterCaseListTile(theaterCase: item, canWrite: canWrite);
},
```

---

## Implementation Steps

### 1. Add l10n keys (`frontend/lib/l10n/app_en.arb` only)

```json
"theaterAdvancedFiltersTitle": "Advanced filters",
"@theaterAdvancedFiltersTitle": {
  "description": "Advanced filters modal title for the theater worklist table chrome."
},
"theaterTableSettingsTitle": "Table Settings",
"@theaterTableSettingsTitle": {
  "description": "Table Settings modal title for the theater worklist."
}
```

Run codegen: `cd frontend && flutter gen-l10n` (or project-standard l10n command).

### 2. Pass `section` into `_TheaterCaseBoard`

In `_TheaterWorkspaceContentState.build` (L417–423), add `section: _section`.

Update `_TheaterCaseBoard` constructor and fields to accept `TheaterSection section`.

### 3. Extract column helpers and section column builders

- Create `frontend/lib/features/theater/presentation/widgets/theater_workspace_widgets.dart` (recommended) or keep private top-level functions in the page file.
- Move/re-export column builders, `theaterTableSearchMatcher`, `_TheaterNextActionButton`, `_runTheaterNextAction`.
- Implement `_defaultColumnsForSection` and `_columnChoicesForSection`.
- Replace `_TheaterStatusBadge` in the **table status column** with `AppWorkspaceStatusBadge(status: AppWorkspaceStatus(label: _caseStatusLabel(...), tone: _statusTone(...)))`. You may keep `_TheaterStatusBadge` elsewhere if still used in mobile until updated.

### 4. Refactor `_TheaterCaseBoard.build`

- Wire standardized search chrome (`theaterAdvancedFiltersTitle`, `theaterTableSettingsTitle`).
- Set `columnVisibilityStorageKey`, `columnWidthStorageKey`, `columnChoices`, `displayMode`.
- Replace inline 9-column list with `_defaultColumnsForSection(context, section)`.
- Replace `theaterNextActionColumn` `Text` cell with `_TheaterNextActionButton`.
- Update `mobileItemBuilder` for action parity.

### 5. Delete dead code

- Remove the old 9-column inline `columns: <AppListTableColumn<TheaterCase>>[...]` block once helpers are wired.
- Remove `_TheaterStatusBadge` if no longer referenced.

### 6. Update tests

File: `frontend/test/features/theater/presentation/theater_workspace_page_test.dart`

- Assert ≤5 default columns via `_table(tester).columns.length`.
- Assert `columnVisibilityStorageKey` matches active tab (e.g. `theater_scheduled`).
- Assert Advanced filters modal title **"Advanced filters"** and Settings modal title **"Table Settings"** when opened.
- Assert next-action column contains `AppButton` (or project action widget) for actionable scheduled case.
- Assert mobile viewport shows next-action control.
- Preserve existing tests: tab counts, filter application, deep links, read-only toolbar.

---

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `components.dart` | Session column visibility |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/layout.dart` | Status column |
| `AppButton` | `components.dart` | Next-action column (intra-module dialogs) |
| `AppListItemText` / `_TwoLineCell` pattern | existing in page | Patient, room cells |
| `_openTheaterCaseDialog` + action dialogs | `theater_workspace_page.dart` | Row tap + next-action destinations |

---

## Files to Create / Modify / Delete

| File | Action |
|------|--------|
| `frontend/lib/features/theater/presentation/widgets/theater_workspace_widgets.dart` | **Create** (recommended) — column helpers, matcher, next-action button |
| `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart` | **Modify** — board wiring, section param, remove inline columns |
| `frontend/lib/l10n/app_en.arb` | **Modify** — `theaterAdvancedFiltersTitle`, `theaterTableSettingsTitle` |
| `frontend/test/features/theater/presentation/theater_workspace_page_test.dart` | **Modify** — compliance assertions |

No files to delete. No API/repository changes.

---

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule).
- Reuse `commonTableSettingsActionLabel` for the Settings **button** label.
- Use new `theaterAdvancedFiltersTitle` / `theaterTableSettingsTitle` for modal titles (do not reuse `theaterFiltersLabel` as modal title).

---

## Database Migrations

No database migrations required — schema unchanged.

---

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/theater/
```

---

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per `theater_${section.name}` key
- [ ] ≤5 default columns per tab; row number automatic
- [ ] Workflow tables: explicit status badge + pressable next-action with verb labels from `_nextActionLabel`
- [ ] Row tap opens `_openTheaterCaseDialog`
- [ ] Mobile list shows same priority fields + status + next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions (`canWrite` disables next-action presses)
- [ ] Server-side `applySearch` still works on submit/clear

---

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved (filters, counts, dialogs, recovery filter semantics)
- [ ] Analyze clean; tests pass
