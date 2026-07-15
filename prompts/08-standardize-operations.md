# Standardize Operations Screen

## Objective

Refactor the Operations workspace to match the standardized tab-and-table layout used by the Reception workspace. The Operations screen currently renders all maintenance requests in a single flat `AppListTable` with status counts shown as `AppWorkspaceSummaryNotification` badges. This refactor adds routable `AppTabStrip` tabs (All Requests, Open, In Progress, Completed, Assets), deep-link support via `OperationsWorkspaceQuery`, per-tab URL synchronization, per-tab column configurations, and per-tab column-visibility storage keys — following the exact patterns established by `ReceptionWorkspacePage`.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Implementation files

| Layer | File |
|-------|------|
| Page | `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart` (1942 lines) |
| Controller | `frontend/lib/features/operations/presentation/controllers/operations_workspace_controller.dart` (641 lines) |
| Entities | `frontend/lib/features/operations/domain/entities/operations_entities.dart` (422 lines) |
| Repository (interface) | `frontend/lib/features/operations/domain/repositories/operations_repository.dart` |
| Repository (impl) | `frontend/lib/features/operations/data/repositories/operations_repository_impl.dart` |
| DTOs | `frontend/lib/features/operations/data/dtos/operations_dtos.dart` |
| Routes | `frontend/lib/app/router/app_routes.dart` (lines 444-455) |
| Router | `frontend/lib/app/router/app_router.dart` (lines 278-282) |

### Tests

| Type | File |
|------|------|
| Controller unit | `frontend/test/features/operations/presentation/operations_workspace_controller_test.dart` |
| DTO unit | `frontend/test/features/operations/data/operations_dtos_test.dart` |
| Patrol integration | `frontend/patrol_test/operations_flow_test.dart` |

### Current structure description

- **Outer widget**: `OperationsWorkspacePage` (`ConsumerWidget`) wrapping `AsyncStateScaffold<OperationsWorkspaceState>`.
- **Inner widget**: `_OperationsWorkspaceContent` (`ConsumerStatefulWidget`) holding local state for `_searchController` and `_tableColumnController`.
- **Layout**: `AppWorkspace` with `appWorkspaceToolbarWithLabels(...)`. Summary notifications show counts for All, Open, In Progress, Completed, Cancelled, and Assets. Secondary toolbar has "Open Report" button. Primary toolbar has "Create Request" button.
- **Body**: A single `_OperationsQueuePanel` containing `AppListTable<OperationsWorkItem>` with server-side paginated data, advanced search filters (status, priority, facility, asset, date range), 5 default columns + 3 optional column choices.
- **Detail dialog**: `AppDialog` → `_OperationsDetailPanel` → `AppWorkspaceDetailPanel` with status banner, info tile grid, action buttons, and service logs.

### Problems / gaps vs. Reception reference

1. **No `AppTabStrip`** — status categories are shown only as toolbar summary notifications, not navigable tabs.
2. **No `OperationsWorkspaceQuery`** — no deep-link query value object. Route builder is `const OperationsWorkspacePage()` with no URI parsing.
3. **No URL sync on section change** — no `_updateUrlForSection()`, no `GoRouter.replace()` call on tab switch.
4. **No per-tab data filtering** — all work items displayed in one list regardless of status; filtering is manual via advanced filters only.
5. **No per-tab column visibility storage keys** — single storage key for all views instead of per-tab keys like `operations_open`, `operations_in_progress`, etc.
6. **No per-tab column set** — the Assets tab should display asset-specific columns, not the same maintenance-request columns.
7. **Summary notifications are clickable but don't visually indicate the active section** — clicking them calls `controller.applyStatus(...)` which modifies the query but has no tab UI feedback.

### Shared components already in use (no changes needed)

