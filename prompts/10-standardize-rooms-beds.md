# Standardize Rooms & Beds Workspace Screen

## Objective

Refactor the Rooms & Beds workspace screen (`/rooms-beds`) to match the standardized tab-and-table layout used by the Reception workspace. The screen currently renders a flat, single-view bed board wrapped in `AppWorkspace` with toolbar summary notification cards (Total, Available, Occupied, Reserved, Cleaning, Blocked) acting as clickable status-filter chips, a single `AppListTable<BedBoardItem>` with advanced search/filter, and admin/clinical action dialogs. After this refactor it will use routable `AppTabStrip` tabs (All Beds, Available, Occupied, Turnover, Out of Service) with URL-synced section state via `?section=` query parameter, per-tab column visibility persistence keys, and the canonical `AsyncStateScaffold` → `SizedBox(width: double.infinity)` → `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` → `Row(AppTabStrip, AppButton.primary)` → `AppListTable` widget tree — exactly mirroring the Reception workspace pattern. All existing business logic (server-side filtering via controller methods, advanced search with facility/ward/room/status dropdowns, summary status counts, bed detail dialog with assign/release/transfer/status-update actions, realtime sync, pagination, bed selection) must be preserved.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run formatting and analysis after implementation.

## Current State (from audit)

### Files

- **Main page file:** `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart` — ~1522 lines. Contains `RoomsBedsWorkspacePage`, `_RoomsBedsWorkspacePageState`, `_RoomsBedsWorkspaceContent`, `_RoomsBedsWorkspaceContentState`, `_BedBoardPanel`, `_BedDetailContent`, `_AssignmentListItem`, `_BedMobileItem`, `_TwoLineCell`, `_AdmissionActionForm`, `_TransferForm`, `_TransferUpdateForm`, plus ~15 private helper/dialog functions (`_openBedDetailDialog`, `_showAssignDialog`, `_showReleaseDialog`, `_showTransferDialog`, `_showTransferUpdateDialog`, `_updateBedStatus`, `_canAdminBeds`, `_locationLabel`, `_assignmentLabel`, `_dateLabel`, `_assignmentTitle`, `_facilityChoices`, `_wardChoices`, `_roomChoices`, `_filterValue`, `_joinDisplay`, `_readableDisplayText`, `_isNonHumanReadableId`, `_showFailureIfNeeded`, `_showSaved`), and 4 filter key constants.
- **Controller:** `frontend/lib/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart` — `RoomsBedsWorkspaceController` (`AsyncNotifier<Result<RoomsBedsWorkspaceState>>`), provider: `roomsBedsWorkspaceControllerProvider`. ~808 lines. Methods: `refresh`, `applyRouteQuery`, `applySearch`, `applyFacility`, `applyWard`, `applyRoom`, `applyStatus`, `changePage`, `clearFilters`, `selectBed`, `clearSelection`, `updateBedStatus`, `assignBed`, `releaseBed`, `requestTransfer`, `updateTransfer`, `availableDestinationBeds`.
- **Entities:** `frontend/lib/features/rooms_beds/domain/entities/rooms_beds_entities.dart` — `RoomsBedsQuery`, `BedAssignmentRecord`, `BedAdmissionContext`, `BedBoardItem`, `RoomsBedsReferenceData`, `RoomsBedsWorkspaceState`. ~302 lines.
- **Status helpers:** `frontend/lib/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart` — `roomsBedsStatusLabel`, `roomsBedsStatusTone`, `roomsBedsStatusIcon`, `roomsBedsStatusBadge`, `roomsBedsNextActionLabel`, `roomsBedsReadinessLabel`, `roomsBedsStatusFilterChoices`, `roomsBedsStatusFromFilter`, `roomsBedsTransferActionForStatus`, `roomsBedsTransferRequiresDestinationBed`. ~118 lines.
- **Repository interface:** `frontend/lib/features/rooms_beds/domain/repositories/rooms_beds_repository.dart` — `RoomsBedsRepository` (abstract interface).
- **Repository impl:** `frontend/lib/features/rooms_beds/data/repositories/rooms_beds_repository_impl.dart` — `RoomsBedsRepositoryImpl`, provider: `roomsBedsRepositoryProvider`.
- **DTOs:** `frontend/lib/features/rooms_beds/data/dtos/rooms_beds_dtos.dart` — `BedAssignmentRecordDto`, `BedAdmissionContextDto`, decoders.
- **Route definition:** `frontend/lib/app/router/app_routes.dart` line ~344: `AppRoutes.roomsBeds`, path `/rooms-beds`, module `inpatient-bed-management`.
- **GoRoute registration:** `frontend/lib/app/router/app_router.dart` line ~200: builder passes `RoomsBedsQuery.fromUri(state.uri)`.
- **Tests:**
  - `frontend/test/features/rooms_beds/presentation/rooms_beds_workspace_controller_test.dart`
  - `frontend/test/features/rooms_beds/data/rooms_beds_dtos_test.dart`

### Current layout / structure

