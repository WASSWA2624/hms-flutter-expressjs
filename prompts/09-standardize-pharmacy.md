# Standardize Pharmacy Screen

## Objective

Refactor the Pharmacy workspace to adopt the standardized tab-and-table layout used by the Reception workspace. The pharmacy currently uses summary-notification chips as quick-filter buttons in the toolbar header — these will be reorganised into an `AppTabStrip` with routable tab sections, each showing a filtered view of the order queue via `AppListTable`. The catalog dialog remains unchanged. The agent will introduce routable tabs with URL sync, per-tab column sets, and per-tab primary actions while preserving every existing domain behaviour (server-side pagination, advanced filters, order detail dialog, billing, dispensing, attestation, catalog dialog, real-time sync, and inventory alerts).

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### File inventory

| File | Purpose |
|------|---------|
| `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (~3160 lines) | Main page: `PharmacyWorkspacePage` (ConsumerWidget) → `_PharmacyWorkspaceContent` (ConsumerStatefulWidget). Order queue list, detail dialog, filter helpers, column definitions, mobile tile, billing/pricing dialogs, print helpers integration |
| `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` (~1565 lines) | `PharmacyWorkspaceController` (AsyncNotifier) — data loading, search, filter, pagination, order selection, catalog, inventory, storage, dispense/attest/cancel/return mutations, real-time sync, adaptive polling |
| `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` (~1734 lines) | All domain entities, enums (`PharmacyOrderFilter`, `PharmacyCatalogTab`, `PharmacyInventoryFilter`), query VOs (`PharmacyWorkbenchQuery`, `PharmacyWorkspaceQuery`, `PharmacyWorkspaceState`), order/item/workflow models |
| `frontend/lib/features/pharmacy/domain/repositories/pharmacy_repository.dart` | Abstract `PharmacyRepository` (23 methods) |
| `frontend/lib/features/pharmacy/data/dtos/pharmacy_dtos.dart` | JSON → entity DTO converters |
| `frontend/lib/features/pharmacy/data/repositories/pharmacy_repository_impl.dart` | `PharmacyRepositoryImpl` with all API calls |
| `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart` | `openPharmacyCatalogDialog()` → `_PharmacyCatalogDialog` |
| `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` | `PharmacyCatalogPanel` — tabbed catalog content (Drugs, Formulary, Inventory, Storage) |
| `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_tabs.dart` | `PharmacyCatalogIconTabBar`, tab descriptors |
| `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` | Storage rooms/shelves CRUD |
| `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart` | Drug create/edit dialog |
| `frontend/lib/features/pharmacy/presentation/pharmacy_drug_catalog_options.dart` | Drug form/unit/expiry option catalogs |
| `frontend/lib/features/pharmacy/presentation/pharmacy_billing_helpers.dart` | Billing line-item builders |
| `frontend/lib/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart` | Price source resolution helpers |
| `frontend/lib/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart` | Print/PDF helpers |

### Current layout/structure

- `PharmacyWorkspacePage` → `AsyncStateScaffold<PharmacyWorkspaceState>` → `_PharmacyWorkspaceContent`
- `_PharmacyWorkspaceContent.build()` returns `AppWorkspace(title, leadingIcon, toolbar, body)`
- **Toolbar:** `appWorkspaceToolbarWithLabels(l10n, summaryNotifications: [...], primary: AppButton.primary("Dispense"), overflowSections: [catalog action, notifications], onRefresh, isRefreshing)`
- Summary notifications act as quick-filter buttons (All, Ready, Partial, Completed, Discharge, Outpatient, Ward, Pending Payment, Attestation, Low Stock, Almost Out, Expiring Soon) — **not tabs**
- **Body:** `_PharmacyQueuePanel` → `AppListTable<PharmacyOrder>(page: ..., columns: ..., columnChoices: ..., search: AppListTableSearch(...), mobileItemBuilder: ...)`
- Server-side pagination via `page` property and `onPageChanged: controller.changePage`
- Advanced filter dialog with 6 filter groups: status, location, payment, priority, stock, urgent
- Order detail opens in `AppDialog` via `_openPharmacyDetailDialog()`
- Catalog opens in `AppDialog` via `openPharmacyCatalogDialog()`
- Deep linking: `?section=inventory|stock` opens catalog dialog; `?search=`, `?encounterId=`, `?orderId=` target orders

### Problems / inconsistencies found

1. **No `AppTabStrip` tabs** — the page uses summary notification chips in the toolbar header as quick-filter buttons, unlike the Reception reference that uses `AppTabStrip` with routable sections.
2. **No routable tab sections** — there is no `?section=queue|ready|partial|completed|...` URL parameter that selects a tab. The only deep-link section parameter (`?section=inventory`) opens the catalog dialog.
3. **No per-tab column set** — all filters share a single column set with `_defaultPharmacyWorklistColumns()` and `_optionalPharmacyWorklistColumns()`. The reception reference changes columns per section via `_columnsForSection(l10n)`.
4. **No per-tab storage keys** — `columnVisibilityStorageKey` and `columnWidthStorageKey` are not set, so column visibility is not persisted per tab section. Reception uses `'reception_${_section.name}'`.
5. **Summary notifications duplicate what tabs should provide** — the toolbar has 11+ summary notification items (All, Ready, Partial, Completed, Outpatient, Ward, etc.) that serve as filter buttons. With tabs, the primary workflow sections move to the tab strip and the remaining alerts (Low Stock, Expiring Soon, etc.) stay as toolbar notifications.
6. **Primary action does not change per tab** — the "Dispense" button is static. In a tab-based layout, the primary action could be contextual (e.g., "Dispense" on Queue/Ready tab, "View Catalog" on All tab).

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key patterns to extract |
|------|------------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `AppTabStrip` with `ReceptionDeskSection` enum; per-tab column sets via `_columnsForSection()`; `_updateUrlForSection()` → `GoRouter.replace` with `?section=`; `AppAccessActionGate` → `AppButton.primary` in same `Row` as tab strip; per-tab `columnVisibilityStorageKey`/`columnWidthStorageKey`; `_mobileItemBuilder` for `< 600px`; `_searchMatcher` for client-side search |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` enum; `ReceptionWorkspaceQuery` VO with `section`, `search`, `flowId` fields and `fromUri()` factory |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` constructor: `tabs` (`List<AppTabItem>`), `selectedId`, `onTabTapped`; `AppTabItem`: `id`, `icon`, `label` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor: `items`/`page`, `columns`, `columnChoices`, `search`, `mobileItemBuilder`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `onRowSelected`, `onPageChanged`, `emptyBuilder`, `isLoading`, `rowColorBuilder` |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` scaffold: `title`, `toolbar`, `body`, `primaryAction` |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels()` factory; `AppWorkspaceToolbarConfig` with `primary`, `secondary`, `overflowSections`, `summaryNotifications`, `onRefresh`, `isRefreshing` |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage`, `PageMaxWidth.dataHeavy` |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints`, `AppBreakpoint` enum; mobile = xs/sm (< 600px) |

## Target Architecture

### Tab Configuration

The existing `PharmacyOrderFilter` quick-filter chips will be reorganised into tab sections. The tabs represent the pharmacist's primary workflow stages:

| Tab Name | Route Query Value | Description | Primary Action Button | Icon |
|----------|------------------|-------------|----------------------|------|
| Queue | `queue` | Active orders ready to dispense (ORDERED status) — the default landing tab | "Dispense" → `controller.applyFilter(PharmacyOrderFilter.ready)` | `Icons.medication_liquid_outlined` |
| In Progress | `in-progress` | Partially dispensed orders requiring follow-up | "Continue Dispense" → `controller.applyFilter(PharmacyOrderFilter.partial)` | `Icons.pending_actions_outlined` |
| Pending Payment | `pending-payment` | Orders blocked by billing clearance | "Record Payment" → no-op (row-level action) | `Icons.payments_outlined` |
| Completed | `completed` | Fully dispensed orders | "View Catalog" → `openPharmacyCatalogDialog(context, ref)` | `Icons.done_all_outlined` |
| All Orders | `all` | All orders regardless of status | "New Drug" → `openPharmacyCatalogDialog(context, ref, initialTab: PharmacyCatalogTab.drugs)` | `Icons.inventory_2_outlined` |

### New Enum

Add a `PharmacyDeskSection` enum to `pharmacy_entities.dart`:

```dart
enum PharmacyDeskSection {
  queue,
  inProgress,
  pendingPayment,
  completed,
  allOrders,
}
```

### Routing

The existing route definition in `frontend/lib/app/router/app_router.dart` (line 269–277) stays the same — no changes to the `GoRoute`. Tab selection is handled via query parameter `?section=queue|in-progress|pending-payment|completed|all` using `GoRouter.replace()`, following the same pattern as Reception.

Update `PharmacyWorkspaceQuery` in `pharmacy_entities.dart` to parse the `section` query parameter from the URI and expose it alongside existing `search`, `encounterId`, `orderId` fields.

### Page Layout

The page will combine `AppWorkspace` (for header/toolbar) with the tab strip in the body area, following a hybrid of the AppWorkspace and Reception patterns:

```
PharmacyWorkspacePage (ConsumerWidget)
└── AsyncStateScaffold<PharmacyWorkspaceState>
    └── _PharmacyWorkspaceContent (ConsumerStatefulWidget)
        └── AppWorkspace(title, leadingIcon, toolbar, body)
            ├── [toolbar] AppWorkspaceToolbarConfig
            │   ├── primary: contextual AppButton.primary (changes per tab)
            │   ├── overflowSections: [catalog action, inventory alerts]
            │   ├── summaryNotifications: [inventory alerts only — Low Stock, Almost Out, Expiring Soon]
            │   └── onRefresh / isRefreshing
            └── [body] Column
                ├── Row
                │   ├── Expanded → AppTabStrip (5 tabs with counts)
                │   └── AppAccessActionGate → AppButton.primary (contextual per tab)
                ├── SizedBox(height: theme.spacing.md)
                └── AppListTable<PharmacyOrder>
                    ├── page: server-side paginated orders (filtered per tab)
                    ├── columns: per-tab column set
                    ├── columnVisibilityStorageKey: 'pharmacy_${_section.name}'
                    ├── columnWidthStorageKey: 'pharmacy_cw_${_section.name}'
                    ├── search: AppListTableSearch with advanced filters
                    ├── mobileItemBuilder: _PharmacyOrderListTile
                    └── emptyBuilder: AppWorkspaceStatePanel.state(empty)
