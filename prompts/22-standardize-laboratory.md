# Standardize Laboratory Screen

## Objective

Refactor the Laboratory workspace to match the standardized tab-and-table layout used by the Reception workspace. The current implementation uses `AppWorkspace` with a toolbar-based `AppWorkspaceSummaryNotification` chip pattern and a patients/orders view toggle. This refactor replaces that structure with the `ResponsivePage` → `AppTabStrip` → `AppListTable` pattern, converting the existing `LabQueueScope` scopes into routable tabs with URL-synced navigation, per-tab row counts, and a contextual primary action button — while fully preserving all domain-specific business logic (lab order creation/editing/deletion, result entry dialog, sample collection, processing, verification, critical flagging, reference range configurations, QC logging, catalog management, billing gate integration, and the patients/orders view toggle).

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Laboratory screen files

| File | Purpose |
|------|---------|
| `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` | Main page (~2770 lines). Uses `AsyncStateScaffold` → `AppWorkspace` with `appWorkspaceToolbarWithLabels`. Contains `_LabWorkspaceContent`, `_LabWorklistPanel`, worklist columns, `_LabConfigurationsDialog`, `_LabConfigurationTypeSelector`, `_ReverseWorkflowDialog`, `_QcDialog`, and all dialog-opening helper functions. |
| `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` | `LabResultEntryDialog` — the detail dialog for entering/verifying lab results. |
| `frontend/lib/features/lab/presentation/pages/lab_result_entry_status.dart` | Result entry status display helpers. |
| `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart` | `LabWorkspaceController` — Riverpod `AsyncNotifier` managing `LabWorkspaceState`. Handles search, scope filtering, view toggle, pagination, order CRUD, result entry, verification, reversal, catalog management, QC logging, realtime sync, and adaptive polling. |
| `frontend/lib/features/lab/domain/entities/lab_entities.dart` | Domain entities: `LabWorkspaceQuery`, `LabWorkbenchQuery`, `LabWorkbenchSummary`, `LabWorkspaceState`, `LabOrderSummary`, `LabOrderItem`, `LabOrderWorkflow`, `LabCatalogItem`, `LabCatalogScope`, `LabQueueScope`, `LabWorkbenchView`, etc. |
| `frontend/lib/features/lab/domain/repositories/lab_repository.dart` | Repository interface. |
| `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart` | Repository implementation + provider. |
| `frontend/lib/features/lab/data/dtos/lab_dtos.dart` | DTO serialization. |
| `frontend/lib/features/lab/presentation/lab_status_display.dart` | `labStatusBadge` and `labStatusLabel` — maps status strings to `AppWorkspaceStatus` with tone/icon. |
| `frontend/lib/features/lab/presentation/widgets/lab_workflow_progress_section.dart` | Workflow progress stepper for lab orders. |
| `frontend/test/features/lab/presentation/lab_workspace_controller_test.dart` | Controller tests. |
| `frontend/test/features/lab/data/lab_dtos_test.dart` | DTO tests. |
| `frontend/test/features/lab/domain/lab_catalog_scope_test.dart` | Catalog scope tests. |

### Current layout problems

- **No tab-based navigation**: Reception uses `AppTabStrip` with an enum (`ReceptionDeskSection`) for tab-routable sections; Laboratory uses `AppWorkspace` toolbar with `AppWorkspaceSummaryNotification` chips for scope filtering (Total, Collection, Processing, Results, Critical, Completed). Scopes are clickable summary notification chips, not tabs.
- **Different component hierarchy**: Reception uses `ResponsivePage` → `Column` → `Row[AppTabStrip + primary button]` → `AppListTable`; Laboratory uses `AppWorkspace` → toolbar + body with `_LabWorklistPanel` widget.
- **No URL routing for sections**: Reception updates the URL with `?section=appointments` on tab switch via `GoRouter.replace`. Laboratory only has `?encounterId=`, `?orderId=`, `?search=` query parameters — no section routing.
- **Primary action placement differs**: Reception places the primary button ("Register Patient") in a `Row` next to the `AppTabStrip`. Laboratory places "New Lab Order" inside the `appWorkspaceToolbarWithLabels` toolbar primary slot.
- **View toggle instead of integration**: The patients/orders view toggle (`LabWorkbenchView`) is a secondary button in the toolbar that switches between patient-grouped and individual-order views. This changes both the column set and the data grouping. It must be preserved but integrated into the new layout.
- **Summary notifications as filters**: The summary notification chips act as scope filters that call `controller.applyScope()`. These must become tab sections instead.