- `AsyncStateScaffold`, `AppWorkspace`, `appWorkspaceToolbarWithLabels`, `AppWorkspaceSummaryNotification`
- `AppListTable`, `AppListTableSearch`, `AppListTableColumn`, `AppListTableColumnVisibilityController`
- `AppDialog`, `showAppDialog`, `AppButton`, `AppWorkspaceDetailPanel`, `AppWorkspaceStatusBadge`
- `AppInfoTileGrid`, `AppSectionPanel`, `AppContentPanel`, `AppFormShell`, `AppFormActions`
- `AppCopyableIdentifier`, `AppInlineMetaText`, `AppListItemRow`, `AppListItemText`, `AppResponsiveWrap`
- `AppReportSummaryGrid`, `AppReportPreviewPanel`, `AppFailureStateView`, `AppStateView`
- `ResponsivePage`, `PageMaxWidth`

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key patterns to extract |
|------|------------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `AppTabStrip` wiring, `_updateUrlForSection()` via `GoRouter.replace()`, per-tab `_columnsForSection()`, per-tab `columnVisibilityStorageKey: 'reception_${_section.name}'`, `_applyDeepLink()` for initial section, `_searchMatcher`, mobile builder per-tab |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery.fromUri(Uri uri)` factory pattern, `ReceptionDeskSection` enum with icon/label/count mappings |
| `frontend/lib/app/router/app_router.dart` (lines 139-146) | GoRoute builder that passes `initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri)` to the page |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` constructor: `tabs` (`List<AppTabItem>`), `selectedId`, `onTabTapped` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor: `columnVisibilityStorageKey`, `columnWidthStorageKey`, `mobileItemBuilder` |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` body layout structure |

## Target Architecture

### Tab Configuration

| Tab Name | Enum Value | Query Value | Description | Primary Action Button |
|----------|-----------|-------------|-------------|----------------------|
| All Requests | `allRequests` | `all` | All maintenance requests regardless of status | Create Request → `_showCreateRequestDialog` |
| Open | `open` | `open` | Requests with OPEN status (unassigned/new) | Create Request → `_showCreateRequestDialog` |
| In Progress | `inProgress` | `in-progress` | Requests with IN_PROGRESS status | Create Request → `_showCreateRequestDialog` |
| Completed | `completed` | `completed` | Resolved requests (COMPLETED + CANCELLED) | Create Request → `_showCreateRequestDialog` |
| Assets | `assets` | `assets` | Facility asset inventory | Create Request → `_showCreateRequestDialog` |

### Routing

**File to modify:** `frontend/lib/app/router/app_router.dart`

Change the operations GoRoute builder from:

```dart
GoRoute(
  path: AppRoutes.operations.path,
  name: AppRoutes.operations.name,
  builder: (_, _) => const OperationsWorkspacePage(),
),
```

To:

```dart
GoRoute(
  path: AppRoutes.operations.path,
  name: AppRoutes.operations.name,
  builder: (_, GoRouterState state) {
    return OperationsWorkspacePage(
      initialQuery: OperationsWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

This mirrors the Reception route at lines 139-146 of the same file.

### Page Layout

```
OperationsWorkspacePage (ConsumerWidget)
  └── AsyncStateScaffold<OperationsWorkspaceState>
      └── _OperationsWorkspaceContent (ConsumerStatefulWidget)
          └── AppWorkspace(title, leadingIcon, toolbar, body)
              ├── toolbar: appWorkspaceToolbarWithLabels(...)
              │   ├── summaryNotifications (keep existing status counts)
              │   ├── secondary: [Open Report button]
              │   └── primary: [Create Request button] (if canMutate)
              └── body: Column
                  ├── AppFailureStateView (if lastFailure != null)
                  ├── Row (or responsive layout)
                  │   ├── AppTabStrip(tabs, selectedId, onTabTapped)  ← NEW
                  │   └── (primary action button stays in toolbar)
                  └── _OperationsQueuePanel / _OperationsAssetsPanel  ← CONDITIONAL PER TAB
                      └── AppListTable<T> with per-tab columns
```

The `AppTabStrip` should be placed at the top of the body `Column`, before the table panel — matching the Reception pattern where the tab strip is rendered between the toolbar and the table.

### Data & State Management

**No new providers/controllers needed.** The existing `operationsWorkspaceControllerProvider` already supports:
- `applyStatus(String?)` — used to filter by status when switching request tabs
- `clearFilters()` — used when switching to "All Requests" tab
- `listAssets()` — data already in `state.assets` for the Assets tab

**Per-tab filtering logic** (in the page, not the controller):

| Tab | Data Source | Filter |
|-----|------------|--------|
| All Requests | `state.workItems` | No status filter — call `controller.clearFilters()` when selected (if a status filter was active from another tab) |
| Open | `state.workItems` | `controller.applyStatus('OPEN')` |
| In Progress | `state.workItems` | `controller.applyStatus('IN_PROGRESS')` |
| Completed | `state.workItems` | `controller.applyStatus('COMPLETED')` or show both COMPLETED + CANCELLED locally |
| Assets | `state.assets` | Separate `AppListTable<OperationsAsset>` rendering `state.assets.items` |

When switching tabs, the page calls the controller's existing `applyStatus` / `clearFilters` methods. The "Completed" tab should filter server-side for `COMPLETED` status and also display `CANCELLED` items. To achieve this, either:
- (A) Use the existing `applyFilters()` method and pass both statuses (if the API supports multi-value status), OR
- (B) Call `applyStatus('COMPLETED')` for COMPLETED and show CANCELLED items in a separate sub-section, OR
- (C) Add a small controller method `applyCompletedSection()` that queries with no status filter and does client-side filtering.

Choose the simplest approach that works with the existing API. If the API only supports single-status filtering, use approach (A) with `applyStatus('COMPLETED')` for the Completed tab, and add a separate "Cancelled" count indicator in the tab label (e.g., "Completed (5)" showing both).

## Implementation Steps

### 1. Create `OperationsWorkspaceQuery` value object — File: `frontend/lib/features/operations/domain/entities/operations_entities.dart`

Add a new class following the `ReceptionWorkspaceQuery` pattern:

```dart
@immutable
final class OperationsWorkspaceQuery {
  const OperationsWorkspaceQuery({
    this.section = '',
    this.search = '',
    this.requestId = '',
  });

  factory OperationsWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return OperationsWorkspaceQuery(
      section: pick(<String>['section', 'panel', 'tab']),
      search: pick(<String>['search', 'q']),
      requestId: pick(<String>['requestId', 'request_id', 'id']),
    );
  }

  final String section;
  final String search;
  final String requestId;

  bool get hasRouteTargeting =>
      section.isNotEmpty || search.isNotEmpty || requestId.isNotEmpty;

  String get signature => '$section|$search|$requestId';
}
```

### 2. Create `OperationsDeskSection` enum — File: `frontend/lib/features/operations/domain/entities/operations_entities.dart`

Add after `OperationsWorkspaceQuery`:

```dart
enum OperationsDeskSection {
  allRequests,
  open,
  inProgress,
  completed,
  assets,
}
```

### 3. Update `OperationsWorkspacePage` constructor — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

Change from:

```dart
class OperationsWorkspacePage extends ConsumerWidget {
  const OperationsWorkspacePage({super.key});
```

To:

```dart
class OperationsWorkspacePage extends ConsumerWidget {
  const OperationsWorkspacePage({super.key, this.initialQuery = const OperationsWorkspaceQuery()});

  final OperationsWorkspaceQuery initialQuery;
```

Pass `initialQuery` down to `_OperationsWorkspaceContent`:

```dart
dataBuilder: (BuildContext context, OperationsWorkspaceState state) {
  return _OperationsWorkspaceContent(state: state, initialQuery: initialQuery);
},
```

### 4. Add tab state and URL sync to `_OperationsWorkspaceContent` — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

In `_OperationsWorkspaceContentState`, add:

```dart
late OperationsDeskSection _section;
```

Add `initialQuery` parameter to `_OperationsWorkspaceContent`:

```dart
class _OperationsWorkspaceContent extends ConsumerStatefulWidget {
  const _OperationsWorkspaceContent({required this.state, this.initialQuery = const OperationsWorkspaceQuery()});

  final OperationsWorkspaceState state;
  final OperationsWorkspaceQuery initialQuery;
```

In `initState()`, resolve the initial section from the query:

```dart
@override
void initState() {
  super.initState();
  _section = _sectionFromQuery(widget.initialQuery.section);
  _searchController = TextEditingController(text: widget.state.query.search);
  _tableColumnController =
      AppListTableColumnVisibilityController<OperationsWorkItem>();
  _applyDeepLink(widget.initialQuery);
}
```

Add these private methods (following the Reception pattern):

```dart
static OperationsDeskSection _sectionFromQuery(String value) {
  return switch (value.trim().toLowerCase()) {
    'open' => OperationsDeskSection.open,
    'in-progress' => OperationsDeskSection.inProgress,
    'completed' => OperationsDeskSection.completed,
    'assets' => OperationsDeskSection.assets,
    _ => OperationsDeskSection.allRequests,
  };
}

static String _sectionToQueryValue(OperationsDeskSection section) {
  return switch (section) {
    OperationsDeskSection.allRequests => 'all',
    OperationsDeskSection.open => 'open',
    OperationsDeskSection.inProgress => 'in-progress',
    OperationsDeskSection.completed => 'completed',
    OperationsDeskSection.assets => 'assets',
  };
}

void _updateUrlForSection(OperationsDeskSection section) {
  if (!mounted) return;
  final String tab = _sectionToQueryValue(section);
  final String location = AppRoutes.operations.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}

void _applyDeepLink(OperationsWorkspaceQuery query) {
  if (!query.hasRouteTargeting) return;
  if (query.search.isNotEmpty) {
    _searchController.text = query.search;
    ref.read(operationsWorkspaceControllerProvider.notifier).applySearch(query.search);
  }
  _onTabChanged(_section);
}

void _onTabChanged(OperationsDeskSection section) {
  setState(() => _section = section);
  _updateUrlForSection(section);

  final OperationsWorkspaceController controller = ref.read(
    operationsWorkspaceControllerProvider.notifier,
  );
  switch (section) {
    case OperationsDeskSection.allRequests:
      controller.clearFilters();
    case OperationsDeskSection.open:
      controller.applyStatus('OPEN');
    case OperationsDeskSection.inProgress:
      controller.applyStatus('IN_PROGRESS');
    case OperationsDeskSection.completed:
      controller.applyStatus('COMPLETED');
    case OperationsDeskSection.assets:
      break; // Assets tab shows state.assets, no request filter needed
  }
}
```

Add this import to the top of the file:

```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
```

### 5. Add `AppTabStrip` to the body — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

In the `build()` method of `_OperationsWorkspaceContentState`, add the tab strip inside the `AppWorkspace` body `Column`, before the table panel:

```dart
body: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: <Widget>[
    if (lastFailure != null) ...<Widget>[
      AppFailureStateView(
        failure: lastFailure,
        onRetry: controller.refresh,
      ),
      SizedBox(height: Theme.of(context).spacing.md),
    ],
    AppTabStrip(
      tabs: <AppTabItem>[
        for (final OperationsDeskSection section in OperationsDeskSection.values)
          AppTabItem(
            id: section.name,
            icon: _sectionIcon(section),
            label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
          ),
      ],
      selectedId: _section.name,
      onTabTapped: (String tabId) {
        for (final OperationsDeskSection section in OperationsDeskSection.values) {
          if (section.name == tabId) {
            _onTabChanged(section);
            break;
          }
        }
      },
    ),
    SizedBox(height: Theme.of(context).spacing.md),
    if (_section == OperationsDeskSection.assets)
      _OperationsAssetsPanel(
        state: state,
      )
    else
      _OperationsQueuePanel(
        state: state,
        searchController: _searchController,
        columnVisibilityController: _tableColumnController,
        onItemSelected: (OperationsWorkItem item) {
          unawaited(_openRequestDetailDialog(context, item, canMutate));
        },
        section: _section,
      ),
  ],
),
```

Add helper methods for tab icons, labels, and counts:

```dart
static IconData _sectionIcon(OperationsDeskSection section) {
  return switch (section) {
    OperationsDeskSection.allRequests => Icons.inventory_2_outlined,
    OperationsDeskSection.open => Icons.pending_actions_outlined,
    OperationsDeskSection.inProgress => Icons.engineering_outlined,
    OperationsDeskSection.completed => Icons.task_alt_outlined,
    OperationsDeskSection.assets => Icons.precision_manufacturing_outlined,
  };
}

static String _sectionLabel(AppLocalizations l10n, OperationsDeskSection section) {
  return switch (section) {
    OperationsDeskSection.allRequests => l10n.operationsAllRequestsSummaryLabel,
    OperationsDeskSection.open => l10n.operationsOpenSummaryLabel,
    OperationsDeskSection.inProgress => l10n.operationsInProgressSummaryLabel,
    OperationsDeskSection.completed => l10n.operationsCompletedSummaryLabel,
    OperationsDeskSection.assets => l10n.operationsAssetsSummaryLabel,
  };
}

static int _sectionCount(OperationsWorkspaceState state, OperationsDeskSection section) {
  return switch (section) {
    OperationsDeskSection.allRequests =>
      state.workItems.totalItemCount ?? state.workItems.items.length,
    OperationsDeskSection.open => state.openCount,
    OperationsDeskSection.inProgress => state.inProgressCount,
    OperationsDeskSection.completed =>
      state.completedCount + state.cancelledCount,
    OperationsDeskSection.assets => state.assetCount,
  };
}
```

### 6. Pass `section` to `_OperationsQueuePanel` for per-tab column config — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

Add `section` parameter to `_OperationsQueuePanel`:

```dart
class _OperationsQueuePanel extends ConsumerWidget {
  const _OperationsQueuePanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onItemSelected,
    required this.section,
  });

  final OperationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<OperationsWorkItem>
      columnVisibilityController;
  final ValueChanged<OperationsWorkItem> onItemSelected;
  final OperationsDeskSection section;
```

Update the `AppListTable` inside `_OperationsQueuePanel.build()` to use per-tab storage keys:

```dart
columnVisibilityStorageKey: 'operations_${section.name}',
columnWidthStorageKey: 'operations_cw_${section.name}',
```

### 7. Create `_OperationsAssetsPanel` widget — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

Add a new widget for the Assets tab that renders an `AppListTable<OperationsAsset>`:

```dart
class _OperationsAssetsPanel extends StatelessWidget {
  const _OperationsAssetsPanel({required this.state});

  final OperationsWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppListTable<OperationsAsset>(
      items: state.assets.items,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityStorageKey: 'operations_assets',
      columnWidthStorageKey: 'operations_cw_assets',
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.operationsNoAssetsTitle,
        body: l10n.operationsNoAssetsBody,
      ),
      columns: <AppListTableColumn<OperationsAsset>>[
        AppListTableColumn<OperationsAsset>(
          label: l10n.operationsAssetNameColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return _CopyableSubtitleCell(
              title: asset.effectiveLabel,
              identifier: asset.effectiveDisplayId,
            );
          },
        ),
        AppListTableColumn<OperationsAsset>(
          label: l10n.operationsAssetTagColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return Text(_display(asset.assetTag, l10n.operationsUnknownValue));
          },
        ),
        AppListTableColumn<OperationsAsset>(
          label: l10n.operationsStatusColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return _OperationStatusBadge(status: asset.status);
          },
        ),
        AppListTableColumn<OperationsAsset>(
          label: l10n.operationsLocationColumnLabel,
          cellBuilder: (BuildContext context, OperationsAsset asset) {
            return Text(_display(asset.facilityLabel, asset.facilityId ?? l10n.operationsUnknownValue));
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, OperationsAsset asset) {
        return AppListItemRow(
          leadingIcon: Icons.precision_manufacturing_outlined,
          title: asset.effectiveLabel,
          subtitle: _display(asset.assetTag, ''),
          trailing: _OperationStatusBadge(status: asset.status),
          details: <Widget>[
            AppCopyableIdentifier(
              value: asset.effectiveDisplayId,
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
```

**Note:** The labels `operationsNoAssetsTitle`, `operationsNoAssetsBody`, `operationsAssetNameColumnLabel`, and `operationsAssetTagColumnLabel` may not exist in the l10n files. If they are missing, add them to the ARB files following the existing naming conventions (look for `operationsNoRequestsTitle` as a template). Alternatively, if the l10n generation is complex, use inline string literals temporarily and mark them with a `// TODO(l10n):` comment.

### 8. Update the GoRoute builder — File: `frontend/lib/app/router/app_router.dart`

At lines 278-282, change:

```dart
GoRoute(
  path: AppRoutes.operations.path,
  name: AppRoutes.operations.name,
  builder: (_, _) => const OperationsWorkspacePage(),
),
```

To:

```dart
GoRoute(
  path: AppRoutes.operations.path,
  name: AppRoutes.operations.name,
  builder: (_, GoRouterState state) {
    return OperationsWorkspacePage(
      initialQuery: OperationsWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

Add the import at the top of the file:

```dart
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
```

(Check if a barrel export already covers this; if `operations_entities.dart` is re-exported via a package-level export, use that instead.)

### 9. Remove redundant summary notification tap handlers — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

The `_summaryNotifications` method currently makes each notification badge clickable with `onSelected: () => controller.applyStatus(...)`. Since tabs now handle section switching, update the `onSelected` callbacks to instead call `_onTabChanged(...)` with the corresponding section:

Update `_summaryNotifications` to accept a callback for section changes, or simply remove the `onSelected` callbacks since the tab strip now handles navigation. The summary notifications remain as count displays in the toolbar — they should not duplicate the tab-switching behavior.

Change each `onSelected` to `null` or remove the parameter entirely:

```dart
AppWorkspaceSummaryNotification(
  label: l10n.operationsOpenSummaryLabel,
  count: state.openCount,
  icon: Icons.pending_actions_outlined,
  tone: AppWorkspaceStatusTone.warning,
  // Remove onSelected — tabs handle section navigation now
),
```

### 10. Update tests — File: `frontend/test/features/operations/presentation/operations_workspace_controller_test.dart`

Update existing tests if any reference the page constructor (now requires `initialQuery` parameter). Since `initialQuery` has a default value, most tests should not break. Verify.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Tab bar at top of body, one `AppTabItem` per `OperationsDeskSection` enum value |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Already used for requests; add a second instance for `OperationsAsset` on the Assets tab |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/components.dart` | Already used — no changes |
| `AppListTableColumn<T>` | `package:hosspi_hms/shared/components/components.dart` | Already used — add asset-specific columns |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/components.dart` | Already used — per-tab storage keys |
| `AppButton.primary` / `.secondary` | `package:hosspi_hms/shared/components/components.dart` | Already used — no changes |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — no changes |
| `appWorkspaceToolbarWithLabels` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — no changes |
| `AppWorkspaceSummaryNotification` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — remove `onSelected` handlers |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — no changes |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — no changes |
| `AppWorkspaceDetailPanel` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — no changes |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — add `.empty` for Assets tab |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — reuse for asset status badges |
| `AppListItemRow` / `AppCopyableIdentifier` | `package:hosspi_hms/shared/components/components.dart` | Already used — reuse for asset mobile items |
| `GoRouter` | `package:go_router/go_router.dart` | For `GoRouter.of(context).replace<void>(...)` in URL sync |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | For `AppRoutes.operations.location(queryParameters: ...)` |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/operations/domain/entities/operations_entities.dart` | Add `OperationsWorkspaceQuery` class and `OperationsDeskSection` enum |
| `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart` | Add `initialQuery` parameter, `_section` state, `AppTabStrip`, per-tab panel switching, `_OperationsAssetsPanel`, URL sync methods, per-tab column storage keys, remove summary notification `onSelected` handlers |
| `frontend/lib/app/router/app_router.dart` | Update operations GoRoute builder to parse `OperationsWorkspaceQuery.fromUri(state.uri)` |

## Files to Delete (if any)

No files to delete. This refactor restructures the existing page — it does not replace files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST clean up:

- [ ] Remove the `onSelected` callbacks from `_summaryNotifications` that duplicate tab-switching behavior (specifically the `controller.applyStatus(...)` and `controller.clearFilters()` calls inside notification badges).
- [ ] Remove unused imports across all modified files after adding `go_router` and `app_routes` imports.
- [ ] Verify that no dead references to the old `const OperationsWorkspacePage()` constructor remain in tests or other files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the frontend UI layer (adding tabs, deep-link support, and per-tab rendering). The backend data model (`maintenance_request`, `asset`, `asset_service_log` tables and `MaintenanceStatus` enum) remains identical.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full table with all columns visible, `AppTabStrip` renders as a horizontal `Wrap` of tab chips, side-by-side layout if detail panel is open.
- **Tablet (600–839px / `md`):** Condensed table with narrower default column widths, tab strip wraps to multiple lines if needed, detail panel opens as a dialog.
- **Mobile (<600px / `xs`/`sm`):** `mobileItemBuilder` renders `AppListItemRow` cards instead of table rows, tab strip scrolls horizontally, detail panel opens as a full-screen dialog.

The `AppListTable` already handles responsive switching internally via `AppBreakpoints.fromConstraints()`. The `AppTabStrip` uses `Wrap` which naturally handles overflow. No additional responsive code is needed beyond what the shared components provide.

Reference breakpoint utility: `frontend/lib/core/responsive/app_breakpoints.dart` — `AppBreakpoints.of(context)`, `AppBreakpoint.isMobile`, `AppBreakpoint.supportsNavigationRail`.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/operations/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL with the correct `section` query parameter
- [ ] Deep linking: constructing `OperationsWorkspaceQuery.fromUri(Uri.parse('/operations?section=open'))` resolves to `OperationsDeskSection.open`
- [ ] Deep linking: constructing `OperationsWorkspaceQuery.fromUri(Uri.parse('/operations?section=assets'))` resolves to `OperationsDeskSection.assets`
- [ ] Default section: no `section` query param defaults to `OperationsDeskSection.allRequests`
- [ ] Table data: the Assets tab displays `OperationsAsset` items, not `OperationsWorkItem` items
- [ ] Search: typing in the search bar filters table rows (existing behavior preserved)
- [ ] Filter dialog: filter button opens the filter UI and applies filters (existing behavior preserved)
- [ ] Primary action: "Create Request" button remains functional across all tabs
- [ ] No regressions: existing controller tests pass without modification
- [ ] `OperationsWorkspaceQuery.signature` produces consistent values for the same inputs

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 5 tabs matching the `OperationsDeskSection` enum
- [ ] Each tab has its own URL query parameter (`?section=open`, `?section=in-progress`, etc.) that supports deep linking
- [ ] The primary action button ("Create Request") remains in the toolbar and is functional across all tabs
- [ ] The request tabs use `AppListTable<OperationsWorkItem>` with server-side status filtering via the existing controller methods
- [ ] The Assets tab uses a separate `AppListTable<OperationsAsset>` with asset-specific columns
- [ ] Per-tab column visibility is persisted with storage keys like `operations_open`, `operations_inProgress`, etc.
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (handled by existing shared components)
- [ ] Domain-specific business logic (metadata parsing, status/priority/category mappings, report generation, all CRUD mutations) is preserved unchanged
- [ ] Summary notification badges remain in the toolbar as count indicators (but no longer duplicate tab-switching behavior)
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
