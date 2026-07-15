# Standardize Housekeeping Screen

## Objective

Refactor the Housekeeping workspace to match the standardized tab-and-table layout used by the Reception workspace. The current housekeeping screen uses `AppWorkspace` with `appWorkspaceToolbarWithLabels` and summary-notification chips, with a single flat `AppListTable` that combines tasks, schedules, and maintenance requests — differentiated only by filter dropdowns. The refactored screen must adopt the Reception pattern: an `AppTabStrip` with clearly labelled sections (Tasks, Schedules, Maintenance Requests), per-tab `AppListTable` with section-specific columns, per-tab column visibility storage, tab-aware URL sync via `GoRouter`, and a contextual primary action button per tab — while preserving all existing domain logic (task lifecycle, schedule management, maintenance request triage, assignment, and status transitions).

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

The workspace root is `d:\coding\apps\flutter\hms`. The frontend code is in `frontend/`. Use `flutter test` and `dart format` from the `frontend/` directory.

## Current State (from audit)

### Housekeeping module files

| File | Purpose |
|------|---------|
| `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` | Main page: ~1850 lines. Contains the full workspace, worklist panel, detail panel, all forms (Task, Schedule, MaintenanceRequest, Assign, Triage, Confirmation), status badges, filter logic, helper functions — all in one monolith file. Uses `AppWorkspace` + `appWorkspaceToolbarWithLabels`. |
| `frontend/lib/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart` | `HousekeepingWorkspaceController` — Riverpod `AsyncNotifier` managing workspace state, pagination, search, resource/queue filters, detail selection, mutations (create/update/assign/start/complete/cancel tasks, create schedules, create/triage/complete/cancel maintenance requests), realtime sync, and pending refresh coalescing. |
| `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart` | Domain classes: `HousekeepingResource`, `HousekeepingQueue`, `HousekeepingDatePreset`, `HousekeepingWorkspaceQuery`, `HousekeepingWorkItem`, `HousekeepingWorkspaceState`, `HousekeepingWorkspaceOverview`, `HousekeepingLookups`, `HousekeepingLookupOption`, plus draft classes and status constants. |
| `frontend/lib/features/housekeeping/domain/repositories/housekeeping_repository.dart` | `HousekeepingRepository` interface — 7 methods: `getWorkspace`, `createTask`, `updateTask`, `createSchedule`, `createMaintenanceRequest`, `updateMaintenanceRequest`, `triageMaintenanceRequest`. Plus `HousekeepingWorkspaceLoad` value class. |
| `frontend/lib/features/housekeeping/data/repositories/housekeeping_repository_impl.dart` | `HousekeepingRepositoryImpl` — REST implementation using `ApiClient` against `HmsApiResource.housekeeping`, `housekeepingTasks`, `housekeepingSchedules`. |
| `frontend/lib/features/housekeeping/data/dtos/housekeeping_dtos.dart` | DTOs: `HousekeepingWorkspaceDto`, work-item/overview/lookups decoders. |
| `frontend/lib/shared/actions/app_global_housekeeping_request_action.dart` | Global toolbar action for requesting housekeeping from any workspace. |
| `frontend/lib/shared/actions/app_global_housekeeping_request_dialog.dart` | Dialog launched by the global housekeeping request action. |
| `frontend/patrol_test/housekeeping_flow_test.dart` | Patrol integration test for housekeeping flow. |

### Current layout problems