```
RoomsBedsWorkspacePage (ConsumerStatefulWidget)
 └─ AsyncStateScaffold<RoomsBedsWorkspaceState>(maxWidth: PageMaxWidth.dataHeavy)
     └─ _RoomsBedsWorkspaceContent (ConsumerStatefulWidget)
         └─ AppWorkspace(title: l10n.roomsBedsTitle, leadingIcon: AppRouteIcons.roomsBeds)
             ├─ toolbar: appWorkspaceToolbarWithLabels(
             │   summaryNotifications: [Total, Available, Occupied, Reserved, Cleaning, Blocked],
             │   primary: AppButton.primary("Add Room"),
             │   secondary: [AppButton.secondary("Add Bed"), AppButton.secondary("Manage Catalog"), AppButton.tertiary("Setup")],
             │   onRefresh: controller.refresh,
             │   isRefreshing: state.isRefreshing,
             │ )
             └─ body: Column
                 ├─ AppFailureStateView (conditional)
                 └─ _BedBoardPanel
                     └─ SizedBox(height: 560)
                         └─ AppListTable<BedBoardItem>(
                             page: state.beds,
                             columns: [Bed, Location, Status, Assignment, Next Action],
                             search: AppListTableSearch with advanced filters (facility, ward, room, status),
                             mobileItemBuilder: _BedMobileItem,
                             onRowSelected: _openBedDetailDialog,
                             onPageChanged: controller.changePage,
                             emptyBuilder: AppWorkspaceStatePanel.empty,
                             ...)
```

### Data model

The rooms-beds workspace loads a `FacilitySetupSnapshot` containing all facilities, wards, rooms, and beds for the tenant. The controller filters beds client-side from this snapshot based on the `RoomsBedsQuery` (facility, ward, room, status, search), paginates them, and attaches assignment records for occupied beds. The `BedBoardItem` wraps a `BedProfile` with associated facility/ward/room lookups and assignment history.

The `BedSetupStatus` enum values are: `available`, `occupied`, `reserved`, `cleaning`, `maintenance`, `blocked`, `outOfService`.

### Problems / inconsistencies vs. Reception reference

1. **No tab navigation** — flat single-view bed board; no `AppTabStrip`. The status-based summary notification cards (Available, Occupied, Reserved, Cleaning, Blocked) act as clickable filter chips, but these should be tabs with URL-synced section state.
2. **No URL-synced section state** — `RoomsBedsQuery.fromUri` parses `search`, `facilityId`, `wardId`, `roomId`, `bedId`, `status` but has no `section` parameter for tab routing.
3. **No per-tab column visibility keys** — uses no `columnVisibilityStorageKey` or `columnWidthStorageKey` at all. Should use per-section keys like Reception's `reception_${_section.name}`.
4. **Uses `AppWorkspace` wrapper** instead of direct widget tree — the Reception workspace uses `AsyncStateScaffold` → content widget → `Row(AppTabStrip, AppButton.primary)` → `AppListTable`. The rooms-beds page wraps in `AppWorkspace` which adds its own header/toolbar chrome.
5. **Fixed height constraint** — the `_BedBoardPanel` constrains the table to `SizedBox(height: 560)`, which is non-responsive. Should let the table expand naturally with `shrinkWrap: true` and `NeverScrollableScrollPhysics()`.
6. **Summary notification cards unsurfaced as tab counts** — `RoomsBedsWorkspaceState` has `totalBedCount`, `availableCount`, `occupiedCount`, `reservedCount`, `cleaningCount`, `maintenanceCount`, `blockedCount` — these should appear as tab badge counts.
7. **Secondary admin actions lost without AppWorkspace** — "Add Bed", "Manage Catalog", "Setup" buttons need to move to the search bar's trailing actions.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Pattern to Extract |
|------|----------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Full tabbed-workspace widget tree: `AsyncStateScaffold` → content widget → `SizedBox(width: double.infinity)` → `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` → `Row(Expanded(AppTabStrip), SizedBox(width: theme.spacing.sm), AppAccessActionGate(AppButton.primary))` → `SizedBox(height: theme.spacing.md)` → `AppListTable`. Tab enum iteration, `_sectionIcon()`, `_sectionLabel()`, `_sectionCount()`, `_updateUrlForSection()`, search matcher, mobile item builder. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` enum + `ReceptionWorkspaceQuery` with `section` field and `fromUri` factory using multi-alias parsing. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` constructor: `tabs` (`List<AppTabItem>`), `selectedId`, `onTabTapped`. `AppTabItem`: `id`, `icon`, `label`. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor params: `page`/`items`, `columns`, `search`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `columnVisibilityLabel`, `isLoading`, `shrinkWrap`, `physics`, `onRowSelected`, `itemKeyBuilder`, `mobileItemBuilder`, `emptyBuilder`, `pageLabelBuilder`, `onPageChanged`. |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints`, `AppBreakpoint` enum: xs (<360), sm (360-599), md (600-839), lg (840-1199), xl (1200-1599), xxl (1600+). `isMobile` = xs/sm. |

## Target Architecture

### Tab Configuration

| Tab Name | Section Enum Value | Route Query `?section=` | Description | Icon | Count Source | Primary Action Button |
|----------|-------------------|------------------------|-------------|------|-------------|----------------------|
| All Beds | `all` | (default — omitted from URL) | All beds in the bed board | `Icons.bed_outlined` | `state.totalBedCount` | Add Room → `showTenantFacilityRoomFormDialog` |
| Available | `available` | `available` | Beds ready for patient assignment | `Icons.check_circle_outline` | `state.availableCount` | Add Room → `showTenantFacilityRoomFormDialog` |
| Occupied | `occupied` | `occupied` | Currently occupied beds with active admissions | `Icons.person_pin_circle_outlined` | `state.occupiedCount` | Add Room → `showTenantFacilityRoomFormDialog` |
| Turnover | `turnover` | `turnover` | Reserved + Cleaning + Maintenance beds (in transition) | `Icons.swap_horiz_outlined` | `reservedCount + cleaningCount + maintenanceCount` | Add Room → `showTenantFacilityRoomFormDialog` |
| Out of Service | `outOfService` | `out-of-service` | Blocked + Out of Service beds | `Icons.block_outlined` | `state.blockedCount` | Add Room → `showTenantFacilityRoomFormDialog` |

### Routing

**No changes to `app_routes.dart` or `app_router.dart` route definitions are needed.** The `/rooms-beds` GoRoute already passes `RoomsBedsQuery.fromUri(state.uri)` to the page. The only changes are:

1. **Add a `section` field to `RoomsBedsQuery`** — parse `?section=` from the URI in `fromUri`, adding `'section'` and `'tab'` as aliases.
2. **Add a `RoomsBedsSectionn` enum** to `rooms_beds_entities.dart` — values: `all`, `available`, `occupied`, `turnover`, `outOfService`.
3. **URL update on tab change** — use `GoRouter.of(context).replace<void>(location)` with `AppRoutes.roomsBeds.location(queryParameters: {'section': sectionQueryValue})`, exactly like Reception's `_updateUrlForSection`.

### Page Layout

Target widget tree (mirrors Reception exactly):

```
RoomsBedsWorkspacePage (ConsumerStatefulWidget)
 └─ AsyncStateScaffold<RoomsBedsWorkspaceState>(maxWidth: PageMaxWidth.dataHeavy)
     └─ _RoomsBedsWorkspaceContent (ConsumerStatefulWidget)
         └─ SizedBox(width: double.infinity)
             └─ Column(crossAxisAlignment: CrossAxisAlignment.stretch)
                 ├─ Row
                 │   ├─ Expanded → AppTabStrip(tabs: [...], selectedId: _section.name, onTabTapped: ...)
                 │   ├─ SizedBox(width: theme.spacing.sm)
                 │   └─ AppButton.primary("Add Room") — permission-gated by canAdminBeds
                 ├─ SizedBox(height: theme.spacing.md)
                 ├─ AppFailureStateView (conditional — same as current)
                 └─ AppListTable<BedBoardItem>(
                        page: _filteredPage(state, _section),
                        columns: _columnsForSection(_section),
                        columnVisibilityStorageKey: 'rooms_beds_${_section.name}',
                        columnWidthStorageKey: 'rooms_beds_cw_${_section.name}',
                        search: AppListTableSearch with advanced filters + trailing admin actions,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        mobileItemBuilder: _BedMobileItem,
                        ...)