```

### Data & State Management

- **Controller:** Keep `pharmacyWorkspaceControllerProvider` (`PharmacyWorkspaceController`) unchanged. It already supports `applyFilter(PharmacyOrderFilter)` which maps directly to tab-based server-side filtering.
- **Tab → Filter mapping:** Each tab maps to a `PharmacyOrderFilter` value when selected:
  - `queue` → `PharmacyOrderFilter.ready`
  - `inProgress` → `PharmacyOrderFilter.partial`
  - `pendingPayment` → `PharmacyOrderFilter.pendingPayment`
  - `completed` → `PharmacyOrderFilter.completed`
  - `allOrders` → `PharmacyOrderFilter.all`
- **Tab switching** calls `controller.applyFilter(...)` to trigger a server-side re-fetch. The current advanced filter behavior is preserved within each tab.
- **Tab counts** are read from `state.workbench.summary`: `orderedQueue`, `partiallyDispensedQueue`, `pendingPaymentQueue`, `dispensedOrders`, `totalOrders`.

## Implementation Steps

### 1. Add `PharmacyDeskSection` enum — File: `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`

After the existing `PharmacyOrderFilter` enum (line 16), add:

```dart
/// Desk worklist sections for the pharmacy workspace tab strip.
enum PharmacyDeskSection {
  queue,
  inProgress,
  pendingPayment,
  completed,
  allOrders,
}
```

### 2. Update `PharmacyWorkspaceQuery` — File: `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`

Find the existing `PharmacyWorkspaceQuery` class. Add a `section` field:

```dart
final String section;
```

Update the constructor to accept `this.section = ''` and update `fromUri()` to parse `uri.queryParameters['section'] ?? ''`. Update the `signature` getter to include `section`. Update `hasRouteTargeting` if needed.

### 3. Refactor `_PharmacyWorkspaceContent` — File: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`