- **No tabs.** The housekeeping board uses `AppSearchBarFilterGroup` dropdowns (resource, queue, status, facility, room, assignee, date preset) inside the `AppListTableSearch.advancedFilter` to switch between tasks/schedules/maintenance requests. All resource types share a single flat table with the same columns.
- **Monolith page file.** All dialogs (`_TaskForm`, `_ScheduleForm`, `_MaintenanceRequestForm`, `_AssignForm`, `_TriageForm`, `_ConfirmationForm`), detail panel (`_HousekeepingDetailPanel`), helper widgets (`_CopyableTaskCell`, `_HousekeepingStatusBadge`, `_ReadinessPreview`, `_HousekeepingDateField`), and private helper functions (1840+ lines) live in one file.
- **No section-specific columns.** The same 6 columns (Task, Location, Assignee, Due, Status, Next Action) are used for all resource types, despite schedules and maintenance requests having different relevant data.
- **No tab-aware URL sync.** Reception updates the browser URL when the user switches tabs (`?section=...`); Housekeeping does not sync any filter state to the URL.
- **Missing `AppTabStrip`.** Reception uses the shared `AppTabStrip` component for tab navigation; Housekeeping relies on filter group dropdowns inside the advanced filter panel.
- **Column-visibility storage keys are absent.** Reception passes `columnVisibilityStorageKey` and `columnWidthStorageKey` per tab; Housekeeping does not, meaning table settings are not persisted.
- **Primary action button is static.** The toolbar always shows "Create Task" as primary. It does not change contextually per resource type.

### Route configuration

- **Path:** `/housekeeping`
- **Route data:** `AppRoutes.housekeeping` defined in `frontend/lib/app/router/app_routes.dart` (line ~456).
- **GoRouter entry:** `frontend/lib/app/router/app_router.dart` — a simple `GoRoute` with builder `(_, _) => const HousekeepingWorkspacePage()`. No query parameters extracted.
- **Permissions:** Requires `operationsRead` or `operationsWrite` + roles `housekeepingWorkspaceRoles` + module `facilities-maintenance`.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | What to learn |
|------|---------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Tab-based workspace with `AppTabStrip`, per-section table columns, `AppListTable` with `columnVisibilityStorageKey`/`columnWidthStorageKey`, search with `AppListTableSearch`, tab-aware URL sync via `GoRouter.of(context).replace`, mobile item builder, section counts in tab labels. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery` with `.fromUri()`, `.hasRouteTargeting`, `.signature`, `ReceptionDeskSection` enum. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` and `AppTabItem` widget API. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` API — `items`, `page`, `columns`, `search`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `onRowSelected`, `emptyBuilder`, `mobileItemBuilder`, `isLoading`, `shrinkWrap`, `physics`. |
| `frontend/lib/shared/components/app_search_bar.dart` | `AppListTableSearch<T>`, `AppSearchBarFilterGroup`, `AppSearchBarFilterValue`. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` widget, `AppWorkspaceStatusBadge`, `AppWorkspaceStatus`, `AppWorkspaceStatusTone`. |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels` helper, `AppWorkspaceToolbarConfig`. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` and `PageMaxWidth`. |

## Target Architecture

### Tab Configuration

| Tab Name | Route Query Value | Description | Icon | Primary Action Button |
|----------|------------------|-------------|------|----------------------|
| Tasks | `tasks` | Housekeeping cleaning tasks (default) | `Icons.cleaning_services_outlined` | "Create Task" → opens `_TaskForm` dialog |
| Schedules | `schedules` | Recurring cleaning schedules | `Icons.event_repeat_outlined` | "Create Schedule" → opens `_ScheduleForm` dialog |
| Maintenance | `maintenance` | Maintenance / repair requests | `Icons.build_circle_outlined` | "Request Maintenance" → opens `_MaintenanceRequestForm` dialog |

### Section Enum

Add a new enum `HousekeepingSection` to the entities file:

```dart
enum HousekeepingSection {
  tasks,
  schedules,
  maintenance;

  HousekeepingResource get resource {
    return switch (this) {
      HousekeepingSection.tasks => HousekeepingResource.tasks,
      HousekeepingSection.schedules => HousekeepingResource.schedules,
      HousekeepingSection.maintenance => HousekeepingResource.maintenanceRequests,
    };
  }

  static HousekeepingSection fromQueryValue(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'schedules' => HousekeepingSection.schedules,
      'maintenance' => HousekeepingSection.maintenance,
      _ => HousekeepingSection.tasks,
    };
  }

  String get queryValue {
    return switch (this) {
      HousekeepingSection.tasks => 'tasks',
      HousekeepingSection.schedules => 'schedules',
      HousekeepingSection.maintenance => 'maintenance',
    };
  }
}
```