```

**Key differences from current layout:**
- Replace `AppWorkspace` wrapper with direct `SizedBox(width: double.infinity)` → `Column` → `Row`.
- Add `AppTabStrip` inside the `Row`, before the primary action button (with `SizedBox(width: theme.spacing.sm)` between them, matching Reception).
- Spacing between tab row and table via `SizedBox(height: theme.spacing.md)` — matching Reception line 284.
- The summary notification cards from `appWorkspaceToolbarWithLabels` are removed — their count values become tab badge counts instead.
- The secondary admin actions ("Add Bed", "Manage Catalog", "Setup") move to the search bar's `trailingActions` via `AppSearchBarAction`.
- Remove the `SizedBox(height: 560)` fixed constraint — use `shrinkWrap: true` and `NeverScrollableScrollPhysics()` instead, matching Reception.
- The `onRefresh` callback and refresh button are removed from the toolbar — rely on realtime sync (already wired in the controller).
- Per-tab column visibility persistence keys: `rooms_beds_${section.name}`.
- Per-tab column width persistence keys: `rooms_beds_cw_${section.name}`.

### Tab-to-Status Mapping

The tab filtering operates on the `BedSetupStatus` of each bed:

| Section Enum | Status Filter |
|-------------|---------------|
| `all` | No filter — show all beds |
| `available` | `BedSetupStatus.available` |
| `occupied` | `BedSetupStatus.occupied` |
| `turnover` | `BedSetupStatus.reserved` OR `BedSetupStatus.cleaning` OR `BedSetupStatus.maintenance` |
| `outOfService` | `BedSetupStatus.blocked` OR `BedSetupStatus.outOfService` |

### Data & State Management

**No changes to the controller or repository are required.** The existing `RoomsBedsWorkspaceController` and its methods (`refresh`, `applySearch`, `applyFacility`, `applyWard`, `applyRoom`, `applyStatus`, `changePage`, `clearFilters`, `selectBed`, `updateBedStatus`, `assignBed`, `releaseBed`, `requestTransfer`, `updateTransfer`) already handle all data operations.

The tab-switching logic should:
1. Call `controller.applyStatus(statusForSection)` when switching to a single-status tab (Available, Occupied) — this applies the status filter server-side via the controller.
2. For multi-status tabs (Turnover, Out of Service), apply client-side filtering on the page items since the controller only supports single-status filtering. Alternatively, clear the status filter and filter in the view layer.
3. For the "All Beds" tab, call `controller.clearFilters()` to remove any status filter (preserving facility/ward/room filters).
4. Reset pagination to first page on tab change.
5. Preserve the existing advanced filter dropdowns (facility, ward, room, status) — they continue to work within the active tab's data.

**Important:** The current controller uses server-side-like status filtering via `applyStatus`. The simplest approach for multi-status tabs (Turnover, Out of Service) is to NOT use `applyStatus` on tab switch, but instead:
- Clear the status filter in the query (set `status: null`) on tab change.
- Filter the returned `state.beds.items` client-side in the view by matching the tab's status set.
- This avoids modifying the controller while supporting multi-status tabs.

## Implementation Steps

### 1. Add `RoomsBedsSection` enum — File: `frontend/lib/features/rooms_beds/domain/entities/rooms_beds_entities.dart`

Add the following enum **before** the `RoomsBedsQuery` class (before line 6):

```dart
enum RoomsBedsSection {
  all,
  available,
  occupied,
  turnover,
  outOfService,
}
```

### 2. Add `section` field to `RoomsBedsQuery` — File: `frontend/lib/features/rooms_beds/domain/entities/rooms_beds_entities.dart`

- Add `this.section = RoomsBedsSection.all` to the `RoomsBedsQuery` constructor parameter list.
- Add `final RoomsBedsSection section;` field.
- In `RoomsBedsQuery.fromUri`, add a section parser. Update the factory to include:

```dart
section: _parseRoomsBedsSection(params['section'] ?? params['tab'] ?? ''),
```

Add a top-level helper function (before `RoomsBedsQuery`):

```dart
RoomsBedsSection _parseRoomsBedsSection(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'available' => RoomsBedsSection.available,
    'occupied' => RoomsBedsSection.occupied,
    'turnover' || 'reserved' || 'cleaning' || 'maintenance' =>
      RoomsBedsSection.turnover,
    'out-of-service' || 'out_of_service' || 'blocked' || 'oos' =>
      RoomsBedsSection.outOfService,
    _ => RoomsBedsSection.all,
  };
}
```

- Update `hasRouteTargeting` to include non-default section:
```dart
bool get hasRouteTargeting {
  return section != RoomsBedsSection.all ||
      search.trim().isNotEmpty ||
      facilityId != null ||
      wardId != null ||
      roomId != null ||
      bedId != null ||
      status != null;
}
```

- Add `section` to `copyWith`:
```dart
RoomsBedsQuery copyWith({
  RoomsBedsSection? section,
  String? search,
  // ... existing params ...
}) {
  return RoomsBedsQuery(
    section: section ?? this.section,
    search: search ?? this.search,
    // ... existing params ...
  );
}
```

- Update `hasFilters` — section is NOT a filter (it's a tab), so `hasFilters` stays as-is.

### 3. Add section helper functions — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

Add these top-level helper functions (place them near the existing `_canAdminBeds` function):

```dart
IconData _roomsBedsSectionIcon(RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => Icons.bed_outlined,
    RoomsBedsSection.available => Icons.check_circle_outline,
    RoomsBedsSection.occupied => Icons.person_pin_circle_outlined,
    RoomsBedsSection.turnover => Icons.swap_horiz_outlined,
    RoomsBedsSection.outOfService => Icons.block_outlined,
  };
}