This is the main refactoring step. Make the following changes:

#### 3a. Add section state

Add to `_PharmacyWorkspaceContentState`:

```dart
late PharmacyDeskSection _section;
```

Initialise in `initState()`:

```dart
_section = _sectionFromQuery(widget.initialQuery?.section ?? '') ??
    PharmacyDeskSection.queue;
```

#### 3b. Add tab-to-section mapping helpers

Add these private methods to `_PharmacyWorkspaceContentState`:

```dart
void _updateUrlForSection(PharmacyDeskSection section) {
  if (!mounted) return;
  final String tab = _sectionToQueryValue(section);
  final String location = AppRoutes.pharmacy.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}

static String _sectionToQueryValue(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => 'queue',
    PharmacyDeskSection.inProgress => 'in-progress',
    PharmacyDeskSection.pendingPayment => 'pending-payment',
    PharmacyDeskSection.completed => 'completed',
    PharmacyDeskSection.allOrders => 'all',
  };
}

PharmacyDeskSection? _sectionFromQuery(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'queue':
    case 'ready':
    case 'dispense':
      return PharmacyDeskSection.queue;
    case 'in-progress':
    case 'partial':
    case 'in_progress':
      return PharmacyDeskSection.inProgress;
    case 'pending-payment':
    case 'payment':
    case 'pending_payment':
      return PharmacyDeskSection.pendingPayment;
    case 'completed':
    case 'dispensed':
      return PharmacyDeskSection.completed;
    case 'all':
    case 'all-orders':
      return PharmacyDeskSection.allOrders;
    default:
      return null;
  }
}

PharmacyOrderFilter _filterForSection(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => PharmacyOrderFilter.ready,
    PharmacyDeskSection.inProgress => PharmacyOrderFilter.partial,
    PharmacyDeskSection.pendingPayment => PharmacyOrderFilter.pendingPayment,
    PharmacyDeskSection.completed => PharmacyOrderFilter.completed,
    PharmacyDeskSection.allOrders => PharmacyOrderFilter.all,
  };
}

int _sectionCount(PharmacyWorkbenchSummary summary, PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => summary.orderedQueue,
    PharmacyDeskSection.inProgress => summary.partiallyDispensedQueue,
    PharmacyDeskSection.pendingPayment => summary.pendingPaymentQueue,
    PharmacyDeskSection.completed => summary.dispensedOrders,
    PharmacyDeskSection.allOrders => summary.totalOrders,
  };
}

static IconData _sectionIcon(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => Icons.medication_liquid_outlined,
    PharmacyDeskSection.inProgress => Icons.pending_actions_outlined,
    PharmacyDeskSection.pendingPayment => Icons.payments_outlined,
    PharmacyDeskSection.completed => Icons.done_all_outlined,
    PharmacyDeskSection.allOrders => Icons.inventory_2_outlined,
  };
}

String _sectionLabel(AppLocalizations l10n, PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => l10n.pharmacySummaryReadyLabel,
    PharmacyDeskSection.inProgress => l10n.pharmacySummaryPartialLabel,
    PharmacyDeskSection.pendingPayment => l10n.pharmacyFilterPendingPayment,
    PharmacyDeskSection.completed => l10n.pharmacySummaryCompletedLabel,
    PharmacyDeskSection.allOrders => l10n.pharmacyFilterAll,
  };
}
```

