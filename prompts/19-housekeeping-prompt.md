# Standardize Housekeeping Tables

## Objective

Refactor every `AppListTable` on the Housekeeping workspace (`/housekeeping`, `HousekeepingWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, unrelated screen chrome (tab strip, report preview toolbar, advanced-filter field definitions), or detail-dialog internals unless required for compilation.

## Current State (from audit)

### Screen wiring

| Field | Value |
|-------|-------|
| Route | `/housekeeping` (`AppRoutes.housekeeping`) |
| Page | `HousekeepingWorkspacePage` → `_HousekeepingWorkspaceContent` |
| Primary file | `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` |
| Controller | `housekeepingWorkspaceControllerProvider` (`HousekeepingWorkspaceController`) |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.housekeeping` + `WorkspaceRefreshProfile.operations` |
| Detail dialog | `_openTaskDetailDialog` → `AppDialog` + `_HousekeepingDetailPanel` + `_DetailActions` |
| Tabs | `HousekeepingSection`: `tasks`, `schedules`, `maintenance` |
| Deep link | `?section=<value>` (`tasks`, `schedules`, `maintenance`) and `?search=<text>` — **not** `?panel=` |

### Table inventory (one widget, three tab column profiles)

| # | Table widget | File | Entity | Tab binding | Declared columns today | Detail on row select |
|---|--------------|------|--------|-------------|------------------------|----------------------|
| 1 | `_HousekeepingWorklistPanel` | `housekeeping_workspace_page.dart` | `HousekeepingWorkItem` | `HousekeepingSection` via `_columnsForSection` | **6 per tab** (see matrix) | `onRowSelected` → `_openTaskDetailDialog` ✓ |

### Per-tab column matrix (current)

**Tasks tab** (`_taskColumns`) — 6 columns:

| Position | id (missing today) | Label (l10n) | Source field | Notes |
|----------|-------------------|--------------|--------------|-------|
| 1 | — | `housekeepingTaskColumnLabel` ("Task") | `title` + `effectiveDisplayId` | `_CopyableTaskCell` (two-line, one field ✓) |
| 2 | — | `housekeepingLocationColumnLabel` | `locationDisplay` | |
| 3 | — | `housekeepingAssigneeColumnLabel` | `assigneeLabel` | |
| 4 | — | `housekeepingDueColumnLabel` | `scheduledAt` | |
| 5 | — | `housekeepingStatusColumnLabel` | `status` | `_HousekeepingStatusBadge` → `AppWorkspaceStatusBadge` ✓ |
| 6 | — | `housekeepingNextActionColumnLabel` | `_nextActionLabel(...)` | **Plain `Text`**, not an action control |

**Schedules tab** (`_scheduleColumns`) — 6 columns:

| Position | Label (l10n) | Source field | Notes |
|----------|--------------|--------------|-------|
| 1 | `housekeepingScheduleColumnLabel` | `title` + `effectiveDisplayId` | `_CopyableTaskCell` |
| 2 | `housekeepingLocationColumnLabel` | `locationDisplay` | |
| 3 | `housekeepingFrequencyColumnLabel` | `subtitle` (frequency) | |
| 4 | `housekeepingStartDateColumnLabel` | `startDate` | |
| 5 | `housekeepingEndDateColumnLabel` | `endDate` | |
| 6 | `housekeepingStatusColumnLabel` | `status` | `_HousekeepingStatusBadge` |

**Missing on schedules:** next-action column (logic exists in `_nextActionLabel` → `housekeepingNextActionReviewSchedule` but not rendered).

**Maintenance tab** (`_maintenanceColumns`) — 6 columns:

| Position | Label (l10n) | Source field | Notes |
|----------|--------------|--------------|-------|
| 1 | `housekeepingRequestColumnLabel` | `title` + `effectiveDisplayId` | `_CopyableTaskCell` |
| 2 | `housekeepingLocationColumnLabel` | `locationDisplay` | |
| 3 | `housekeepingAssetColumnLabel` | `assetLabel` | |
| 4 | `housekeepingReportedColumnLabel` | `reportedAt` | |
| 5 | `housekeepingStatusColumnLabel` | `status` | `_HousekeepingStatusBadge` |
| 6 | `housekeepingNextActionColumnLabel` | `_nextActionLabel(...)` | **Plain `Text`**, not an action control |

**Automatic row-number column:** Not declared (correct).

### Search chrome (current)

`_HousekeepingWorklistPanel` uses `AppListTableSearch<HousekeepingWorkItem>` with:

- `showAdvancedFilterButton: true` ✓
- `advancedFilterButtonLabel: l10n.housekeepingFiltersAction` → **"Filters"** ✓
- `advancedFilterTitle: l10n.housekeepingFiltersTitle` → **"Housekeeping filters"** — must be **"Advanced filters"**
- `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → **"Settings"** ✓
- **Missing:** `columnVisibilityTitle` on `AppListTable` (must be **"Table Settings"**)
- **Missing:** `columnChoices` — all 6 columns are in `columns` only
- **Blocker:** `matcher: (_, _) => true` — search does not match column values; defers entirely to server `applySearch`
- No export/refresh/overflow in search chrome ✓

### Session persistence (current)

- `AppListTableColumnVisibilityController<HousekeepingWorkItem>` owned by `_HousekeepingWorkspaceContentState` ✓
- `columnVisibilityStorageKey: 'housekeeping_${section.name}'` ✓ (per tab)
- `columnWidthStorageKey: 'housekeeping_cw_${section.name}'` ✓
- Backed by `AppListTableColumnVisibilityMemory` (session scope) ✓

### Row interaction (current)

- `onRowSelected` → `_openTaskDetailDialog` ✓
- `_DetailActions` exposes Assign, Start, Complete, Cancel, Triage, Complete/Cancel request — aligned with workflow ✓
- Next-action column renders label text only; does not open dialogs or trigger mutations ✗

### Responsiveness (current)

- `displayMode` not set → defaults to `AppListTableDisplayMode.adaptive` ✓
- `mobileItemBuilder` per section (`_taskMobileItem`, `_scheduleMobileItem`, `_maintenanceMobileItem`) ✓
- **Gaps:** mobile rows show status badge in `trailing` but **no next-action control**; priority fields differ from post-refactor desktop defaults

### Realtime (current)

- `HousekeepingWorkspaceController.build()` wires `listenForRealtimeRefresh` with `RealtimeEventGroups.housekeeping` ✓
- Table reads `state.items` from provider; `isLoading: state.isRefreshing` ✓
- Do **not** modify controller/repository sync wiring.

### Gap list vs `prompt.md`

| Gap | Severity |
|-----|----------|
| 6 declared columns per tab (max 5) | **Blocker** |
| No `columnChoices` for lower-priority fields | **Blocker** |
| Search `matcher` is stub `(_, _) => true` | **Blocker** |
| Next-action column is `Text`, not explicit action control | **Blocker** |
| Schedules tab missing next-action column | **Blocker** |
| `advancedFilterTitle` is "Housekeeping filters", not "Advanced filters" | High |
| Missing `columnVisibilityTitle` ("Table Settings") | Medium |
| Columns lack stable `id` strings | Medium |
| Mobile rows missing next-action button | High |
| Tests assert 6-column layout on tasks tab | Must update |

### Workflow / next-action semantics

Housekeeping items are **not** encounter-scoped; do **not** use `WorkflowActionButton` (requires `encounterId` + `WorkflowActionRegistry`). Use an explicit `AppButton` cell (copy `_NextActionCell` pattern from `patient_registry_page.dart`).

| Resource / condition | Status display | Next-action label (l10n) | Handler (same as detail dialog) |
|----------------------|----------------|---------------------------|----------------------------------|
| Task, `PENDING`, no `assigneeId`, `canManage` | `_HousekeepingStatusBadge` | `housekeepingNextActionAssign` | `_showAssignDialog` |
| Task, `PENDING`, `canUpdateTasks` | badge | `housekeepingNextActionStart` | `_confirmTaskAction` → `startTask` |
| Task, `IN_PROGRESS`, `canUpdateTasks` | badge | `housekeepingNextActionComplete` | `_confirmTaskAction` → `completeTask` |
| Task, terminal (`COMPLETED`/`CANCELLED`) | badge | `housekeepingNextActionNoAction` | disabled / no-op |
| Task, other / read-only | badge | `housekeepingNextActionView` | `_openTaskDetailDialog` |
| Schedule (any) | badge (`housekeepingStatusScheduled`) | `housekeepingNextActionReviewSchedule` | `_openTaskDetailDialog` |
| Maintenance, not terminal, `canManage` | badge | `housekeepingNextActionTriage` | `_showTriageDialog` |
| Maintenance, terminal or read-only | badge | `housekeepingNextActionView` / `housekeepingNextActionNoAction` | detail dialog or disabled |

Reuse existing `_nextActionLabel(l10n, item, capabilities)` for label text; add `_HousekeepingNextActionCell` that resolves `onPressed` from the same conditions as `_DetailActions`.

### Permissions (preserve)

- `_HousekeepingCapabilities`: `canManage`, `canUpdateTasks`, `canReport` from `AppAccessPolicy` — do not change gating logic.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — table contract, `columnChoices`, visibility memory
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` search chrome, `_matchesSearch`, `AppWorkspaceStatusBadge`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn` (`alwaysVisible: true` on next-action)
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` — `_NextActionCell` (`AppButton` + permission gate pattern for non-workflow-registry entities)
- `prompt.md`

Copy patterns:

```dart
// Search chrome
search: AppListTableSearch<HousekeepingWorkItem>(
  matcher: _matchesHousekeepingSearch,
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel, // or housekeepingFiltersAction
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
  // ...
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,
```

```dart
// Next-action cell (non-WorkflowActionButton)
AppButton.tertiary(
  label: actionLabel,
  onPressed: enabled ? () => _handleNextAction(context, ref, item) : null,
)
```

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|----------------------------------|----------------------------|
| `_HousekeepingWorklistPanel` | Tasks | `HousekeepingWorkItem` | task, location, assignee, status, next_action | `housekeeping_tasks` |
| `_HousekeepingWorklistPanel` | Schedules | `HousekeepingWorkItem` | schedule, location, frequency, status, next_action | `housekeeping_schedules` |
| `_HousekeepingWorklistPanel` | Maintenance | `HousekeepingWorkItem` | request, location, asset, status, next_action | `housekeeping_maintenance` |

### Column plan (per tab)

Every `AppListTableColumn` **must** have a stable `id`. Status column is second-from-right; next-action is rightmost with `alwaysVisible: true`.

**Tasks — default `columns` (5):**

| id | Label (l10n) | Source | Notes |
|----|--------------|--------|-------|
| `task` | `housekeepingTaskColumnLabel` | `title` + `effectiveDisplayId` | `AppListItemText` or keep `_CopyableTaskCell` |
| `location` | `housekeepingLocationColumnLabel` | `locationDisplay` | `_locationLabel` |
| `assignee` | `housekeepingAssigneeColumnLabel` | `assigneeLabel` | fallback `housekeepingUnassigned` |
| `status` | `housekeepingStatusColumnLabel` | `status` | `_HousekeepingStatusBadge` |
| `next_action` | `housekeepingNextActionColumnLabel` | workflow | `_HousekeepingNextActionCell`, `alwaysVisible: true` |

**Tasks — `columnChoices`:** `due` (`scheduledAt`, label `housekeepingDueColumnLabel`)

**Schedules — default `columns` (5):**

| id | Label | Source |
|----|-------|--------|
| `schedule` | `housekeepingScheduleColumnLabel` | `title` + `effectiveDisplayId` |
| `location` | `housekeepingLocationColumnLabel` | `locationDisplay` |
| `frequency` | `housekeepingFrequencyColumnLabel` | `subtitle` |
| `status` | `housekeepingStatusColumnLabel` | `status` |
| `next_action` | `housekeepingNextActionColumnLabel` | review schedule |

**Schedules — `columnChoices`:** `start_date`, `end_date`

**Maintenance — default `columns` (5):**

| id | Label | Source |
|----|-------|--------|
| `request` | `housekeepingRequestColumnLabel` | `title` + `effectiveDisplayId` |
| `location` | `housekeepingLocationColumnLabel` | `locationDisplay` |
| `asset` | `housekeepingAssetColumnLabel` | `assetLabel` |
| `status` | `housekeepingStatusColumnLabel` | `status` |
| `next_action` | `housekeepingNextActionColumnLabel` | triage / view |

**Maintenance — `columnChoices`:** `reported` (`reportedAt`)

Wire on `AppListTable<HousekeepingWorkItem>`:

```dart
AppListTable<HousekeepingWorkItem>(
  columns: defaultColumns,       // ≤ 5
  columnChoices: optionalColumns,
  columnVisibilityStorageKey: 'housekeeping_${section.name}',
  columnWidthStorageKey: 'housekeeping_cw_${section.name}',
  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
  columnVisibilityTitle: l10n.commonTableSettingsTitle,
  displayMode: AppListTableDisplayMode.adaptive,
  // ...
)
```

### Search chrome (per table)

Implement `_matchesHousekeepingSearch(HousekeepingWorkItem item, String query, AppLocalizations l10n, HousekeepingSection section, _HousekeepingCapabilities capabilities)` indexing **all** display strings for default and hidden columns:

- `title`, `effectiveDisplayId`, `subtitle`, `locationDisplay`, `assigneeLabel`, formatted dates (`_dateTimeLabel` values), `assetLabel`
- Formatted status: `_statusLabel(l10n, item)`
- Next-action label: `_nextActionLabel(l10n, item, capabilities)`
- Section-specific: frequency, etc.

Keep server-side `onSubmitted: controller.applySearch` — client matcher is for in-page filtering UX per `AppListTableSearch` contract (match Mortuary `_matchesSearch` + repository search behavior).

- `advancedFilterButtonLabel`: prefer `l10n.commonFiltersActionLabel` (add key **"Filters"**) or keep `housekeepingFiltersAction`
- `advancedFilterTitle`: `l10n.commonAdvancedFiltersTitle` (**"Advanced filters"**)
- Do not add trailing controls beyond Filters and Settings.

### Row interaction

- Keep `onRowSelected` → `_openTaskDetailDialog`.
- `_HousekeepingNextActionCell` must invoke the **same** dialogs as `_DetailActions` for the active label (assign, start, complete, triage, or detail).
- Stop action-button press propagation so row select does not double-fire (see `WorkflowActionButton` / `AppButton` table patterns).

### Mobile (`_taskMobileItem`, `_scheduleMobileItem`, `_maintenanceMobileItem`)

Rebuild to mirror desktop priority for each section:

- Title/subtitle: same as primary data column (task/schedule/request + location or frequency)
- Details: status badge + key meta fields matching visible data columns
- Trailing or inline: compact `_HousekeepingNextActionCell` (or shared builder)
- Row tap still handled by `AppListTable` `onRowSelected`

## Implementation Steps

1. **`frontend/lib/l10n/app_en.arb`**
   - Add `commonTableSettingsTitle`: **"Table Settings"**
   - Add `commonAdvancedFiltersTitle`: **"Advanced filters"**
   - Add `commonFiltersActionLabel`: **"Filters"** (if not present)
   - Run `flutter gen-l10n` during verification.

2. **`housekeeping_workspace_page.dart` — column refactor**
   - Add stable `id` to every `AppListTableColumn`.
   - Refactor `_taskColumns`, `_scheduleColumns`, `_maintenanceColumns` to return ≤5 defaults; extract hidden columns into `columnChoices` passed to `AppListTable`.
   - Add `next_action` column to schedules tab.
   - Add `columnVisibilityTitle: l10n.commonTableSettingsTitle`.
   - Set `displayMode: AppListTableDisplayMode.adaptive` explicitly.
   - Replace `Text(_nextActionLabel(...))` with `_HousekeepingNextActionCell` (`ConsumerWidget` or callback wiring to existing dialog functions).

3. **`housekeeping_workspace_page.dart` — search**
   - Replace `matcher: (_, _) => true` with `_matchesHousekeepingSearch`.
   - Update `advancedFilterTitle` to `l10n.commonAdvancedFiltersTitle`.
   - Optionally switch filter button label to `l10n.commonFiltersActionLabel`.

4. **`housekeeping_workspace_page.dart` — mobile**
   - Add next-action control to each mobile builder; align visible fields with per-tab default columns.

5. **`frontend/test/features/housekeeping/presentation/housekeeping_workspace_page_test.dart`**
   - Update `renders tab strip, task columns, and create task action`: expect ≤5 default headers (Due hidden by default; Next action visible).
   - Update schedules/maintenance tab column assertions for 5-column defaults.
   - Add test: Settings opens dialog titled **"Table Settings"**.
   - Add test: Filters opens modal titled **"Advanced filters"**.
   - Add test: next-action button visible on tasks row (e.g. tap **"Start cleaning"** or **"Assign staff or team"** opens expected dialog).
   - Keep existing: tab switching, deep link, filter dialog excludes resource, search submit, row detail dialog, narrow viewport mobile cards.

6. **Do not modify**
   - `HousekeepingWorkspaceController` realtime/mutation logic
   - `_filterGroupsForSection` field definitions
   - `housekeeping_repository` / DTOs / API contracts
   - Tab toolbar primary/secondary actions (Create task, report preview)

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `app_list_table.dart` (via components) | Session column visibility |
| `AppListItemText` / `AppListItemRow` | `components.dart` | Two-line task cell, mobile rows |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Status column (`_HousekeepingStatusBadge`) |
| `AppButton` | `components.dart` | Next-action column |
| `AppCopyableIdentifier` | `components.dart` | Reference/id subtitle in cells |
| `appListTableCompareText` / `appListTableCompareDateTime` | `app_list_table.dart` | Sort comparators |
| `showAppDialog` / `showAppWorkspaceActionDialog` | `components.dart` | Existing detail and action dialogs |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/housekeeping/presentation/housekeeping_workspace_page_test.dart` |
| Delete | None |

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- New shared keys: `commonTableSettingsTitle`, `commonAdvancedFiltersTitle`, `commonFiltersActionLabel` (if missing).
- Reuse existing housekeeping column and next-action keys (`housekeepingNextActionAssign`, `housekeepingNextActionStart`, etc.).

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/housekeeping/
```

Manual smoke (web or desktop):

1. Open `/housekeeping` — Tasks tab shows 5 default columns; Due available via Settings.
2. Switch to Schedules — 5 columns including Next action; Start/End date in Settings.
3. Switch to Maintenance — 5 columns; Reported in Settings.
4. Filters opens **"Advanced filters"**; Settings opens **"Table Settings"**.
5. Search matches location, assignee, or ID not in default visible columns (e.g. enable Due, search due date text).
6. Row tap and next-action both open the correct dialog (assign, start, triage, or detail).
7. Narrow viewport — mobile cards show status + next action.
8. Mutate a task (start/complete) — table refreshes without manual reload.

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per `housekeeping_<section>` key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels as `AppButton` controls
- [ ] Row tap opens detail dialog
- [ ] Mobile list shows same priority fields, status, and next action
- [ ] Realtime refresh still updates rows after mutations/events (controller untouched)
- [ ] Permissions still gate write actions (assign/start/complete/triage)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every `AppListTable` on `/housekeeping` (`_HousekeepingWorklistPanel` across all three tabs)
- [ ] Domain logic preserved (tab filters, counts, pagination, deep links, dialogs, permissions)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/housekeeping/` passes