String _roomsBedsSectionLabel(
  AppLocalizations l10n,
  RoomsBedsSection section,
) {
  return switch (section) {
    RoomsBedsSection.all => l10n.roomsBedsSectionAllLabel,
    RoomsBedsSection.available => l10n.roomsBedsSectionAvailableLabel,
    RoomsBedsSection.occupied => l10n.roomsBedsSectionOccupiedLabel,
    RoomsBedsSection.turnover => l10n.roomsBedsSectionTurnoverLabel,
    RoomsBedsSection.outOfService => l10n.roomsBedsSectionOutOfServiceLabel,
  };
}

int _roomsBedsSectionCount(
  RoomsBedsWorkspaceState state,
  RoomsBedsSection section,
) {
  return switch (section) {
    RoomsBedsSection.all => state.totalBedCount,
    RoomsBedsSection.available => state.availableCount,
    RoomsBedsSection.occupied => state.occupiedCount,
    RoomsBedsSection.turnover =>
      state.reservedCount + state.cleaningCount + state.maintenanceCount,
    RoomsBedsSection.outOfService => state.blockedCount,
  };
}

String _roomsBedsSectionQueryValue(RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => '',
    RoomsBedsSection.available => 'available',
    RoomsBedsSection.occupied => 'occupied',
    RoomsBedsSection.turnover => 'turnover',
    RoomsBedsSection.outOfService => 'out-of-service',
  };
}