#### 3c. Update `_handleSectionDeepLink()`

Update the existing deep-link handler to also support the new section-based deep linking. The current `?section=inventory` / `?section=stock` behavior should be preserved — if the section value matches an inventory keyword, open the catalog dialog. Otherwise, switch to the corresponding `PharmacyDeskSection` tab.

```dart
Future<void> _handleSectionDeepLink() async {
  if (_handledSectionDeepLink || !mounted) return;
  final String section =
      GoRouterState.of(context)
          .uri.queryParameters['section']?.trim().toLowerCase() ??
      '';
  if (section == 'inventory' || section == 'stock') {
    _handledSectionDeepLink = true;
    await openPharmacyCatalogDialog(
      context, ref,
      initialTab: PharmacyCatalogTab.inventory,
    );
    return;
  }
  final PharmacyDeskSection? parsed = _sectionFromQuery(section);
  if (parsed != null && parsed != _section) {
    _handledSectionDeepLink = true;
    setState(() => _section = parsed);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    unawaited(controller.applyFilter(_filterForSection(parsed)));
  }
}
```

#### 3d. Refactor `build()` method

Replace the current `build()` of `_PharmacyWorkspaceContentState`. The new structure:

1. **Toolbar:** Keep `appWorkspaceToolbarWithLabels()` but **remove order-status summary notifications** (All, Ready, Partial, Completed, Discharge, Outpatient, Ward, Pending Payment, Attestation). **Keep only inventory-alert notifications** (Low Stock, Almost Out, Expiring Soon). Move the primary action to be contextual per tab. Keep the catalog overflow action and refresh.