### What already works correctly (PRESERVE these)

- `AppListTable<LabOrderSummary>` with server-side pagination (`page` parameter), `AppListTableSearch`, `AppSearchBarFilterGroup` for advanced scope filters, `AppListTableColumnVisibilityController`, column choices, and mobile item builder.
- `LabWorkspaceController` with all its methods: `applySearch`, `applyScope`, `applyView`, `changePage`, `refresh`, `selectOrder`, `selectOrderById`, `createOrder`, `updateOrder`, `deleteOrder`, `reverseSelected`, `createQcLog`, `loadFacilityCatalogConfig`, `searchPlatformLabCatalogForOffering`, `updateLabTest`, `updateLabPanel`, `deleteLabTest`, `deleteLabPanel`.
- Result entry dialog (`LabResultEntryDialog`) with workflow progress, result entry, verification, reversal.
- Configurations dialog (`_LabConfigurationsDialog`) with catalog/equipment management, tenant/facility scope selectors, tests/panels toggle.
- QC logging dialog (`_QcDialog`).
- Reverse workflow dialog (`_ReverseWorkflowDialog`).
- Deep-link routing via `LabWorkspaceQuery.fromUri` for `encounterId`, `orderId`, `search`.
- Patients vs orders view toggle with separate column sets (`_patientViewWorklistColumns`, `_orderViewWorklistColumns`).
- All helper functions: `_openLabDetailDialog`, `_openCreateLabOrderDialog`, `_openAdditionalLabOrderDialog`, `_openLabOrderActionDialog`, `_openEditLabOrderDialog`, `_openDeleteLabOrderDialog`, `_openLabTestConfigurationDialog`, `_openLabPanelDialog`, `_openDeleteLabTestDialog`, `_openDeleteLabPanelDialog`, `_openQcDialog`, `_openLabConfigurationsDialog`.
- Status display: `labStatusBadge`, `labStatusLabel`, `_entryStatus`, `_resultStatus`, `_orderStatus`.
- Billing gate display: `_labBillingGateLabel`.
- Realtime sync and adaptive polling.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Extract |
|------|---------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | **Tab structure**: `ReceptionDeskSection` enum → `AppTabStrip` with `AppTabItem` for each section, `selectedId` synced to state, `onTabTapped` calling `setState` + `_updateUrlForSection`. **Layout**: `ResponsivePage` → `Column` → `Row[AppTabStrip (expanded) + primary button]` → `SizedBox` → `AppListTable`. **URL routing**: `_updateUrlForSection` builds `AppRoutes.reception.location(queryParameters:)` and calls `GoRouter.of(context).replace<void>(location)`. **Tab counts**: Label format `'${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})'`. **Primary button**: `AppAccessActionGate` wrapping `AppButton.primary` with `leadingIcon` and `onPressed`. **Search**: `AppListTableSearch` with `controller`, `matcher`, `hintText`. **Mobile**: `mobileItemBuilder` returning `AppPatientDetails`. **Deep-link**: `_applyDeepLink` method reading `ReceptionWorkspaceQuery`. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | **Query model**: `ReceptionWorkspaceQuery` with `section`, `search`, `patientId`, `flowId` fields, `fromUri` factory, `hasRouteTargeting`, `signature`. **Section enum**: `ReceptionDeskSection { appointments, queue, activeVisits, paymentGate }`. |
| `frontend/lib/features/reception/presentation/reception_access.dart` | Access requirements pattern. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` widget: `tabs` (list of `AppTabItem`), `selectedId`, `onTabTapped`. `AppTabItem`: `id`, `icon`, `label`. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` API — `items`, `page`, `columns`, `search`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `onRowSelected`, `emptyBuilder`, `mobileItemBuilder`, `isLoading`, `shrinkWrap`, `physics`. |
| `frontend/lib/shared/components/app_search_bar.dart` | `AppListTableSearch<T>`, `AppSearchBarFilterGroup`, `AppSearchBarFilterValue`. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` with `maxWidth`, `child`. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` — the current wrapper used by Laboratory. Understand its structure to know what to replace. |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels` — the toolbar builder currently used by Laboratory. |

## Target Architecture

### Tab Configuration

The existing `LabQueueScope` enum values (`all`, `collection`, `processing`, `results`, `critical`, `completed`, `cancelled`) and `LabWorkbenchSummary` counts map naturally to tabs. Cancelled orders are infrequent and can remain accessible via the advanced filter only.

Create a new enum `LabDeskSection` in `lab_entities.dart`:

```dart
enum LabDeskSection {
  worklist,
  collection,
  processing,
  verification,
  critical,
  completed,
}
```

| Tab Name | Route Value (`?section=`) | Maps to `LabQueueScope` | Description | Count Source | Icon | Primary Action Button |
|----------|--------------------------|------------------------|-------------|--------------|------|-----------------------|
| Worklist | `worklist` | `.all` | All active orders (default tab) | `summary.totalForView(view)` | `Icons.assignment_outlined` | "New Lab Order" → `_openCreateLabOrderDialog` |
| Collection | `collection` | `.collection` | Awaiting sample collection | `summary.collectionForView(view)` | `Icons.biotech_outlined` | "New Lab Order" → `_openCreateLabOrderDialog` |
| Processing | `processing` | `.processing` | Samples being processed | `summary.processingForView(view)` | `Icons.sync_outlined` | "New Lab Order" → `_openCreateLabOrderDialog` |
| Verification | `verification` | `.results` | Results pending verification | `summary.resultsForView(view)` | `Icons.pending_actions_outlined` | "New Lab Order" → `_openCreateLabOrderDialog` |
| Critical | `critical` | `.critical` | Critical results requiring attention | `summary.criticalForView(view)` | `Icons.priority_high_outlined` | "New Lab Order" → `_openCreateLabOrderDialog` |
| Completed | `completed` | `.completed` | Verified and completed orders | `summary.completedForView(view)` | `Icons.verified_outlined` | "New Lab Order" → `_openCreateLabOrderDialog` |

### Routing

**Router file**: `frontend/lib/app/router/app_router.dart`

The existing route definition stays the same — a single `GoRoute` at `/lab` with query parameters. Add `section` to the recognized query parameters in `LabWorkspaceQuery.fromUri`.

**Route definition** (no changes needed, already correct):
```dart
GoRoute(
  path: AppRoutes.lab.path,
  name: AppRoutes.lab.name,
  builder: (_, GoRouterState state) {
    return LabWorkspacePage(
      initialQuery: LabWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

**URL sync**: On tab change, call `GoRouter.of(context).replace<void>(location)` where `location` is built from `AppRoutes.lab.location(queryParameters: {'section': sectionValue})`. Follow the exact pattern from `_updateUrlForSection` in `reception_workspace_page.dart`.

### Page Layout

The target widget tree for `_LabWorkspaceContent.build()`:

```
ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
└── SizedBox(width: double.infinity)
    └── Column(crossAxisAlignment: stretch)
        ├── Row
        │   ├── Expanded
        │   │   └── AppTabStrip(
        │   │         tabs: [AppTabItem for each LabDeskSection],
        │   │         selectedId: _section.name,
        │   │         onTabTapped: _onTabTapped,
        │   │       )
        │   ├── SizedBox(width: theme.spacing.sm)
        │   ├── AppWorkspaceViewToggle(  // patients/orders view toggle
        │   │     label: toggle label,
        │   │     icon: Icons.swap_horiz_outlined,
        │   │     onPressed: _toggleView,
        │   │   )
        │   ├── SizedBox(width: theme.spacing.sm)
        │   ├── if (canMutate) AppButton.secondary(  // Reference Ranges
        │   │     label: l10n.labReferenceRangesAction,
        │   │     leadingIcon: Icons.tune_outlined,
        │   │     onPressed: _openLabConfigurationsDialog,
        │   │   )
        │   ├── SizedBox(width: theme.spacing.sm)
        │   └── if (canMutate) AppButton.primary(  // New Lab Order
        │         label: l10n.labCreateAction,
        │         leadingIcon: Icons.add_circle_outline,
        │         onPressed: _openCreateLabOrderDialog,
        │       )
        ├── SizedBox(height: theme.spacing.md)
        └── AppListTable<LabOrderSummary>(...) // existing table config
```

### Data & State Management

**Controller** (`LabWorkspaceController`): No changes needed to the controller itself. The `applyScope(LabQueueScope)` method already supports server-side filtering by scope. Tab changes will simply call `controller.applyScope(scope)` where `scope` is derived from the selected `LabDeskSection`.

**Mapping** from `LabDeskSection` to `LabQueueScope`:
```dart
LabQueueScope _scopeForSection(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.worklist => LabQueueScope.all,
    LabDeskSection.collection => LabQueueScope.collection,
    LabDeskSection.processing => LabQueueScope.processing,
    LabDeskSection.verification => LabQueueScope.results,
    LabDeskSection.critical => LabQueueScope.critical,
    LabDeskSection.completed => LabQueueScope.completed,
  };
}
```

**Reverse mapping** (for deep-link section resolution):
```dart
LabDeskSection? _sectionFromQuery(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'worklist':
    case 'all':
      return LabDeskSection.worklist;
    case 'collection':
    case 'sample':
      return LabDeskSection.collection;
    case 'processing':
    case 'in-process':
      return LabDeskSection.processing;
    case 'verification':
    case 'results':
    case 'pending':
      return LabDeskSection.verification;
    case 'critical':
      return LabDeskSection.critical;
    case 'completed':
    case 'done':
      return LabDeskSection.completed;
    default:
      return null;
  }
}
```

**State**: The `_section` field lives in the `_LabWorkspaceContentState` widget state (same as Reception's `_section`), not in the controller. This is local UI state that drives both the tab strip selection and the `applyScope` call.

## Implementation Steps

### 1. Add `LabDeskSection` enum — File: `frontend/lib/features/lab/domain/entities/lab_entities.dart`

- Add the `LabDeskSection` enum after the existing `LabQueueScope` enum (around line 13):

```dart
enum LabDeskSection {
  worklist,
  collection,
  processing,
  verification,
  critical,
  completed,
}
```

### 2. Extend `LabWorkspaceQuery` — File: `frontend/lib/features/lab/domain/entities/lab_entities.dart`

- Add a `section` field to `LabWorkspaceQuery` (currently at line 1284):

```dart
@immutable
final class LabWorkspaceQuery {
  const LabWorkspaceQuery({
    this.section = '',
    this.encounterId = '',
    this.orderId = '',
    this.search = '',
  });

  factory LabWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return LabWorkspaceQuery(
      section: pick(<String>['section', 'panel', 'filter', 'scope']),
      encounterId: pick(<String>['encounterId', 'encounter_id', 'encounter']),
      orderId: pick(<String>['orderId', 'order_id', 'order']),
      search: pick(<String>['search', 'q']),
    );
  }

  final String section;
  final String encounterId;
  final String orderId;
  final String search;

  bool get hasRouteTargeting =>
      section.isNotEmpty ||
      encounterId.isNotEmpty ||
      orderId.isNotEmpty ||
      search.isNotEmpty;

  String get signature => '$section|$encounterId|$orderId|$search';
}
```

### 3. Refactor `_LabWorkspaceContent` — File: `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`

This is the main refactoring step. Replace the `AppWorkspace` wrapper with the `ResponsivePage` → `AppTabStrip` → `AppListTable` pattern.

#### 3a. Add `LabDeskSection` state field

Add to `_LabWorkspaceContentState`:
```dart
late LabDeskSection _section;
```

Initialize in `initState`:
```dart
_section = LabDeskSection.worklist;
```

#### 3b. Add section helper methods

Add these methods to `_LabWorkspaceContentState`:

```dart
LabQueueScope _scopeForSection(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.worklist => LabQueueScope.all,
    LabDeskSection.collection => LabQueueScope.collection,
    LabDeskSection.processing => LabQueueScope.processing,
    LabDeskSection.verification => LabQueueScope.results,
    LabDeskSection.critical => LabQueueScope.critical,
    LabDeskSection.completed => LabQueueScope.completed,
  };
}

LabDeskSection _sectionForScope(LabQueueScope scope) {
  return switch (scope) {
    LabQueueScope.all => LabDeskSection.worklist,
    LabQueueScope.collection => LabDeskSection.collection,
    LabQueueScope.processing => LabDeskSection.processing,
    LabQueueScope.results => LabDeskSection.verification,
    LabQueueScope.critical => LabDeskSection.critical,
    LabQueueScope.completed => LabDeskSection.completed,
    LabQueueScope.cancelled => LabDeskSection.worklist,
  };
}

LabDeskSection? _sectionFromQuery(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'worklist':
    case 'all':
      return LabDeskSection.worklist;
    case 'collection':
    case 'sample':
      return LabDeskSection.collection;
    case 'processing':
    case 'in-process':
      return LabDeskSection.processing;
    case 'verification':
    case 'results':
    case 'pending':
      return LabDeskSection.verification;
    case 'critical':
      return LabDeskSection.critical;
    case 'completed':
    case 'done':
      return LabDeskSection.completed;
    default:
      return null;
  }
}

static String _sectionToQueryValue(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.worklist => 'worklist',
    LabDeskSection.collection => 'collection',
    LabDeskSection.processing => 'processing',
    LabDeskSection.verification => 'verification',
    LabDeskSection.critical => 'critical',
    LabDeskSection.completed => 'completed',
  };
}

void _updateUrlForSection(LabDeskSection section) {
  if (!mounted) return;
  final String tab = _sectionToQueryValue(section);
  final String location = AppRoutes.lab.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}

String _sectionLabel(AppLocalizations l10n, LabDeskSection section) {
  return switch (section) {
    LabDeskSection.worklist => l10n.labScopeAll,
    LabDeskSection.collection => l10n.labScopeCollection,
    LabDeskSection.processing => l10n.labScopeProcessing,
    LabDeskSection.verification => l10n.labScopeResults,
    LabDeskSection.critical => l10n.labScopeCritical,
    LabDeskSection.completed => l10n.labScopeCompleted,
  };
}

static IconData _sectionIcon(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.worklist => Icons.assignment_outlined,
    LabDeskSection.collection => Icons.biotech_outlined,
    LabDeskSection.processing => Icons.sync_outlined,
    LabDeskSection.verification => Icons.pending_actions_outlined,
    LabDeskSection.critical => Icons.priority_high_outlined,
    LabDeskSection.completed => Icons.verified_outlined,
  };
}

int _sectionCount(LabWorkspaceState state, LabDeskSection section) {
  final LabWorkbenchView view = state.query.view;
  return switch (section) {
    LabDeskSection.worklist => state.summary.totalForView(view),
    LabDeskSection.collection => state.summary.collectionForView(view),
    LabDeskSection.processing => state.summary.processingForView(view),
    LabDeskSection.verification => state.summary.resultsForView(view),
    LabDeskSection.critical => state.summary.criticalForView(view),
    LabDeskSection.completed => state.summary.completedForView(view),
  };
}
```

#### 3c. Update `_applyRouteQuery` / `_applyScopeFromRoute`

Remove `_applyScopeFromRoute` and integrate section handling into `_applyRouteQuery`:

```dart
Future<void> _applyRouteQuery(LabWorkspaceQuery query) async {
  // Apply section from deep link
  final LabDeskSection? section = _sectionFromQuery(query.section);
  if (section != null && section != _section) {
    setState(() => _section = section);
    unawaited(
      ref.read(labWorkspaceControllerProvider.notifier).applyScope(
        _scopeForSection(section),
      ),
    );
  }

  if (query.search.isNotEmpty) {
    _searchController.text = query.search;
    ref.read(labWorkspaceControllerProvider.notifier).applySearch(
      query.search,
    );
  }
  final LabOrderSummary? order = _findOrderByQuery(query);
  if (order != null) {
    await ref
        .read(labWorkspaceControllerProvider.notifier)
        .selectOrder(order);
  }
}
```

#### 3d. Replace `build()` method of `_LabWorkspaceContentState`

Replace the entire `build()` method. Remove the `AppWorkspace` wrapper and replace with the `ResponsivePage` → `AppTabStrip` → `AppListTable` pattern:

```dart
@override
Widget build(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final LabWorkspaceState state = widget.state;
  final LabWorkspaceController controller = ref.read(
    labWorkspaceControllerProvider.notifier,
  );
  final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
  final bool canMutate = _mutationRequirement.isAllowed(policy);

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
                    for (final LabDeskSection section
                        in LabDeskSection.values)
                      AppTabItem(
                        id: section.name,
                        icon: _sectionIcon(section),
                        label:
                            '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                      ),
                  ],
                  selectedId: _section.name,
                  onTabTapped: (String tabId) {
                    for (final LabDeskSection section
                        in LabDeskSection.values) {
                      if (section.name == tabId) {
                        setState(() => _section = section);
                        _updateUrlForSection(section);
                        unawaited(
                          controller.applyScope(
                            _scopeForSection(section),
                          ),
                        );
                        break;
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              AppWorkspaceViewToggle(
                label: state.query.view == LabWorkbenchView.patients
                    ? l10n.labOrdersViewAction
                    : l10n.labPatientsViewAction,
                icon: Icons.swap_horiz_outlined,
                semanticLabel: state.query.view == LabWorkbenchView.patients
                    ? l10n.labOrdersViewAction
                    : l10n.labPatientsViewAction,
                tooltip: state.query.view == LabWorkbenchView.patients
                    ? l10n.labOrdersViewAction
                    : l10n.labPatientsViewAction,
                onPressed: () => controller.applyView(
                  state.query.view == LabWorkbenchView.patients
                      ? LabWorkbenchView.orders
                      : LabWorkbenchView.patients,
                ),
              ),
              if (canMutate) ...<Widget>[
                SizedBox(width: theme.spacing.sm),
                AppButton.secondary(
                  label: l10n.labReferenceRangesAction,
                  leadingIcon: Icons.tune_outlined,
                  semanticLabel: l10n.labReferenceRangesAction,
                  tooltip: l10n.labReferenceRangesAction,
                  onPressed: () =>
                      _openLabConfigurationsDialog(context, state),
                ),
                SizedBox(width: theme.spacing.sm),
                AppButton.primary(
                  label: l10n.labCreateAction,
                  leadingIcon: Icons.add_circle_outline,
                  semanticLabel: l10n.labCreateAction,
                  tooltip: l10n.labCreateAction,
                  enabled: !state.isSaving,
                  onPressed: () =>
                      _openCreateLabOrderDialog(context, state),
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacing.md),
          _LabWorklistPanel(
            state: state,
            canMutate: canMutate,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
            onSearchChanged: _scheduleWorklistSearch,
            onSearchSubmitted: _submitWorklistSearch,
            onSearchCleared: _clearWorklistSearch,
            sectionName: _section.name,
          ),
        ],
      ),
    ),
  );
}
```

#### 3e. Update `_LabWorklistPanel`

Add a `sectionName` parameter to `_LabWorklistPanel` and use it for `columnVisibilityStorageKey` and `columnWidthStorageKey`:

```dart
class _LabWorklistPanel extends ConsumerWidget {
  const _LabWorklistPanel({
    required this.state,
    required this.canMutate,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
    required this.sectionName,
  });

  // ... existing fields ...
  final String sectionName;
```

In `_LabWorklistPanel.build()`, add storage keys to `AppListTable`:
```dart
AppListTable<LabOrderSummary>(
  page: state.worklist,
  columnVisibilityController: columnVisibilityController,
  columnVisibilityStorageKey: 'lab_$sectionName',
  columnWidthStorageKey: 'lab_cw_$sectionName',
  // ... rest of existing config ...
```

Also **remove** the existing `_labScopeFilterKey`-based `AppSearchBarFilterGroup` from the `search:` parameter of `AppListTable`, since scope filtering is now handled by tabs. The search should still support text search but the scope filter group becomes unnecessary. Keep `showAdvancedFilterButton: false` or remove the scope filter entirely.

#### 3f. Update imports

In `lab_workspace_page.dart`, ensure these imports are present:
```dart
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart'; // if not via barrel
import 'package:hosspi_hms/shared/layout/responsive_page.dart'; // if not via barrel
```

Remove any imports that become unused after removing `AppWorkspace` and `appWorkspaceToolbarWithLabels` usage.

#### 3g. Remove `_applyScopeFromRoute` method

Delete the `_applyScopeFromRoute` method entirely from `_LabWorkspaceContentState`. Its logic is now handled by `_applyRouteQuery` and tab-based section routing.

#### 3h. Remove scope filter from search bar

In the `_LabWorklistPanel.build()` method, remove the `AppSearchBarFilterGroup` for `_labScopeFilterKey` and the `filterValue`, `hasActiveFilters`, and `onFilterChanged` parameters from the `AppListTableSearch` constructor. The scope is now controlled by tabs.

Remove these top-level constants/functions that are no longer needed:
- `_labScopeFilterKey`
- `_labFilterValue`
- `_labScopeFromFilter`
- `_labScopeFilterChoices`
- `_labScopeIcon`
- `_scopeOptions`

#### 3i. Remove `_summaryNotification` helper

Delete the `_summaryNotification` method from `_LabWorkspaceContentState` — summary notification chips are replaced by tab labels with counts.

### 4. Update `initState` — File: `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`

In `_LabWorkspaceContentState.initState()`:
- Remove the `WidgetsBinding.instance.addPostFrameCallback((_) => _applyScopeFromRoute());` call.
- Add initialization for `_section`:

```dart
@override
void initState() {
  super.initState();
  _section = LabDeskSection.worklist;
  _searchController = TextEditingController(text: widget.state.query.search);
  _tableColumnController =
      AppListTableColumnVisibilityController<LabOrderSummary>();
  _scheduleRouteQuery(widget.initialQuery);
}
```

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (or via `components.dart` barrel) | Tab navigation with `AppTabItem` list, `selectedId`, and `onTabTapped`. |
| `AppTabItem` | Same as above | Tab definition with `id`, `icon`, `label`. |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` (or via `layout.dart` barrel) | Top-level page wrapper with `maxWidth: PageMaxWidth.dataHeavy`. |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` | Already used — add `columnVisibilityStorageKey` and `columnWidthStorageKey`. |
| `AppListTableSearch<T>` | Same as above | Already used — simplify by removing scope filter group. |
| `AppButton` | `package:hosspi_hms/shared/components/app_button.dart` | Already used for primary/secondary actions. |
| `AppWorkspaceViewToggle` | `package:hosspi_hms/shared/layout/app_workspace_view_toggle.dart` | Already used for patients/orders toggle — moves to the tab bar row. |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Already used in table cells for status display. |
| `GoRouter` | `package:go_router/go_router.dart` | Already imported — used for URL sync via `GoRouter.of(context).replace<void>()`. |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | Already defined — use `AppRoutes.lab.location(queryParameters:)` for URL generation. |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/lab/domain/entities/lab_entities.dart` | Add `LabDeskSection` enum. Add `section` field to `LabWorkspaceQuery` with `fromUri` and `signature` updates. |
| `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` | Replace `AppWorkspace` with `ResponsivePage` → `AppTabStrip` → `AppListTable`. Add `_section` state field and all section helpers. Remove `_applyScopeFromRoute`, `_summaryNotification`, scope filter constants/functions. Add `sectionName` to `_LabWorklistPanel`. Add `columnVisibilityStorageKey`/`columnWidthStorageKey` to `AppListTable`. Update imports. |

## Files to Delete (if any)

No files to delete. All changes are in-place modifications.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove `_summaryNotification` helper method from `_LabWorkspaceContentState`.
- [ ] Remove `_labScopeFilterKey` constant.
- [ ] Remove `_labFilterValue` function.
- [ ] Remove `_labScopeFromFilter` function.
- [ ] Remove `_labScopeFilterChoices` function.
- [ ] Remove `_labScopeIcon` function.
- [ ] Remove `_scopeOptions` function.
- [ ] Remove `_applyScopeFromRoute` method from `_LabWorkspaceContentState`.
- [ ] Remove the `appWorkspaceToolbarWithLabels` import if it becomes unused.
- [ ] Remove the `AppWorkspaceSummaryNotification` import if it becomes unused.
- [ ] Remove the `AppWorkspaceViewToggle` import from the toolbar module if it was imported only for toolbar usage (it may still be needed if imported from the layout barrel).
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the Flutter frontend UI layer. The `LabWorkspaceController` API calls, repository methods, and backend endpoints remain identical. The server-side `applyScope` filtering is already implemented and will continue to work with tab-driven scope selection.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full tab strip visible with all 6 tabs, view toggle, configurations button, and primary action button in a single row. `AppListTable` renders as a full data table with sortable columns, column resize handles, and column visibility settings.
- **Tablet (600–1023px):** `AppTabStrip` wraps naturally (it uses `Wrap` internally). Compact table layout with condensed column widths (`_defaultCompactColumnWidth`). Action buttons may wrap to a second line.
- **Mobile (<600px):** `AppListTable` automatically switches to `mobileItemBuilder` rendering (card-based rows with `AppListItemRow`). Tab strip wraps into multiple lines. The view toggle and action buttons stack vertically or collapse into overflow.

The existing `AppListTable` already handles responsive breakpoints via `AppBreakpoints.fromConstraints` — using `AppBreakpoint.xs`/`AppBreakpoint.sm` for list mode and `AppBreakpoint.md` for compact table mode. No additional breakpoint utilities needed.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to lab
flutter test test/features/lab/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls `controller.applyScope()` with the correct `LabQueueScope` and updates the URL via `GoRouter.replace`
- [ ] Deep linking: navigating directly to `/lab?section=collection` sets the `_section` to `LabDeskSection.collection` and calls `applyScope(LabQueueScope.collection)`
- [ ] Tab counts: each tab label displays the correct count from `LabWorkbenchSummary` for the current view
- [ ] View toggle: patients/orders toggle still works and updates column set and tab counts
- [ ] Table data: each tab displays the correct server-side filtered dataset
- [ ] Search: typing in the search bar filters table rows (unchanged behavior)
- [ ] Primary action: "New Lab Order" button remains functional across all tabs
- [ ] Column visibility: `columnVisibilityStorageKey` uses `lab_${sectionName}` prefix for per-tab persistence
- [ ] Responsive layout: widget tests verify layout at each breakpoint (mobile list vs desktop table)
- [ ] No regressions: existing result entry dialog, configurations dialog, QC dialog, and all order CRUD operations still work
- [ ] Existing `LabWorkspaceQuery` deep-link parameters (`encounterId`, `orderId`, `search`) still function correctly alongside the new `section` parameter

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable tabs matching the Reception workspace pattern — `ResponsivePage` → `AppTabStrip` → `AppListTable`
- [ ] Each tab has its own URL that supports deep linking via `?section=` query parameter
- [ ] Tab labels include per-section counts that update based on the current view (patients/orders)
- [ ] The primary action button ("New Lab Order") is positioned in the tab bar row and remains functional
- [ ] The patients/orders view toggle is preserved and positioned next to the tab strip
- [ ] The configurations button ("Reference Ranges") is preserved and accessible
- [ ] The page body uses `AppListTable` with integrated search, column visibility (`columnVisibilityStorageKey`/`columnWidthStorageKey`), and per-tab storage
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old toolbar-based summary notification code is removed — no stale scope filter functions, no `AppWorkspaceSummaryNotification` usage, no `appWorkspaceToolbarWithLabels` usage
- [ ] All domain-specific business logic is preserved: order CRUD, result entry, verification, reversal, catalog management, QC logging, billing gate
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