bool _roomsBedsSectionMatchesStatus(
  RoomsBedsSection section,
  BedSetupStatus status,
) {
  return switch (section) {
    RoomsBedsSection.all => true,
    RoomsBedsSection.available => status == BedSetupStatus.available,
    RoomsBedsSection.occupied => status == BedSetupStatus.occupied,
    RoomsBedsSection.turnover =>
      status == BedSetupStatus.reserved ||
      status == BedSetupStatus.cleaning ||
      status == BedSetupStatus.maintenance,
    RoomsBedsSection.outOfService =>
      status == BedSetupStatus.blocked ||
      status == BedSetupStatus.outOfService,
  };
}
```

### 4. Update imports in `rooms_beds_workspace_page.dart` — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

The file already imports `go_router`, `app_routes`, and `app_route_icons`. Verify these imports are present (they are in the current file). No new imports are needed since `AppTabStrip` and `AppTabItem` are exported via `package:hosspi_hms/shared/components/components.dart` which is already imported.

### 5. Add section state and URL helpers to `_RoomsBedsWorkspaceContentState` — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

#### 5a. Add state field

Add to `_RoomsBedsWorkspaceContentState`:
```dart
late RoomsBedsSection _section;
```

#### 5b. Initialize in `initState`

After the existing `_tableColumnController` initialization (after line 128), add:
```dart
_section = widget.state.query.section;
```

#### 5c. Add URL update method (follows Reception pattern exactly)

```dart
void _updateUrlForSection(RoomsBedsSection section) {
  if (!mounted) {
    return;
  }
  final String tab = _roomsBedsSectionQueryValue(section);
  final String location = AppRoutes.roomsBeds.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

#### 5d. Add tab change handler

```dart
void _handleTabChanged(RoomsBedsSection section) {
  if (section == _section) {
    return;
  }
  setState(() => _section = section);
  _updateUrlForSection(section);
}
```

### 6. Replace the `build` method of `_RoomsBedsWorkspaceContentState` — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

Replace the current `build` method (lines 148-287) with:

```dart
@override
Widget build(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final RoomsBedsWorkspaceState state = widget.state;
  final RoomsBedsWorkspaceController controller = ref.read(
    roomsBedsWorkspaceControllerProvider.notifier,
  );
  final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
  final bool canAdminBeds = _canAdminBeds(accessPolicy);
  final bool canIpdWrite = accessPolicy.grants(AppPermissions.clinicalWrite);
  final AppFailure? lastFailure = state.lastFailure as AppFailure?;

  final AppPage<BedBoardItem> sectionPage = _sectionFilteredPage(
    state.beds,
    _section,
  );

  return SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppTabStrip(
                tabs: <AppTabItem>[
                  for (final RoomsBedsSection section
                      in RoomsBedsSection.values)
                    AppTabItem(
                      id: section.name,
                      icon: _roomsBedsSectionIcon(section),
                      label:
                          '${_roomsBedsSectionLabel(l10n, section)} (${_roomsBedsSectionCount(state, section)})',
                    ),
                ],
                selectedId: _section.name,
                onTabTapped: (String tabId) {
                  for (final RoomsBedsSection section
                      in RoomsBedsSection.values) {
                    if (section.name == tabId) {
                      _handleTabChanged(section);
                      break;
                    }
                  }
                },
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            if (canAdminBeds)
              AppButton.primary(
                label: l10n.tenantFacilityAddRoomAction,
                leadingIcon: Icons.meeting_room_outlined,
                semanticLabel: l10n.tenantFacilityAddRoomAction,
                tooltip: l10n.tenantFacilityAddRoomAction,
                enabled: !state.isSaving,
                onPressed: () async {
                  await showTenantFacilityRoomFormDialog(
                    context,
                    state.referenceData.snapshot,
                  );
                  if (context.mounted) {
                    await controller.refresh();
                  }
                },
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (lastFailure != null) ...<Widget>[
          AppFailureStateView(
            failure: lastFailure,
            onRetry: controller.refresh,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        AppListTable<BedBoardItem>(
          page: sectionPage,
          isLoading: state.isRefreshing,
          columnVisibilityController: _tableColumnController,
          columnVisibilityStorageKey: 'rooms_beds_${_section.name}',
          columnWidthStorageKey: 'rooms_beds_cw_${_section.name}',
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          search: AppListTableSearch<BedBoardItem>(
            controller: _searchController,
            semanticLabel: l10n.roomsBedsSearchLabel,
            hintText: l10n.roomsBedsSearchHint,
            matcher: (_, _) => true,
            onSubmitted: (String value) async {
              final AppFailure? failure = await controller.applySearch(value);
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
            onClear: () async {
              final AppFailure? failure = await controller.applySearch('');
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.roomsBedsFiltersLabel,
            advancedFilterTitle: l10n.roomsBedsFiltersLabel,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            enableDateFilter: false,
            allFieldsLabel: l10n.roomsBedsAllFilterLabel,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _facilityFilterKey,
                label: l10n.roomsBedsFacilityFilterLabel,
                allLabel: l10n.roomsBedsAllFacilitiesLabel,
                choices: _facilityChoices(state.referenceData.facilities),
              ),
              AppSearchBarFilterGroup(
                key: _wardFilterKey,
                label: l10n.roomsBedsWardFilterLabel,
                allLabel: l10n.roomsBedsAllWardsLabel,
                choices: _wardChoices(state.referenceData.wards),
              ),
              AppSearchBarFilterGroup(
                key: _roomFilterKey,
                label: l10n.roomsBedsRoomFilterLabel,
                allLabel: l10n.roomsBedsAllRoomsLabel,
                choices: _roomChoices(state.referenceData.rooms),
              ),
              AppSearchBarFilterGroup(
                key: _statusFilterKey,
                label: l10n.roomsBedsStatusFilterLabel,
                allLabel: l10n.roomsBedsAllStatusesLabel,
                choices: roomsBedsStatusFilterChoices(l10n),
              ),
            ],
            filterValue: _filterValue(state.query),
            hasActiveFilters: state.query.hasFilters,
            onFilterChanged: (AppSearchBarFilterValue value) async {
              AppFailure? failure;
              final String? facilityId = value.option(_facilityFilterKey);
              final String? wardId = value.option(_wardFilterKey);
              final String? roomId = value.option(_roomFilterKey);
              final BedSetupStatus? status = roomsBedsStatusFromFilter(
                value.option(_statusFilterKey),
              );
              if (facilityId != state.query.facilityId) {
                failure = await controller.applyFacility(facilityId);
              }
              if (wardId != state.query.wardId) {
                failure ??= await controller.applyWard(wardId);
              }
              if (roomId != state.query.roomId) {
                failure ??= await controller.applyRoom(roomId);
              }
              if (status != state.query.status) {
                failure ??= await controller.applyStatus(status);
              }
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
            trailingActions: <AppSearchBarAction>[
              if (canAdminBeds)
                AppSearchBarAction(
                  icon: Icons.bed_outlined,
                  label: l10n.tenantFacilityAddBedAction,
                  tooltip: l10n.tenantFacilityAddBedAction,
                  onPressed: () async {
                    await showTenantFacilityBedFormDialog(
                      context,
                      state.referenceData.snapshot,
                    );
                    if (context.mounted) {
                      await controller.refresh();
                    }
                  },
                ),
              if (canAdminBeds)
                AppSearchBarAction(
                  icon: Icons.apartment_outlined,
                  label: l10n.roomsBedsManageCatalogAction,
                  tooltip: l10n.roomsBedsManageCatalogAction,
                  onPressed: () =>
                      context.go(AppRoutes.tenantFacilitySetup.location()),
                ),
              AppSearchBarAction(
                icon: Icons.settings_outlined,
                label: l10n.navigationSetupLabel,
                tooltip: l10n.navigationSetupLabel,
                onPressed: () =>
                    context.go(AppRoutes.tenantFacilitySetup.location()),
              ),
            ],
          ),
          itemKeyBuilder: (BedBoardItem item) => ValueKey<String>(item.id),
          onPageChanged: (AppPageRequest request) {
            unawaited(controller.changePage(request));
          },
          onRowSelected: (BedBoardItem item) {
            unawaited(
              _openBedDetailDialog(
                context,
                ref,
                state,
                item,
                canAdminBeds: canAdminBeds,
                canIpdWrite: canIpdWrite,
              ),
            );
          },
          previousPageLabel: l10n.roomsBedsPreviousPageLabel,
          nextPageLabel: l10n.roomsBedsNextPageLabel,
          pageLabelBuilder: (AppPage<BedBoardItem> page) {
            return l10n.roomsBedsPageLabel(
              page.firstItemNumber,
              page.lastItemNumber,
              page.totalItemCount ?? page.items.length,
            );
          },
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.roomsBedsEmptyTitle,
            body: l10n.roomsBedsEmptyBody,
            icon: Icons.bed_outlined,
          ),
          columns: <AppListTableColumn<BedBoardItem>>[
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsBedColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(left.label, right.label);
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return _TwoLineCell(
                  title: item.label,
                  subtitle: _joinDisplay(<String?>[item.facility?.name]),
                );
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsLocationColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  _locationLabel(context, left),
                  _locationLabel(context, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(_locationLabel(context, item));
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsStatusColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  left.status.apiValue,
                  right.status.apiValue,
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return AppWorkspaceStatusBadge(
                  status: roomsBedsStatusBadge(context.l10n, item.status),
                );
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsAssignmentColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  _assignmentLabel(context, left),
                  _assignmentLabel(context, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(_assignmentLabel(context, item));
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsNextActionColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  roomsBedsNextActionLabel(context.l10n, left),
                  roomsBedsNextActionLabel(context.l10n, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(roomsBedsNextActionLabel(context.l10n, item));
              },
            ),
          ],
          mobileItemBuilder: (BuildContext context, BedBoardItem item) {
            return _BedMobileItem(item: item);
          },
        ),
      ],
    ),
  );
}
```

### 7. Add client-side section filtering helper — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

Add this top-level function near the other section helpers:

```dart
AppPage<BedBoardItem> _sectionFilteredPage(
  AppPage<BedBoardItem> page,
  RoomsBedsSection section,
) {
  if (section == RoomsBedsSection.all) {
    return page;
  }
  final List<BedBoardItem> filtered = page.items
      .where(
        (BedBoardItem item) => _roomsBedsSectionMatchesStatus(section, item.status),
      )
      .toList(growable: false);
  return AppPage<BedBoardItem>(
    items: filtered,
    request: page.request,
    totalItemCount: filtered.length,
  );
}
```

### 8. Remove `_BedBoardPanel` widget — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

Delete the entire `_BedBoardPanel` class (lines 290-496). Its content (the `AppListTable`) has been inlined into the `_RoomsBedsWorkspaceContentState.build` method. All search/filter/column/pagination configuration has been moved there.

### 9. Update `_RoomsBedsWorkspacePageState._scheduleRouteQuery` for section deep-linking — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

The existing `_scheduleRouteQuery` / `_querySignature` methods should include the section in the signature to support section deep-linking. Update `_querySignature`:

```dart
String? _querySignature(RoomsBedsQuery? query) {
  if (query == null) {
    return null;
  }
  return '${query.section.name}|${query.wardId}|${query.roomId}|${query.bedId}|${query.status?.apiValue}|${query.search}';
}
```

### 10. Add localization strings — File: `frontend/lib/l10n/app_en.arb`

Find the rooms-beds section of `app_en.arb` (near where `"roomsBedsTitle"` is defined) and add these entries:

```json
"roomsBedsSectionAllLabel": "All beds",
"@roomsBedsSectionAllLabel": {
  "description": "Tab label for showing all beds in the bed board"
},
"roomsBedsSectionAvailableLabel": "Available",
"@roomsBedsSectionAvailableLabel": {
  "description": "Tab label for showing available beds"
},
"roomsBedsSectionOccupiedLabel": "Occupied",
"@roomsBedsSectionOccupiedLabel": {
  "description": "Tab label for showing occupied beds"
},
"roomsBedsSectionTurnoverLabel": "Turnover",
"@roomsBedsSectionTurnoverLabel": {
  "description": "Tab label for showing beds in transition (reserved, cleaning, maintenance)"
},
"roomsBedsSectionOutOfServiceLabel": "Out of service",
"@roomsBedsSectionOutOfServiceLabel": {
  "description": "Tab label for showing blocked and out-of-service beds"
}
```

After adding the ARB entries, regenerate localizations:

```bash
cd frontend && flutter gen-l10n
```

If the project uses a different localization generation command, check the project's `l10n.yaml` or `pubspec.yaml` for the correct command and run that instead.

### 11. Remove `AppRouteIcons.roomsBeds` import if unused — File: `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`

After removing the `AppWorkspace` wrapper, the `AppRouteIcons.roomsBeds` reference is no longer used in this file. Remove the import:

```dart
import 'package:hosspi_hms/app/router/app_route_icons.dart';
```

Only remove it if `AppRouteIcons` is not referenced elsewhere in this file. Search the file for `AppRouteIcons` before removing.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab bar above the table. Constructor: `AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)` |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab definition: `AppTabItem(id: ..., icon: ..., label: ...)` |
| `AppListTable<BedBoardItem>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Data table — already in use, add `shrinkWrap`, `physics`, per-section storage keys |
| `AppListTableSearch<BedBoardItem>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Search bar config — already in use, add `trailingActions` for admin buttons |
| `AppSearchBarAction` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Trailing action buttons in search bar for "Add Bed", "Manage Catalog", "Setup" |
| `AppListTableColumnVisibilityController<BedBoardItem>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Column visibility — already in use |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Primary action button — already in use |
| `AsyncStateScaffold<RoomsBedsWorkspaceState>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Async state wrapper — already in use, keep as-is |
| `AppWorkspaceStatePanel.empty` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Empty state — already in use in table `emptyBuilder` |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Status badge — already in use in columns and mobile items |
| `AppFailureStateView` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Error display — already in use |
| `GoRouter` | `package:go_router/go_router.dart` | URL replacement for tab sync — already imported |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | Route constants for URL generation — already imported |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/rooms_beds/domain/entities/rooms_beds_entities.dart` | Add `RoomsBedsSection` enum, `_parseRoomsBedsSection` helper, `section` field to `RoomsBedsQuery`, update `fromUri`, `hasRouteTargeting`, `copyWith` |
| `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart` | Replace `AppWorkspace` with `SizedBox` → `Column` → `Row(AppTabStrip, AppButton.primary)` → `AppListTable`. Add `_section` state, `_handleTabChanged`, `_updateUrlForSection`, section helper functions, `_sectionFilteredPage`. Remove `_BedBoardPanel` class. Move secondary admin actions to search bar `trailingActions`. Remove `SizedBox(height: 560)` constraint, add `shrinkWrap: true`, `NeverScrollableScrollPhysics()`. Add per-section column visibility/width storage keys. Remove `AppWorkspace` wrapper, `appWorkspaceToolbarWithLabels`, summary notifications. Remove `AppRouteIcons` import if unused. |
| `frontend/lib/l10n/app_en.arb` | Add `roomsBedsSectionAllLabel`, `roomsBedsSectionAvailableLabel`, `roomsBedsSectionOccupiedLabel`, `roomsBedsSectionTurnoverLabel`, `roomsBedsSectionOutOfServiceLabel` localization strings with `@` metadata |

## Files to Delete (if any)

No files need to be deleted. The refactor restructures the UI within existing files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace` wrapper usage from `_RoomsBedsWorkspaceContentState.build` — replaced by `SizedBox(width: double.infinity)` → `Column` → `Row`.
- [ ] Remove `appWorkspaceToolbarWithLabels` call — it was used to wrap the primary action button + summary notification cards + secondary actions in `AppWorkspace.toolbar`.
- [ ] Remove the 6 `AppWorkspaceSummaryNotification` instances — the summary notification cards are superseded by tab badge counts. (Keep the `RoomsBedsWorkspaceState` count properties — they power the tab counts.)
- [ ] Remove `_BedBoardPanel` widget class — its `AppListTable` is now inlined in the content state's `build` method.
- [ ] Remove `AppRouteIcons.roomsBeds` reference and its import — it was used as `AppWorkspace.leadingIcon`. Check the file for other references before removing the import.
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactor only restructures the Flutter UI layer. The `RoomsBedsWorkspaceController` already fetches all needed data via the existing API endpoints. No new columns, tables, or indexes are needed.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full data table with all 5 columns visible, `AppTabStrip` and primary action button ("Add Room") in a horizontal `Row`, column resize handles enabled, column visibility settings button in search bar, admin trailing actions visible in search bar.
- **Tablet (600–839px / `md`):** Same table layout — `AppListTable` renders as table at this breakpoint. Tab labels may truncate. Action button may collapse to icon-only via `AppActionLabelScope` (inherited from the shell scaffold). Admin trailing actions overflow into a menu.
- **Mobile (<600px / `xs`/`sm`):** `AppListTable` automatically switches to `mobileItemBuilder` rendering each row via `_BedMobileItem` → `ListTile`. `AppTabStrip` wraps to multiple lines via its `Wrap` layout. Primary action button remains accessible. Search bar trailing actions collapse to overflow menu.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` for any breakpoint-dependent logic. The existing `AppListTable` already handles the table/list switch — no manual breakpoint logic needed for the table itself.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Regenerate localizations
cd frontend && flutter gen-l10n

# Format
dart format frontend/lib/features/rooms_beds/ frontend/lib/l10n/

# Analyze
dart analyze frontend/ --fatal-infos

# Run tests related to this screen
flutter test test/features/rooms_beds/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs filters the bed board to the correct status set (available, occupied, turnover statuses, out-of-service statuses, or all)
- [ ] Tab navigation: switching tabs updates the URL query parameter `?section=` via `GoRouter.replace`
- [ ] Deep linking: constructing a `RoomsBedsQuery.fromUri` with `?section=available` produces `RoomsBedsSection.available`
- [ ] Deep linking: constructing a `RoomsBedsQuery.fromUri` with `?section=out-of-service` produces `RoomsBedsSection.outOfService`
- [ ] Deep linking: constructing a `RoomsBedsQuery.fromUri` with `?section=turnover` produces `RoomsBedsSection.turnover`
- [ ] Tab counts: badge counts on tabs match `totalBedCount`, `availableCount`, `occupiedCount`, `reservedCount + cleaningCount + maintenanceCount`, `blockedCount` from `RoomsBedsWorkspaceState`
- [ ] Search: typing in the search bar triggers `controller.applySearch` within the active tab's data
- [ ] Filter dialog: filter button opens the filter UI with facility/ward/room/status dropdowns
- [ ] Primary action: "Add Room" button is present on all tabs (when user has admin permissions) and opens `showTenantFacilityRoomFormDialog`
- [ ] Admin actions: "Add Bed", "Manage Catalog", "Setup" appear as trailing actions in the search bar
- [ ] Row click: clicking a bed row opens `_openBedDetailDialog` with full bed detail + action buttons
- [ ] Mobile layout: widget tests verify `mobileItemBuilder` renders `_BedMobileItem` at mobile breakpoint
- [ ] Existing deep-link: `?status=OCCUPIED&ward=<wardId>` still applies the correct filters
- [ ] No regressions: all existing rooms-beds workspace tests pass

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable `AppTabStrip` tabs matching the Reception workspace pattern, with 5 tabs: All Beds, Available, Occupied, Turnover, Out of Service
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] Tab badge counts display the correct count for each status group
- [ ] The primary action button ("Add Room") is positioned correctly beside the tab strip in a `Row`, visible only when user has admin permissions
- [ ] The page body uses `AppListTable<BedBoardItem>` with integrated search, advanced filters (facility/ward/room/status), column visibility settings (per-section persistence keys `rooms_beds_${section.name}`), and `shrinkWrap: true` (no fixed height constraint)
- [ ] Secondary admin actions ("Add Bed", "Manage Catalog", "Setup") are accessible via search bar trailing actions
- [ ] The layout uses `SizedBox(width: double.infinity)` → `Column` → `Row` directly instead of `AppWorkspace`
- [ ] Spacing between elements matches Reception: `theme.spacing.sm` between tab strip and button, `theme.spacing.md` between tab row and table
- [ ] Tab switching filters the bed board by status group client-side without additional API calls
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old/duplicate layout code is removed — no stale `AppWorkspace` wrapper, no `appWorkspaceToolbarWithLabels` call, no `_BedBoardPanel` class, no summary notification cards remain
- [ ] Domain-specific business logic is preserved: server-side search/filter via controller, status-based bed actions, assign/release/transfer workflows, bed detail dialog, realtime sync, pagination
- [ ] No database migrations required — schema unchanged (explicitly confirmed)
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] New localization strings are added for tab labels and localizations are regenerated