2. **Body:** Wrap content in a `Column` with:
   - `Row` containing `Expanded(AppTabStrip(...))` + `AppAccessActionGate(AppButton.primary(...))`
   - `SizedBox(height: theme.spacing.md)`
   - The existing `_PharmacyQueuePanel` with its `AppListTable`

The contextual primary action button next to the tab strip:

```dart
Widget _primaryActionForSection(
  AppLocalizations l10n,
  PharmacyDeskSection section,
  PharmacyWorkspaceController controller,
) {
  return switch (section) {
    PharmacyDeskSection.queue || PharmacyDeskSection.inProgress =>
      AppButton.primary(
        label: l10n.pharmacyDispenseAction,
        leadingIcon: Icons.medication_liquid_outlined,
        onPressed: () => controller.applyFilter(PharmacyOrderFilter.ready),
      ),
    PharmacyDeskSection.pendingPayment =>
      AppButton.primary(
        label: l10n.pharmacyQueueFilterLabel,
        leadingIcon: Icons.payments_outlined,
        onPressed: () => controller.applyFilter(PharmacyOrderFilter.pendingPayment),
      ),
    PharmacyDeskSection.completed || PharmacyDeskSection.allOrders =>
      AppButton.primary(
        label: l10n.pharmacyCatalogPanelTitle,
        leadingIcon: Icons.inventory_2_outlined,
        onPressed: () => unawaited(openPharmacyCatalogDialog(context, ref)),
      ),
  };
}
```

Approximate `build()` body structure:

```dart
@override
Widget build(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final PharmacyWorkspaceState state = widget.state;
  final PharmacyWorkspaceController controller = ref.read(
    pharmacyWorkspaceControllerProvider.notifier,
  );
  final ThemeData theme = Theme.of(context);

  return AppWorkspace(
    title: l10n.pharmacyTitle,
    leadingIcon: AppRouteIcons.pharmacy,
    toolbar: appWorkspaceToolbarWithLabels(
      l10n,
      summaryNotifications: <AppWorkspaceSummaryNotification>[
        // ONLY inventory alerts — order-status summaries removed (now tabs)
        if (state.inventoryWorkbench.summary.criticalStockRows > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.pharmacySummaryLowStockLabel,
            count: state.inventoryWorkbench.summary.criticalStockRows,
            icon: Icons.warning_amber_outlined,
            tone: AppWorkspaceStatusTone.error,
            onSelected: () => unawaited(
              _openCatalogForInventoryAlert(PharmacyInventoryFilter.lowStock),
            ),
          ),
        if (state.inventoryWorkbench.summary.almostOutOfStockRows > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.pharmacySummaryAlmostOutLabel,
            count: state.inventoryWorkbench.summary.almostOutOfStockRows,
            icon: Icons.inventory_outlined,
            tone: AppWorkspaceStatusTone.warning,
            onSelected: () => unawaited(
              _openCatalogForInventoryAlert(
                PharmacyInventoryFilter.almostOutOfStock,
              ),
            ),
          ),
        if (state.inventoryWorkbench.summary.expiringSoonRows > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.pharmacySummaryExpiringSoonLabel,
            count: state.inventoryWorkbench.summary.expiringSoonRows,
            icon: Icons.event_busy_outlined,
            tone: AppWorkspaceStatusTone.warning,
            onSelected: () => unawaited(
              _openCatalogForInventoryAlert(
                PharmacyInventoryFilter.expiringSoon,
              ),
            ),
          ),
      ],
      maxVisibleScreenActions: 1,
      overflowSections: <AppToolbarOverflowSection>[
        AppToolbarOverflowSection(
          headerLabel: l10n.pharmacyCatalogPanelTitle,
          actions: <Widget>[
            AppButton.secondary(
              label: l10n.pharmacyCatalogPanelTitle,
              leadingIcon: Icons.inventory_2_outlined,
              onPressed: () {
                unawaited(openPharmacyCatalogDialog(context, ref));
              },
            ),
          ],
        ),
        const AppToolbarOverflowSection(showsNotifications: true),
      ],
      onRefresh: () async {
        final AppFailure? failure = await controller.refresh();
        if (context.mounted) {
          _showFailureIfNeeded(context, failure);
        }
      },
      isRefreshing: state.isRefreshingOrders,
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppTabStrip(
                tabs: <AppTabItem>[
                  for (final PharmacyDeskSection section
                      in PharmacyDeskSection.values)
                    AppTabItem(
                      id: section.name,
                      icon: _sectionIcon(section),
                      label:
                          '${_sectionLabel(l10n, section)} (${_sectionCount(state.workbench.summary, section)})',
                    ),
                ],
                selectedId: _section.name,
                onTabTapped: (String tabId) {
                  for (final PharmacyDeskSection section
                      in PharmacyDeskSection.values) {
                    if (section.name == tabId) {
                      setState(() => _section = section);
                      _updateUrlForSection(section);
                      unawaited(
                        controller.applyFilter(_filterForSection(section)),
                      );
                      break;
                    }
                  }
                },
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            AppAccessActionGate(
              requirement: _writeRequirement,
              builder: (BuildContext context, bool isAllowed) {
                return _primaryActionForSection(l10n, _section, controller);
              },
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _PharmacyQueuePanel(
          state: state,
          section: _section,
          writeRequirement: _writeRequirement,
          searchController: _searchController,
          columnVisibilityController: _tableColumnController,
        ),
      ],
    ),
  );
}
```

### 4. Update `_PharmacyQueuePanel` — File: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`

Add a `section` parameter to `_PharmacyQueuePanel`:

```dart
class _PharmacyQueuePanel extends ConsumerWidget {
  const _PharmacyQueuePanel({
    required this.state,
    required this.section,
    required this.writeRequirement,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PharmacyWorkspaceState state;
  final PharmacyDeskSection section;
  // ... rest unchanged
```