### Routing

**File:** `frontend/lib/app/router/app_router.dart`

Update the GoRoute for housekeeping to extract query parameters:

```dart
GoRoute(
  path: AppRoutes.housekeeping.path,
  name: AppRoutes.housekeeping.name,
  builder: (_, GoRouterState state) {
    final String? section = state.uri.queryParameters['section'];
    final String? search = state.uri.queryParameters['search'];
    return HousekeepingWorkspacePage(
      initialSection: HousekeepingSection.fromQueryValue(section),
      initialSearch: search ?? '',
    );
  },
),
```

### Page Layout

Replace the current `AppWorkspace`-based layout with a `ResponsivePage`-wrapped column, matching Reception:

```
ResponsivePage (maxWidth: PageMaxWidth.dataHeavy)
└─ Column
   ├─ Row
   │  ├─ Expanded → AppTabStrip (3 tabs with counts)
   │  └─ SizedBox(width: spacing.sm)
   │  └─ AppButton.primary (contextual per tab)
   ├─ SizedBox(height: spacing.md)
   └─ AppListTable<HousekeepingWorkItem>
      ├─ page: state.items (server-side paginated)
      ├─ columns: _columnsForSection(section) [per-tab columns]
      ├─ columnVisibilityController: _columnVisibilityController
      ├─ columnVisibilityStorageKey: 'housekeeping_${section.name}'
      ├─ columnWidthStorageKey: 'housekeeping_cw_${section.name}'
      ├─ search: AppListTableSearch with advanced filter
      ├─ onRowSelected: open detail dialog
      ├─ mobileItemBuilder: per-section mobile card
      ├─ onPageChanged: controller.changePage
      ├─ pagination labels
      └─ emptyBuilder: section-aware empty state
```

### Per-Tab Columns

**Tasks tab:**
| Column | Field | Sortable |
|--------|-------|----------|
| Task | title + displayId (copyable) | Yes (title) |
| Location | locationDisplay (room/facility) | Yes |
| Assignee | assigneeLabel | Yes |
| Scheduled | scheduledAt | Yes |
| Status | status badge | Yes |
| Next Action | contextual label | No |

**Schedules tab:**
| Column | Field | Sortable |
|--------|-------|----------|
| Schedule | title + displayId (copyable) | Yes (title) |
| Location | locationDisplay | Yes |
| Frequency | subtitle (frequency string) | No |
| Start Date | startDate | Yes |
| End Date | endDate | Yes |
| Status | status badge | Yes |

**Maintenance tab:**
| Column | Field | Sortable |
|--------|-------|----------|
| Request | title + displayId (copyable) | Yes (title) |
| Location | locationDisplay | Yes |
| Asset | assetLabel | Yes |
| Reported | reportedAt | Yes |
| Status | status badge | Yes |
| Next Action | contextual label (Triage/Complete/View) | No |

### Data & State Management

Keep the existing `HousekeepingWorkspaceController` and its provider `housekeepingWorkspaceControllerProvider`. The controller already supports switching resource types via `applyResource(HousekeepingResource)` and `applyFilters(resource: ...)`. When the user switches tabs, call `controller.applyResource(section.resource)` to reload data for that resource type.

The `HousekeepingWorkspaceState` already holds the current `query.resource` which maps to the active section.

### URL Sync

