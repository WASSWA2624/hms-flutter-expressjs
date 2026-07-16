# Standardize Rooms & Beds Tables

## Objective

Refactor every `AppListTable` on the Rooms & Beds workspace (`/rooms-beds`, `RoomsBedsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, repository contracts, or unrelated screen chrome (tab toolbar primary/secondary actions, add-room/add-bed dialogs) unless required for compilation.

## Current State (from audit)

### Screen layout

| Field | Value |
|-------|-------|
| Route | `/rooms-beds` (`AppRoutes.roomsBeds`) |
| Page widget | `RoomsBedsWorkspacePage` |
| Primary file | `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart` |
| Content state | `_RoomsBedsWorkspaceContentState` |
| Provider | `roomsBedsWorkspaceControllerProvider` (`RoomsBedsWorkspaceController`) |
| Entity | `BedBoardItem` |
| Realtime | `RealtimeEventGroups.roomsBeds` via `listenForRealtimeRefresh` in controller |

**Important:** The generator pre-fill listed tabs "Bed board, Wards, Rooms" — that is **incorrect**. The live screen uses **status-section tabs** from `RoomsBedsSection`: `all`, `available`, `occupied`, `turnover`, `outOfService`. Deep-link query uses `?section=<value>` (not `?view=`). Values: `''` (all), `available`, `occupied`, `turnover`, `out-of-service`.

There is **one** `AppListTable<BedBoardItem>` instance. Section tabs do **not** swap tables; they client-filter the same page via `roomsBedsSectionFilteredPage(state.beds, _section)` before passing to the table.

### Table 1 — Bed board worklist

| Attribute | Current value |
|-----------|---------------|
| Widget location | `AppListTable<BedBoardItem>` inside `_RoomsBedsWorkspaceContentState.build` (~line 236) |
| Entity | `BedBoardItem` |
| Page source | `roomsBedsSectionFilteredPage(state.beds, _section)` |
| `columnVisibilityStorageKey` | `'rooms_beds_${_section.name}'` (per section — keep) |
| `columnWidthStorageKey` | `'rooms_beds_cw_${_section.name}'` (per section — keep) |
| `columnVisibilityController` | `_tableColumnController` (`AppListTableColumnVisibilityController<BedBoardItem>`) |
| `onRowSelected` | `_openBedDetailDialog(...)` — **already correct** |
| `displayMode` | Not set (defaults to `AppListTableDisplayMode.adaptive` — OK) |
| `columnChoices` | **Missing** |
| `columnVisibilityTitle` | **Missing** |
| `mobileItemBuilder` | `_BedMobileItem` — missing next-action control |

#### Current columns (5 declared — at budget limit)

| # | Label (l10n) | Field / builder | Sort | Notes |
|---|--------------|-----------------|------|-------|
| 1 | `roomsBedsBedColumnLabel` | `item.label` + `item.facility?.name` subtitle via `_TwoLineCell` | `left.label` vs `right.label` | Facility is a **separate** semantic field — move to `columnChoices` |
| 2 | `roomsBedsLocationColumnLabel` | `_locationLabel` (ward \| room \| floor) | location text | Single computed location field — OK |
| 3 | `roomsBedsStatusColumnLabel` | `AppWorkspaceStatusBadge(roomsBedsStatusBadge(...))` | `status.apiValue` | Correct position for workflow status (col 4 of 5) |
| 4 | `roomsBedsAssignmentColumnLabel` | `_assignmentLabel` | assignment text | Priority data column |
| 5 | `roomsBedsNextActionColumnLabel` | `Text(roomsBedsNextActionLabel(...))` | next-action label text | **Not interactive**; uses compound labels |

No column `id` values are set on any `AppListTableColumn`.

#### Search chrome gaps

| Issue | Current | Required |
|-------|---------|----------|
| Matcher | `matcher: (_, _) => true` (stub) | Real matcher over all visible + hidden column fields |
| Filters button label | `l10n.roomsBedsFiltersLabel` ("Filters") | OK — prefer `commonFiltersActionLabel` if added |
| Advanced filters modal title | `advancedFilterTitle: l10n.roomsBedsFiltersLabel` ("Filters") | **"Advanced filters"** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` | OK |
| Settings modal title | **Missing** `columnVisibilityTitle` | **"Table Settings"** |
| Extra chrome actions | None in search bar | OK — refresh/manage catalog correctly live in tab toolbar |

Server-side search already exists: `BedBoardItem.matchesSearch` in `rooms_beds_entities.dart` and `controller.applySearch`. The table matcher must additionally cover formatted display values (status label, readiness, next-action label) and hidden `columnChoices` fields for in-page filtering consistency.

#### Next-action gaps

`roomsBedsNextActionLabel` in `rooms_beds_status_helpers.dart` returns **compound** labels for some states:

| Status | Current label key | Problem |
|--------|-------------------|---------|
| `occupied` (no transfer) | `roomsBedsNextActionReleaseOrTransfer` | Compound — not a single verb |
| `reserved` | `roomsBedsNextActionAssignOrReleaseHold` | Compound |
| `available` | `roomsBedsNextActionAssign` | OK |
| `occupied` + transfer | `roomsBedsNextActionCompleteTransfer` | OK |
| `cleaning` | `roomsBedsNextActionMarkAvailable` | OK |
| `maintenance` | `roomsBedsNextActionResolveMaintenance` | OK |
| `blocked` / `outOfService` | `roomsBedsNextActionResolveBlock` | OK |

Next-action column renders plain `Text` — no press handler. `WorkflowActionButton` does **not** apply (beds are not shared-workflow encounters). Module needs a dedicated `RoomsBedsNextActionButton`.

#### Mobile gaps

`_BedMobileItem` shows bed label, location + assignment subtitle, status badge — **no next-action button**.

#### Other gaps

- `_TwoLineCell` private widget duplicates `AppListItemText`
- Column visibility persistence wired but no `columnChoices` to hide extras
- Permissions preserved via `canAdminBeds` / `canIpdWrite` in detail dialog — next-action button must respect same gates

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `columnChoices`, `displayMode`
- `frontend/lib/shared/components/app_list_item_text.dart` — `AppListItemText`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings chrome, `_matchesSearch`, `columnChoices`, `columnVisibilityTitle`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, `WorkflowActionButton` (pattern for interactive next-action column; beds use module equivalent instead)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — `WorkflowActionButton` with `alwaysVisible: true` on next-action column
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|----------------------------------|----------------------------|
| `AppListTable<BedBoardItem>` in `_RoomsBedsWorkspaceContentState` | `RoomsBedsSection.all` | `BedBoardItem` | bed, location, assignment, status, next_action | `rooms_beds_all` |
| Same table instance | `RoomsBedsSection.available` | `BedBoardItem` | same column set | `rooms_beds_available` |
| Same table instance | `RoomsBedsSection.occupied` | `BedBoardItem` | same column set | `rooms_beds_occupied` |
| Same table instance | `RoomsBedsSection.turnover` | `BedBoardItem` | same column set | `rooms_beds_turnover` |
| Same table instance | `RoomsBedsSection.outOfService` | `BedBoardItem` | same column set | `rooms_beds_outOfService` |

Column definitions are **shared across sections** (only the filtered row set changes). Do not create per-section column arrays unless a section truly needs different defaults (none do today).

### Column plan (Bed board table)

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `bed` | `roomsBedsBedColumnLabel` | `item.label` | `AppListItemText` with no subtitle in default view |
| 2 | `location` | `roomsBedsLocationColumnLabel` | `_locationLabel(context, item)` | ward + room + floor as one location display |
| 3 | `assignment` | `roomsBedsAssignmentColumnLabel` | `_assignmentLabel(context, item)` | current admission display |
| 4 | `status` | `roomsBedsStatusColumnLabel` | `roomsBedsStatusBadge(l10n, item.status)` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | `roomsBedsNextActionColumnLabel` | primary next action | `RoomsBedsNextActionButton`; `alwaysVisible: true` |

### Hidden column choices (`columnChoices` — not in default 5)

| Column id | Label | Source field |
|-----------|-------|--------------|
| `facility` | `roomsBedsFacilityFilterLabel` | `item.facility?.name` |
| `readiness` | `roomsBedsReadinessLabel` | `roomsBedsReadinessLabel(l10n, item)` |
| `room_floor` | New key `roomsBedsFloorColumnLabel` ("Floor") | `item.room?.floor` |

Pass `columnChoices: roomsBedsBedBoardColumnChoices(l10n)` (extract to helper) alongside `columns: roomsBedsBedBoardColumns(...)`.

### Search chrome (Bed board table)

```dart
search: AppListTableSearch<BedBoardItem>(
  controller: _searchController,
  semanticLabel: l10n.roomsBedsSearchLabel,
  hintText: l10n.roomsBedsSearchHint,
  matcher: roomsBedsBedBoardSearchMatcher, // new function
  onSubmitted: (value) async { /* keep controller.applySearch */ },
  onClear: () async { /* keep controller.applySearch('') */ },
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.commonFiltersActionLabel, // or roomsBedsFiltersLabel
  advancedFilterTitle: l10n.commonAdvancedFiltersTitle,       // "Advanced filters"
  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
  advancedFilterResetLabel: l10n.opdClearFiltersAction,
  enableDateFilter: false,
  allFieldsLabel: l10n.roomsBedsAllFilterLabel,
  filterGroups: /* keep existing facility/ward/room/status groups */,
  filterValue: _filterValue(state.query),
  hasActiveFilters: state.query.hasFilters,
  onFilterChanged: /* keep existing handler */,
),
```

On `AppListTable`:

```dart
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle, // "Table Settings"
columnVisibilityController: _tableColumnController,
columnVisibilityStorageKey: 'rooms_beds_${_section.name}',
columnWidthStorageKey: 'rooms_beds_cw_${_section.name}',
displayMode: AppListTableDisplayMode.adaptive,
columnChoices: roomsBedsBedBoardColumnChoices(l10n),
```

### Search matcher (`roomsBedsBedBoardSearchMatcher`)

Add to `frontend/lib/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart` (or a new `rooms_beds_table_helpers.dart` in the same folder):

```dart
bool roomsBedsBedBoardSearchMatcher(BedBoardItem item, String query) {
  final AppLocalizations l10n = /* pass via closure or use a builder that captures l10n */;
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return <String?>[
    item.id,
    item.label,
    item.facility?.name,
    item.ward?.name,
    item.room?.name,
    item.room?.floor,
    item.currentAdmissionDisplayId,
    item.currentAdmissionId,
    item.status.apiValue,
    roomsBedsStatusLabel(l10n, item.status),
    roomsBedsReadinessLabel(l10n, item),
    roomsBedsPrimaryNextActionLabel(l10n, item),
    _assignmentSearchText(l10n, item), // mirror _assignmentLabel logic
    _locationSearchText(item),
  ].whereType<String>().any((v) => v.toLowerCase().contains(needle));
}
```

Because `AppListTableSearch.matcher` cannot take `l10n` directly, implement as a factory:

```dart
bool Function(BedBoardItem, String) roomsBedsBedBoardSearchMatcher(AppLocalizations l10n) =>
    (item, query) => /* body above */;
```

Wire: `matcher: roomsBedsBedBoardSearchMatcher(l10n)`.

Also keep `BedBoardItem.matchesSearch` for server-side controller filtering — do not remove it.

### Primary next-action resolution

Add to `rooms_beds_status_helpers.dart`:

```dart
enum RoomsBedsNextActionKind {
  assign,
  release,
  completeTransfer,
  markAvailable,
  openHousekeeping,
  openOperations,
  viewDetail, // fallback when user lacks permission
}

RoomsBedsNextActionKind roomsBedsPrimaryNextActionKind(BedBoardItem item);

String roomsBedsPrimaryNextActionLabel(AppLocalizations l10n, BedBoardItem item);
```

**Resolution rules** (single explicit verb — never compound):

| `BedSetupStatus` | Condition | `RoomsBedsNextActionKind` | Label key |
|------------------|-----------|---------------------------|-----------|
| `available` | — | `assign` | `roomsBedsAssignAction` |
| `occupied` | `item.hasOpenTransfer` | `completeTransfer` | `roomsBedsManageTransferAction` |
| `occupied` | else | `release` | `roomsBedsReleaseAction` |
| `reserved` | — | `assign` | `roomsBedsAssignAction` (primary over release-hold) |
| `cleaning` | — | `markAvailable` | `roomsBedsMarkAvailableAction` |
| `maintenance` | — | `openOperations` | `roomsBedsOpenOperationsAction` |
| `blocked` | — | `markAvailable` | `roomsBedsMarkAvailableAction` |
| `outOfService` | — | `openOperations` | `roomsBedsOpenOperationsAction` |

Deprecate display-only use of `roomsBedsNextActionReleaseOrTransfer` and `roomsBedsNextActionAssignOrReleaseHold` in the table column (keep keys in arb for backward compatibility or repurpose in tests only).

### `RoomsBedsNextActionButton` widget

Create `frontend/lib/features/rooms_beds/presentation/widgets/rooms_beds_next_action_button.dart`:

- `ConsumerWidget` taking `BedBoardItem item`, `RoomsBedsWorkspaceState state`, `bool canAdminBeds`, `bool canIpdWrite`
- Renders compact tertiary `AppButton` (match visual weight of `WorkflowActionButton` with `compact: true`)
- Label from `roomsBedsPrimaryNextActionLabel`
- `onPressed` dispatches to the **same handlers** as `_BedDetailContent` / `_openBedDetailDialog` follow-ups:
  - `assign` → `_showAssignDialog` (requires `canIpdWrite` + `item.isAvailable`)
  - `release` → `_showReleaseDialog` (requires `canIpdWrite` + occupied + admission)
  - `completeTransfer` → `_showTransferUpdateDialog`
  - `markAvailable` → `_updateBedStatus(..., BedSetupStatus.available)` (requires `canAdminBeds`)
  - `openHousekeeping` → `context.go(AppRoutes.housekeeping.location())`
  - `openOperations` → `context.go(AppRoutes.operations.location())`
  - `viewDetail` / disabled → open `_openBedDetailDialog` or show disabled button with tooltip
- Stop row-tap propagation (wrap with `GestureDetector`/`InkWell` that calls `stopPropagation` pattern used by `WorkflowActionButton`)
- When permission denies the primary action, show disabled button with semantic label explaining why (mirror detail dialog `enabled` logic)

Extract shared dialog functions from `rooms_beds_workspace_page.dart` into the widget file or a `rooms_beds_dialogs.dart` barrel only if needed to avoid circular imports — prefer keeping dialogs in the page and passing callbacks into the button widget.

### Row interaction

- Keep `onRowSelected` → `_openBedDetailDialog`
- Next-action button must trigger the same destination as the corresponding button inside `_BedDetailContent`
- Detail dialog title: `l10n.roomsBedsDetailTitle`; content: `_BedDetailContent`

### Mobile item builder

Replace `_BedMobileItem` body to mirror desktop priority fields:

```dart
mobileItemBuilder: (context, item) => RoomsBedsBedMobileItem(
  item: item,
  state: state,
  canAdminBeds: canAdminBeds,
  canIpdWrite: canIpdWrite,
),
```

`RoomsBedsBedMobileItem` must show: bed label, location, assignment (subtitle), status badge, and `RoomsBedsNextActionButton` as trailing/secondary action.

## Implementation Steps

### 1. Add shared l10n keys (`frontend/lib/l10n/app_en.arb` only)

```json
"commonFiltersActionLabel": "Filters",
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"roomsBedsFloorColumnLabel": "Floor"
```

Run codegen if the project requires it after arb edits.

### 2. Extend `rooms_beds_status_helpers.dart`

- Add `roomsBedsPrimaryNextActionKind`, `roomsBedsPrimaryNextActionLabel`
- Add `roomsBedsBedBoardSearchMatcher` factory
- Add `roomsBedsBedBoardColumns` and `roomsBedsBedBoardColumnChoices` builders (accept `AppLocalizations` + action callbacks)
- Keep existing `roomsBedsStatusBadge`, `roomsBedsSectionFilteredPage`, etc. unchanged

### 3. Create `rooms_beds_next_action_button.dart`

- Implement `RoomsBedsNextActionButton` per Target Architecture
- Export from feature if needed; import in workspace page

### 4. Refactor `rooms_beds_workspace_page.dart` — Bed board table

- Replace inline `columns:` with `roomsBedsBedBoardColumns(...)`
- Add `columnChoices:`
- Fix search chrome labels/titles per Target Architecture
- Wire `matcher: roomsBedsBedBoardSearchMatcher(l10n)`
- Set `columnVisibilityTitle: l10n.commonTableSettingsTitle`
- Set `displayMode: AppListTableDisplayMode.adaptive` explicitly
- Replace `_TwoLineCell` bed column with `AppListItemText(title: item.label)`
- Replace next-action `Text` cell with `RoomsBedsNextActionButton`
- Update `_BedMobileItem` → `RoomsBedsBedMobileItem` with next-action parity
- Remove unused `_TwoLineCell` if no longer referenced
- Pass `canAdminBeds` / `canIpdWrite` into column builders and mobile item

### 5. Do NOT change

- `RoomsBedsWorkspaceController` domain methods (`assignBed`, `releaseBed`, `updateBedStatus`, `requestTransfer`, `updateTransfer`, `refresh`, filter apply methods)
- Tab toolbar primary/secondary actions (`_buildPrimaryAction`, `_buildSecondaryActions`)
- Route query handling (`RoomsBedsQuery.fromUri`, `?section=` deep links)
- `_openBedDetailDialog` / `_BedDetailContent` action logic (only reuse from next-action button)

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableColumnVisibilityMemory` | same (via controller) | Persistence backing |
| `AppListItemText` | same | Two-line bed cell when needed in choices |
| `AppWorkspaceStatusBadge` | same | Status column |
| `AppButton` | same | `RoomsBedsNextActionButton` |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | **Do not use** for beds — reference only |
| `roomsBedsStatusBadge` / helpers | `package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart` | Status + search + column builders |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart` |
| Modify | `frontend/lib/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart` |
| Create | `frontend/lib/features/rooms_beds/presentation/widgets/rooms_beds_next_action_button.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/rooms_beds/presentation/rooms_beds_status_helpers_test.dart` (add tests for primary next-action + matcher) |
| Optional create | `frontend/test/features/rooms_beds/presentation/rooms_beds_next_action_button_test.dart` |
| Delete | `_TwoLineCell` from workspace page if fully replaced |

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer new shared keys: `commonFiltersActionLabel`, `commonAdvancedFiltersTitle`, `commonTableSettingsTitle`
- Reuse existing: `commonTableSettingsActionLabel`, `opdApplyFiltersAction`, `opdClearFiltersAction`
- Keep module-specific column/filter labels (`roomsBedsBedColumnLabel`, etc.)

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/rooms_beds/
```

## Testing Requirements

- [ ] Bed board table: search bar shows only Filters + Settings trailing actions
- [ ] Advanced filters modal title is "Advanced filters"
- [ ] Table Settings modal title is "Table Settings"
- [ ] Column visibility persists per `rooms_beds_<section>` storage key
- [ ] Exactly 5 default columns; row number is automatic (not declared)
- [ ] Hidden columns (`facility`, `readiness`, `room_floor`) available via Settings
- [ ] Search matcher finds beds by label, location, facility, status label, assignment, readiness, and hidden column values
- [ ] Status column uses `AppWorkspaceStatusBadge` with formatted label
- [ ] Next-action column shows single-verb label and is pressable (`RoomsBedsNextActionButton`)
- [ ] Next-action opens correct dialog or navigates to housekeeping/operations — not generic module home
- [ ] Row tap still opens `_openBedDetailDialog` with full action set
- [ ] Mobile list shows bed, location, assignment, status, and next-action button
- [ ] `roomsBedsWorkspaceControllerProvider` realtime refresh still updates rows after mutations
- [ ] `canAdminBeds` / `canIpdWrite` still gate write actions in both detail dialog and next-action button
- [ ] All five section tabs (`all`, `available`, `occupied`, `turnover`, `outOfService`) render the same compliant table with correct filtered rows

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for the Bed board `AppListTable` on `/rooms-beds`
- [ ] Domain logic preserved (assign, release, transfer, status updates, permissions, pagination, deep links)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/rooms_beds/` passes