In its `build()`, add per-tab column visibility and width storage keys:

```dart
AppListTable<PharmacyOrder>(
  page: state.workbench.orders,
  isLoading: state.isRefreshingOrders,
  columnVisibilityController: columnVisibilityController,
  columnVisibilityStorageKey: 'pharmacy_${section.name}',
  columnWidthStorageKey: 'pharmacy_cw_${section.name}',
  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
  // ... rest of existing config unchanged
)
```

### 5. Add per-tab column sets (optional enhancement) — File: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`

Create a `_columnsForSection()` method that returns different column configurations per tab:

```dart
List<AppListTableColumn<PharmacyOrder>> _columnsForSection(
  BuildContext context,
  PharmacyDeskSection section,
) {
  final List<AppListTableColumn<PharmacyOrder>> base =
      _defaultPharmacyWorklistColumns(context);
  return switch (section) {
    PharmacyDeskSection.queue => base,
    PharmacyDeskSection.inProgress => base,
    PharmacyDeskSection.pendingPayment => [
      ...base,
      ..._optionalPharmacyWorklistColumns(context)
          .where((AppListTableColumn<PharmacyOrder> c) => c.id == 'ordered_at'),
    ],
    PharmacyDeskSection.completed => base,
    PharmacyDeskSection.allOrders => base,
  };
}
```

Update `_PharmacyQueuePanel.build()` to use `_columnsForSection(context, section)` instead of `_defaultPharmacyWorklistColumns(context)`. Since `_columnsForSection` is a top-level function, pass `section` to the panel and call it from inside `build()`.

### 6. Add `app_routes.dart` import — File: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`

Ensure `app_routes.dart` is imported for `AppRoutes.pharmacy.location(...)`:

```dart
import 'package:hosspi_hms/app/router/app_routes.dart';
```

Also ensure `app_tab_strip.dart` is imported (it may already be via `components.dart` barrel):

```dart
// Already available via: import 'package:hosspi_hms/shared/components/components.dart';
```

### 7. Update deep-link handling for section — File: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`

In `_applyRouteQuery()`, also handle the new section field:

```dart
Future<void> _applyRouteQuery(PharmacyWorkspaceQuery query) async {
  final PharmacyWorkspaceController controller = ref.read(
    pharmacyWorkspaceControllerProvider.notifier,
  );
  // Handle tab section deep link
  if (query.section.isNotEmpty) {
    final PharmacyDeskSection? parsed = _sectionFromQuery(query.section);
    if (parsed != null && parsed != _section) {
      setState(() => _section = parsed);
      unawaited(controller.applyFilter(_filterForSection(parsed)));
    }
  }
  if (query.search.isNotEmpty) {
    _searchController.text = query.search;
    controller.applySearch(query.search);
  }
  if (query.encounterId.isNotEmpty || query.orderId.isNotEmpty) {
    final PharmacyOrder? order = _findOrderByQuery(query);
    if (order != null) {
      await controller.selectOrder(order);
    }
  }
}
```

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart` barrel) | Tab bar in body with `PharmacyDeskSection` values |
| `AppTabItem` | Same as above | Each tab definition with `id`, `icon`, `label` |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` (via barrel) | Already used — add `columnVisibilityStorageKey` and `columnWidthStorageKey` |
| `AppListTableSearch<T>` | Same as above | Already used — no changes |
| `AppSearchBar` | `package:hosspi_hms/shared/components/app_search_bar.dart` (via barrel) | Already used via `AppListTableSearch` |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/app_workspace.dart` (via `layout.dart` barrel) | Already used — keep as scaffold |
| `AppWorkspaceToolbarConfig` | `package:hosspi_hms/shared/layout/app_workspace_toolbar.dart` (via barrel) | Already used — reduce summary notifications |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Already imported — wrap contextual primary action button |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` | Already used — contextual per-tab label |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Already used — no changes |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Already used via `AppListTable`'s adaptive mode |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| None | No new files needed — all changes are modifications to existing files |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` | Add `PharmacyDeskSection` enum; update `PharmacyWorkspaceQuery` with `section` field and parsing |
| `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` | Add `_section` state, tab strip, URL sync, per-tab primary action, per-tab column storage keys, update `_handleSectionDeepLink()`, update `_applyRouteQuery()`, add `section` param to `_PharmacyQueuePanel`, reduce toolbar summary notifications to inventory-only |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| None | No files to delete — this is a UI layout refactoring |

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the order-status `AppWorkspaceSummaryNotification` entries from the toolbar (the ones for All, Ready, Partial, Completed, Discharge, Outpatient, Ward, Pending Payment, Attestation) — their functionality is now provided by tabs.
- [ ] Remove unused imports across all modified files.
- [ ] Ensure no dead helper methods remain that only served the old summary-notification chip layout.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactoring only restructures the frontend UI layout (tab strip, URL routing, column visibility storage keys). No backend API changes, no new columns, no new endpoints.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full table with all columns visible, tab strip displays full labels with counts (e.g., "Queue (12)"), primary action button shows label + icon beside the tab strip.
- **Tablet (600–839px / `md`):** Table with condensed columns, tab strip may overflow horizontally (scrollable), primary action shows icon only or collapses into toolbar overflow.
- **Mobile (<600px / `xs`/`sm`):** `AppListTable` automatically switches to `mobileItemBuilder` → `_PharmacyOrderListTile` cards. Tab strip scrolls horizontally. Primary action button collapses.