When the tab changes, call:
```dart
void _updateUrlForSection(HousekeepingSection section) {
  if (!mounted) return;
  final String location = AppRoutes.housekeeping.location(
    queryParameters: <String, String>{
      'section': section.queryValue,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

## Implementation Steps

### 1. Add `HousekeepingSection` enum — File: `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart`

- Add the `HousekeepingSection` enum (as shown above) after the existing `HousekeepingDatePreset` enum.
- This enum maps sections to `HousekeepingResource` values and handles query-parameter parsing.

### 2. Update route builder — File: `frontend/lib/app/router/app_router.dart`

- Import `HousekeepingSection` from the entities file.
- Change the housekeeping `GoRoute` builder from `(_, _) => const HousekeepingWorkspacePage()` to extract `section` and `search` query parameters and pass them as constructor arguments.

### 3. Update `HousekeepingWorkspacePage` constructor — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

- Add optional parameters: `HousekeepingSection? initialSection` and `String initialSearch`.
- Pass them through to `_HousekeepingWorkspaceContent`.

### 4. Refactor `_HousekeepingWorkspaceContent` to use `AppTabStrip` — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Replace the current `AppWorkspace(...)` body layout with:

```dart
@override
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final HousekeepingWorkspaceState state = widget.state;
  final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
  final _HousekeepingCapabilities capabilities = _capabilities(accessPolicy);
  final controller = ref.read(housekeepingWorkspaceControllerProvider.notifier);

  return ResponsivePage(
    maxWidth: PageMaxWidth.dataHeavy,
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppTabStrip(
                  tabs: <AppTabItem>[
                    for (final HousekeepingSection section in HousekeepingSection.values)
                      AppTabItem(
                        id: section.name,
                        icon: _sectionIcon(section),
                        label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                      ),
                  ],
                  selectedId: _section.name,
                  onTabTapped: (String tabId) {
                    for (final HousekeepingSection section in HousekeepingSection.values) {
                      if (section.name == tabId) {
                        setState(() => _section = section);
                        _updateUrlForSection(section);
                        controller.applyResource(section.resource);
                        break;
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              _primaryActionButton(l10n, capabilities, state),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          _HousekeepingWorklistPanel(
            state: state,
            section: _section,
            capabilities: capabilities,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
            onItemSelected: (HousekeepingWorkItem item) {
              unawaited(_openTaskDetailDialog(context, item, capabilities));
            },
          ),
        ],
      ),
    ),
  );
}
```

Add `_section` state field initialized from `widget.initialSection` in `initState`.

### 5. Add section-aware helpers — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Add these helper methods to the state class:

```dart
Widget _primaryActionButton(
  AppLocalizations l10n,
  _HousekeepingCapabilities capabilities,
  HousekeepingWorkspaceState state,
) {
  return switch (_section) {
    HousekeepingSection.tasks => AppButton.primary(
      label: l10n.housekeepingCreateTaskAction,
      leadingIcon: Icons.add_task_outlined,
      enabled: capabilities.canManage && !state.isSaving,
      onPressed: capabilities.canManage
          ? () => _showTaskDialog(context, ref, state)
          : null,
    ),
    HousekeepingSection.schedules => AppButton.primary(
      label: l10n.housekeepingCreateScheduleAction,
      leadingIcon: Icons.event_repeat_outlined,
      enabled: capabilities.canManage && !state.isSaving,
      onPressed: capabilities.canManage
          ? () => _showScheduleDialog(context, ref, state)
          : null,
    ),
    HousekeepingSection.maintenance => AppButton.primary(
      label: l10n.housekeepingRequestMaintenanceAction,
      leadingIcon: Icons.build_circle_outlined,
      enabled: capabilities.canUpdateTasks && !state.isSaving,
      onPressed: capabilities.canUpdateTasks
          ? () => _showMaintenanceRequestDialog(context, ref, state)
          : null,
    ),
  };
}

IconData _sectionIcon(HousekeepingSection section) {
  return switch (section) {
    HousekeepingSection.tasks => Icons.cleaning_services_outlined,
    HousekeepingSection.schedules => Icons.event_repeat_outlined,
    HousekeepingSection.maintenance => Icons.build_circle_outlined,
  };
}

String _sectionLabel(AppLocalizations l10n, HousekeepingSection section) {
  return switch (section) {
    HousekeepingSection.tasks => l10n.housekeepingResourceTasks,
    HousekeepingSection.schedules => l10n.housekeepingResourceSchedules,
    HousekeepingSection.maintenance => l10n.housekeepingResourceMaintenanceRequests,
  };
}

int _sectionCount(HousekeepingWorkspaceState state, HousekeepingSection section) {
  return switch (section) {
    HousekeepingSection.tasks => state.overview.summaryValue('pending_tasks'),
    HousekeepingSection.schedules => state.overview.summaryValue('active_schedules'),
    HousekeepingSection.maintenance => state.overview.summaryValue('open_requests'),
  };
}