The breakpoint handling is automatic via `AppListTable`'s `displayMode: AppListTableDisplayMode.adaptive` (default) and `AppBreakpoints.fromConstraints()`. No additional responsive code is needed — the existing `mobileItemBuilder` handles mobile layout.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to the pharmacy screen
flutter test test/features/pharmacy/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls `controller.applyFilter()` with the correct `PharmacyOrderFilter` and updates the URL via `GoRouter.replace`
- [ ] Deep linking: navigating directly to `/pharmacy?section=in-progress` renders the In Progress tab as selected
- [ ] Deep linking (backward compat): navigating to `/pharmacy?section=inventory` still opens the catalog dialog
- [ ] Table data: each tab displays the correct filtered dataset from the server
- [ ] Search: typing in the search bar filters table rows (existing behavior preserved)
- [ ] Filter dialog: advanced filter button opens the filter UI and applies filters (existing behavior preserved)
- [ ] Primary action: button label changes per tab (Dispense on Queue, View Catalog on Completed, etc.)
- [ ] Column visibility: per-tab storage keys ensure column visibility is persisted independently
- [ ] Responsive layout: widget tests verify `mobileItemBuilder` renders on xs/sm breakpoints
- [ ] No regressions: existing pharmacy functionality (order detail dialog, billing, dispensing, attestation, catalog dialog) still works

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The pharmacy workspace uses `AppTabStrip` with 5 tabs (Queue, In Progress, Pending Payment, Completed, All Orders)
- [ ] Each tab has its own URL that supports deep linking via `?section=<value>`
- [ ] Backward compatibility: `?section=inventory|stock` still opens the catalog dialog
- [ ] The primary action button is contextual per tab and positioned to the right of the tab strip
- [ ] The page body uses `AppListTable<PharmacyOrder>` with per-tab `columnVisibilityStorageKey` and `columnWidthStorageKey`
- [ ] Order-status summary notifications are removed from the toolbar (replaced by tabs)
- [ ] Inventory-alert notifications (Low Stock, Almost Out, Expiring Soon) remain in the toolbar
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (automatic via `AppListTable` adaptive mode)
- [ ] All existing domain behavior is preserved: server-side pagination, advanced filters, order detail dialog, billing, dispensing, attestation, catalog dialog, real-time sync, inventory alerts
- [ ] Domain-specific business logic and data are preserved
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