void _updateUrlForSection(HousekeepingSection section) {
  if (!mounted) return;
  final String location = AppRoutes.housekeeping.location(
    queryParameters: <String, String>{
      'section': section.queryValue,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

### 6. Update `_HousekeepingWorklistPanel` with per-section columns — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

- Add a `HousekeepingSection section` parameter to `_HousekeepingWorklistPanel`.
- Pass `columnVisibilityStorageKey: 'housekeeping_${section.name}'` and `columnWidthStorageKey: 'housekeeping_cw_${section.name}'` to `AppListTable`.
- Replace the static `columns:` list with a method `_columnsForSection(l10n, section)` that returns per-tab columns as defined in the "Per-Tab Columns" section above.
- Update `mobileItemBuilder` to show section-relevant information.

Specifically for `AppListTable`:

```dart
AppListTable<HousekeepingWorkItem>(
  page: state.items,
  isLoading: state.isRefreshing,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  columnVisibilityController: columnVisibilityController,
  columnVisibilityStorageKey: 'housekeeping_${section.name}',
  columnWidthStorageKey: 'housekeeping_cw_${section.name}',
  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
  search: AppListTableSearch<HousekeepingWorkItem>(
    controller: searchController,
    semanticLabel: l10n.housekeepingSearchLabel,
    hintText: l10n.housekeepingSearchHint,
    clearLabel: l10n.housekeepingClearSearchAction,
    matcher: (_, _) => true,
    onSubmitted: controller.applySearch,
    onClear: () => controller.applySearch(''),
    showAdvancedFilterButton: true,
    advancedFilterButtonLabel: l10n.housekeepingFiltersAction,
    advancedFilterTitle: l10n.housekeepingFiltersTitle,
    advancedFilterApplyLabel: l10n.housekeepingApplyFiltersAction,
    advancedFilterResetLabel: l10n.housekeepingClearFiltersAction,
    enableDateFilter: false,
    filterGroups: _filterGroupsForSection(l10n, state, section),
    filterValue: _filterValue(state.query),
    hasActiveFilters: _hasActiveFilters(state.query),
    onFilterChanged: (AppSearchBarFilterValue value) {
      // Apply section-specific filters (exclude resource filter since tabs handle it)
      controller.applyFilters(
        resource: section.resource,
        queue: _queueFromFilter(value.option(_queueFilterKey)) ?? HousekeepingQueue.all,
        status: value.option(_statusFilterKey),
        facilityId: value.option(_facilityFilterKey),
        roomId: value.option(_roomFilterKey),
        assigneeId: value.option(_assigneeFilterKey),
        datePreset: _datePresetFromFilter(value.option(_datePresetFilterKey)) ?? HousekeepingDatePreset.all,
      );
    },
  ),
  columns: _columnsForSection(l10n, section, capabilities),
  // ... pagination, emptyBuilder, mobileItemBuilder, onRowSelected unchanged
)
```

### 7. Simplify filter groups per section — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Create a `_filterGroupsForSection` method that excludes the `_resourceFilterKey` filter group (since tabs now handle resource switching). The remaining filter groups (queue, status, facility, room, assignee, date preset) stay, but status choices should be section-aware:

```dart
List<AppSearchBarFilterGroup> _filterGroupsForSection(
  AppLocalizations l10n,
  HousekeepingWorkspaceState state,
  HousekeepingSection section,
) {
  final HousekeepingLookups lookups = state.overview.lookups;
  return <AppSearchBarFilterGroup>[
    if (section == HousekeepingSection.tasks)
      AppSearchBarFilterGroup(
        key: _queueFilterKey,
        label: l10n.housekeepingQueueFilterLabel,
        allLabel: l10n.housekeepingQueueAll,
        choices: <AppSearchBarFilterChoice>[
          for (final HousekeepingQueue queue in HousekeepingQueue.values)
            if (queue != HousekeepingQueue.all && !queue.isRequestQueue)
              AppSearchBarFilterChoice(
                value: queue.name,
                label: _queueLabel(l10n, queue),
                icon: _queueIcon(queue),
              ),
        ],
      ),
    if (section == HousekeepingSection.maintenance)
      AppSearchBarFilterGroup(
        key: _queueFilterKey,
        label: l10n.housekeepingQueueFilterLabel,
        allLabel: l10n.housekeepingQueueAll,
        choices: <AppSearchBarFilterChoice>[
          for (final HousekeepingQueue queue in HousekeepingQueue.values)
            if (queue != HousekeepingQueue.all && !queue.isTaskQueue)
              AppSearchBarFilterChoice(
                value: queue.name,
                label: _queueLabel(l10n, queue),
                icon: _queueIcon(queue),
              ),
        ],
      ),
    AppSearchBarFilterGroup(
      key: _statusFilterKey,
      label: l10n.housekeepingStatusFilterLabel,
      allLabel: l10n.housekeepingStatusAll,
      choices: <AppSearchBarFilterChoice>[
        for (final String status in _statusChoicesFor(section.resource))
          AppSearchBarFilterChoice(
            value: status,
            label: _statusLabelForResource(l10n, section.resource, status),
            icon: Icons.flag_outlined,
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: _facilityFilterKey,
      label: l10n.housekeepingFacilityFilterLabel,
      allLabel: l10n.housekeepingAllFacilities,
      choices: _lookupFilterChoices(lookups.facilities, Icons.business),
    ),
    AppSearchBarFilterGroup(
      key: _roomFilterKey,
      label: l10n.housekeepingRoomFilterLabel,
      allLabel: l10n.housekeepingAllRooms,
      choices: _lookupFilterChoices(lookups.rooms, Icons.meeting_room_outlined),
    ),
    if (section == HousekeepingSection.tasks)
      AppSearchBarFilterGroup(
        key: _assigneeFilterKey,
        label: l10n.housekeepingAssigneeFilterLabel,
        allLabel: l10n.housekeepingAllAssignees,
        choices: _lookupFilterChoices(lookups.assignees, Icons.person_outline),
      ),
    AppSearchBarFilterGroup(
      key: _datePresetFilterKey,
      label: l10n.housekeepingDateFilterLabel,
      allLabel: l10n.housekeepingDateAll,
      choices: <AppSearchBarFilterChoice>[
        for (final HousekeepingDatePreset preset in HousekeepingDatePreset.values)
          if (preset != HousekeepingDatePreset.all)
            AppSearchBarFilterChoice(
              value: preset.name,
              label: _datePresetLabel(l10n, preset),
              icon: Icons.event_outlined,
            ),
      ],
    ),
  ];
}
```

### 8. Remove `AppWorkspace` wrapper, replace with `ResponsivePage` — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

- Remove the `AppWorkspace(...)` wrapper (title, leadingIcon, toolbar, body pattern).
- Remove the `appWorkspaceToolbarWithLabels(...)` call and its summary notifications / secondary buttons / refresh button configuration.
- Wrap the new content in `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: ...)` as Reception does.
- Keep the toolbar summary notifications: move them into an optional `AppWorkspaceSummaryNotification` row above the tabs OR display counts within tab labels (preferred — matching Reception's `${label} (${count})` pattern).
- Keep the secondary toolbar actions (Report Summary) as an overflow menu or inline button alongside the primary action.

### 9. Add `go_router` import — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Add:
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
```

### 10. Update `_hasActiveFilters` to exclude resource check — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Since tabs now handle resource switching, the `_hasActiveFilters` function should NOT count `resource != HousekeepingResource.tasks` as an active filter. Update:

```dart
bool _hasActiveFilters(HousekeepingWorkspaceQuery query) {
  return query.queue != HousekeepingQueue.all ||
      _notEmpty(query.status) ||
      _notEmpty(query.facilityId) ||
      _notEmpty(query.roomId) ||
      _notEmpty(query.assigneeId) ||
      query.datePreset != HousekeepingDatePreset.all;
}
```

### 11. Update `_filterValue` to exclude resource — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Remove the resource entry from the filter value map since tabs now handle it:

```dart
AppSearchBarFilterValue _filterValue(HousekeepingWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.queue != HousekeepingQueue.all)
        _queueFilterKey: query.queue.name,
      if (_notEmpty(query.status)) _statusFilterKey: query.status!,
      if (_notEmpty(query.facilityId)) _facilityFilterKey: query.facilityId!,
      if (_notEmpty(query.roomId)) _roomFilterKey: query.roomId!,
      if (_notEmpty(query.assigneeId)) _assigneeFilterKey: query.assigneeId!,
      if (query.datePreset != HousekeepingDatePreset.all)
        _datePresetFilterKey: query.datePreset.name,
    },
  );
}
```

### 12. Remove `_resourceFilterKey` constant and `_resourceFromFilter` function — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

These are no longer needed since tabs replace the resource filter dropdown. Remove:
- `const String _resourceFilterKey = 'resource';`
- `HousekeepingResource? _resourceFromFilter(String? value) { ... }`
- The `_resourceFilterKey` entry from `_filterGroups` (function being replaced by `_filterGroupsForSection`).

### 13. Ensure tab state syncs on initial load — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

In `initState`, if `widget.initialSection` is provided and differs from the default (tasks), call `controller.applyResource(section.resource)` in a post-frame callback to load the correct data for the initial tab:

```dart
@override
void initState() {
  super.initState();
  _section = widget.initialSection ?? HousekeepingSection.tasks;
  _searchController = TextEditingController(text: widget.initialSearch ?? widget.state.query.search);
  _tableColumnController = AppListTableColumnVisibilityController<HousekeepingWorkItem>();

  if (_section != HousekeepingSection.tasks) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(housekeepingWorkspaceControllerProvider.notifier)
          .applyResource(_section.resource);
    });
  }
}
```

### 14. Implement per-section columns method — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

```dart
List<AppListTableColumn<HousekeepingWorkItem>> _columnsForSection(
  AppLocalizations l10n,
  HousekeepingSection section,
  _HousekeepingCapabilities capabilities,
) {
  switch (section) {
    case HousekeepingSection.tasks:
      return _taskColumns(l10n, capabilities);
    case HousekeepingSection.schedules:
      return _scheduleColumns(l10n);
    case HousekeepingSection.maintenance:
      return _maintenanceColumns(l10n, capabilities);
  }
}
```

Then define each column set, reusing the existing column definitions where possible and adjusting for section-specific data fields.

### 15. Update mobile item builder per section — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Replace the single `mobileItemBuilder` with a section-aware builder:

```dart
mobileItemBuilder: (BuildContext context, HousekeepingWorkItem item) {
  return switch (section) {
    HousekeepingSection.tasks => _taskMobileItem(context, l10n, item),
    HousekeepingSection.schedules => _scheduleMobileItem(context, l10n, item),
    HousekeepingSection.maintenance => _maintenanceMobileItem(context, l10n, item),
  };
},
```

### 16. Clean up dead `_filterGroups` function — File: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`

Remove the old `_filterGroups(AppLocalizations l10n, HousekeepingWorkspaceState state)` function, which is replaced by `_filterGroupsForSection`.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Tab navigation bar above the table |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Data table with columns, search, pagination, mobile builder |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/components.dart` | Search bar with advanced filter integration |
| `AppListTableColumn<T>` | `package:hosspi_hms/shared/components/components.dart` | Column definition with cellBuilder, sortComparator |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/components.dart` | Column visibility state management |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` | Primary action button per tab |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/layout.dart` | Status badge in table cells |
| `AppListItemRow` | `package:hosspi_hms/shared/components/components.dart` | Mobile card layout for table items |
| `AppCopyableIdentifier` | `package:hosspi_hms/shared/components/components.dart` | Copyable ID display in cells |
| `AppInlineMetaText` | `package:hosspi_hms/shared/components/components.dart` | Metadata lines in mobile cards |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Page-level responsive wrapper |
| `AppStateView` | `package:hosspi_hms/shared/components/components.dart` | Empty state display |
| `appListTableCompareText` / `appListTableCompareDateTime` | `package:hosspi_hms/shared/components/components.dart` | Sort comparators |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart` | Add `HousekeepingSection` enum with `resource` getter, `fromQueryValue`, and `queryValue`. |
| `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` | Major refactor: replace `AppWorkspace` with `ResponsivePage` + `AppTabStrip`, add per-section columns, add URL sync, add contextual primary action, remove resource filter dropdown, add `_filterGroupsForSection`, add section helpers. Accept `initialSection` and `initialSearch` parameters. |
| `frontend/lib/app/router/app_router.dart` | Update housekeeping `GoRoute` builder to extract `section` and `search` query parameters. Add import for `HousekeepingSection`. |

## Files to Delete (if any)

No files need to be deleted. The refactoring restructures the existing monolith page file in place.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the old `_filterGroups` function (replaced by `_filterGroupsForSection`).
- [ ] Remove the `_resourceFilterKey` constant.
- [ ] Remove the `_resourceFromFilter` function.
- [ ] Remove unused imports across all modified files.
- [ ] Remove the `appWorkspaceToolbarWithLabels` call and any toolbar-specific code that is no longer referenced (summary notifications moved to tab labels, secondary buttons moved to per-tab primary actions).
- [ ] Remove imports for `app_route_icons.dart` if `AppRouteIcons.housekeeping` is no longer used as the workspace leading icon.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactoring only restructures the frontend UI layer. The backend API, database schema, and query patterns remain identical. The `housekeeping-workspace` endpoint already supports `resource` and `queue` parameters that the tabs will leverage through the existing controller methods.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full table with all columns visible per section. AppTabStrip renders inline with the primary action button. Table uses standard row height with copyable identifiers and status badges.
- **Tablet (600–1023px):** AppTabStrip wraps if needed (uses `Wrap` internally). Columns with lower priority may be hidden via column visibility (user can toggle). Primary action button stacks below tabs if insufficient width.
- **Mobile (<600px):** `mobileItemBuilder` renders `AppListItemRow` cards instead of table rows. Tab strip wraps to multiple lines. Primary action button may move to a FAB or remain inline above the list.

The breakpoint utility is `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart`. The `ResponsivePage` widget already handles responsive width constraints. `AppListTable` automatically switches between desktop table and mobile card layout.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/housekeeping/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL and triggers `applyResource` on the controller
- [ ] Deep linking: navigating directly to `/housekeeping?section=maintenance` renders the Maintenance tab active
- [ ] Per-section columns: each tab displays the correct column set
- [ ] Search: typing in the search bar calls `controller.applySearch`
- [ ] Filter dialog: filter button opens the section-appropriate filter groups (no resource filter in advanced panel)
- [ ] Primary action: button label and icon change per tab (Create Task / Create Schedule / Request Maintenance)
- [ ] Section counts: tab labels show counts from the workspace overview
- [ ] Responsive layout: widget tests verify `mobileItemBuilder` is used on narrow viewports
- [ ] No regressions: existing task lifecycle (create/assign/start/complete/cancel), schedule creation, and maintenance request workflows still function correctly

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 3 tabs: Tasks, Schedules, Maintenance — matching the Reception workspace pattern
- [ ] Each tab has its own URL that supports deep linking (`?section=tasks|schedules|maintenance`)
- [ ] The primary action button is contextual per tab (Create Task / Create Schedule / Request Maintenance) and positioned adjacent to the tab strip
- [ ] The page body uses `AppListTable` with section-specific columns, `columnVisibilityStorageKey`, and `columnWidthStorageKey`
- [ ] The advanced filter panel no longer contains a "Resource" filter group — tabs handle resource switching
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (using `ResponsivePage` and `AppListTable`'s built-in mobile rendering)
- [ ] All domain-specific business logic is preserved: task CRUD, schedule creation, maintenance request lifecycle, triage, assignment
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] Tab counts display relevant summary values from `HousekeepingWorkspaceOverview`
