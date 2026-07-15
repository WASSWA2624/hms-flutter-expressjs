# Standardize Integrations Screen

## Objective

Refactor the Integrations workspace to add section-based tab navigation with deep-linkable URLs, matching the Reception workspace pattern. The current implementation uses `AppWorkspaceSummaryNotification` badges for filtering by status/kind, but lacks the `AppTabStrip` section tabs that Reception uses to let operators quickly switch between data categories. After this refactor the Integrations screen will have an `AppTabStrip` with five sections (Integrations, API Keys, Webhooks, Logs, Interop), each with per-section columns, per-section column persistence, per-section primary actions, deep-link query support via URL query parameters, and URL synchronization on tab change.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

- **Main page:** `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart` (2279 lines) — `IntegrationsWorkspacePage` extends `ConsumerWidget`, wraps content in `AsyncStateScaffold<IntegrationWorkspaceState>`.
- **Content widget:** `_IntegrationsWorkspaceContent` extends `ConsumerStatefulWidget` — uses `AppWorkspace` layout with toolbar containing `AppWorkspaceSummaryNotification` badges (All, Active, Warnings, Failed, API Keys, Webhooks) for filtering, `AppPermissionActionButton` primary/secondary actions (Create Integration, Create API Key, Create Webhook), and body containing `_IntegrationWorklistPanel`.
- **Table:** `_IntegrationWorklistPanel` renders `AppListTable<IntegrationWorkItem>` with `AppListTableSearch` (server-side search + advanced filter via `AppSearchBarFilterGroup`), 7 columns (Type, Name, Status, Owner, Scope, Last Event, Next Action), `mobileItemBuilder`, column visibility controller.
- **Tabs/Sections:** None. No `AppTabStrip`. Filtering is done via `AppWorkspaceSummaryNotification` badge taps and `AppSearchBarFilterGroup` advanced filter, which call `controller.applyFilter()`.
- **Routing:** Flat `GoRoute` at `/integrations` — no `initialQuery` parameter, no deep-link support, no URL sync on filter change.
  ```
  GoRoute(
    path: AppRoutes.integrations.path,
    name: AppRoutes.integrations.name,
    builder: (_, _) => const IntegrationsWorkspacePage(),
  ),
  ```
- **Query model:** `IntegrationWorkspaceQuery` in `frontend/lib/features/integrations/domain/entities/integration_entities.dart` has `search`, `filter` (`IntegrationWorkspaceFilter` enum), and `pageRequest` — but NO `fromUri()` factory, NO `signature` getter, NO URL-related methods.
- **Filter enum:** `IntegrationWorkspaceFilter` has values: `all`, `integrations`, `apiKeys`, `webhooks`, `logs`, `interop`, `active`, `warning`, `failed`, `disabled` — the first six are kind-based (map to tab sections), the last four are status-based (should stay as advanced filters).
- **State management:** Riverpod `AsyncNotifierProvider<IntegrationsWorkspaceController, Result<IntegrationWorkspaceState>>` — already handles search, filter, pagination, refresh, CRUD.
- **Controller:** `frontend/lib/features/integrations/presentation/controllers/integrations_workspace_controller.dart` (701 lines) — methods: `build`, `refresh`, `applySearch`, `applyFilter`, `changePage`, `selectItem`, plus all CRUD operations.
- **Domain entities:** `IntegrationRecord`, `ApiKeyRecord`, `WebhookSubscriptionRecord`, `IntegrationLogRecord`, `InteropCapabilityStatus`, `IntegrationWorkItem` (union-style row model with factories per kind), `IntegrationWorkspaceState`.
- **Shared components already in use:** `AppWorkspace`, `AppListTable`, `AppListTableSearch`, `AppSearchBarFilterGroup`, `AppWorkspaceSummaryNotification`, `AppWorkspaceStatusBadge`, `AppWorkspaceStatePanel`, `AppWorkspaceDetailPanel`, `AppPermissionActionButton`, `AppButton`, `AppDialog`, `AppInfoTileGrid`, `AppFormShell`, `AppAccessActionGate`, `AsyncStateScaffold`, `ResponsivePage`.
- **Package name:** `hosspi_hms`.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

- **`frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`** — Canonical section-tab pattern: `_ReceptionWorkspaceContent` uses `AppTabStrip` with `AppTabItem` entries generated from `ReceptionDeskSection.values` enum. Tab labels include count: `'${label} (${count})'`. Tab change calls `setState(() => _section = section)` + `_updateUrlForSection()`. Per-section columns via `_columnsForSection()`. Per-section column persistence via `columnVisibilityStorageKey: 'reception_${_section.name}'` and `columnWidthStorageKey: 'reception_cw_${_section.name}'`. `AppButton.primary` positioned in a `Row` next to the `AppTabStrip`. Deep-link via `ReceptionWorkspaceQuery.fromUri()`. URL sync via `GoRouter.of(context).replace<void>(location)` with query parameters.
- **`frontend/lib/features/reception/domain/entities/reception_entities.dart`** — `ReceptionWorkspaceQuery` with `fromUri(Uri)` factory, `hasRouteTargeting` getter, `signature` getter. `ReceptionDeskSection` enum with 4 values.
- **`frontend/lib/app/router/app_router.dart`** — Reception route passes `initialQuery`: `builder: (_, GoRouterState state) => ReceptionWorkspacePage(initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri))`.
- **`frontend/lib/app/router/app_routes.dart`** — `AppRouteData` with `location()` method for building URLs with query parameters.
- **`frontend/lib/shared/components/app_tab_strip.dart`** — `AppTabStrip` widget with `tabs: List<AppTabItem>`, `selectedId: String`, `onTabTapped: ValueChanged<String>`.
- **`frontend/lib/shared/components/app_list_table.dart`** — `AppListTable<T>` with `columnVisibilityStorageKey`, `columnWidthStorageKey`, `columnVisibilityController` for per-section column persistence.
- **`frontend/lib/shared/layout/app_workspace.dart`** — `AppWorkspace` with `title`, `toolbar`, `body`, `leadingIcon`.

## Target Architecture

### Section Configuration

The five sections map to the existing kind-based `IntegrationWorkspaceFilter` values:

| Section Tab | Enum Value | Description | Section Count | Primary Action |
|-------------|-----------|-------------|---------------|----------------|
| Integrations | `integrations` | Integration config records | Count of `IntegrationRecord` items | "New Integration" → opens `_IntegrationConfigDialog` |
| API Keys | `apiKeys` | API key records | Count of `ApiKeyRecord` items | "New API Key" → opens `_ApiKeyDialog` |
| Webhooks | `webhooks` | Webhook subscriptions | Count of `WebhookSubscriptionRecord` items | "New Webhook" → opens `_WebhookDialog` |
| Logs | `logs` | Integration event logs | Count of `IntegrationLogRecord` items | No primary action (read-only tab) |
| Interop | `interop` | Interoperability readiness | Count of `InteropCapabilityStatus` items | No primary action (read-only tab) |

### Deep-Link Query Parameters

| Parameter | Aliases | Purpose |
|-----------|---------|---------|
| `section` | `panel`, `filter`, `kind` | Select the active tab section |
| `search` | `q` | Pre-fill search query |

URL examples:
- `/integrations` → default section (integrations)
- `/integrations?section=api-keys` → API Keys tab
- `/integrations?section=webhooks&q=payment` → Webhooks tab with search

### Routing

**File to modify:** `frontend/lib/app/router/app_router.dart`

Replace the current builder:

```dart
builder: (_, _) => const IntegrationsWorkspacePage(),
```

With the deep-link pattern (following Reception exactly):

```dart
builder: (_, GoRouterState state) {
  return IntegrationsWorkspacePage(
    initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri),
  );
},
```

### Page Layout

The widget tree must follow this structure inside the `AppWorkspace.body`:

```
AppWorkspace (KEEP existing toolbar, summary notifications, primary/secondary actions)
└── body: Column
    ├── Row
    │   ├── Expanded → AppTabStrip (NEW — section tabs with counts)
    │   └── AppAccessActionGate → AppButton.primary (per-section primary action)
    ├── SizedBox(height: theme.spacing.md)
    └── AppListTable<IntegrationWorkItem> (EXISTING — add per-section columns + column persistence keys)
```

This mirrors Reception's `ResponsivePage` → `Column` → `Row[AppTabStrip, AppButton.primary]` → `AppListTable` pattern, but placed inside the `AppWorkspace.body` slot.

### Per-Section Columns

Each section should show different, contextually relevant columns. The current 7 columns (Type, Name, Status, Owner, Scope, Last Event, Next Action) are generic across all kinds. Refactor to section-specific columns:

**Integrations section:**
- Name (alwaysVisible)
- Integration Type (HL7/FHIR/LAB/etc.)
- Status
- Tenant / Owner
- Config Summary (hasConfig indicator)
- Webhook Count
- Log Count
- Last Updated

**API Keys section:**
- Name (alwaysVisible)
- Key ID (masked value)
- Status (Active/Inactive/Expired)
- User / Owner
- Permissions Count (scope)
- Expires At
- Last Used At

**Webhooks section:**
- Event (alwaysVisible)
- Integration Name
- Target URL / Host
- Status (Active/Inactive)
- Integration Status
- Created At

**Logs section:**
- Integration Name (alwaysVisible)
- Status (Success/Failure/Pending)
- Message
- Logged At
- Integration Type
- Requires Attention (indicator)

**Interop section:**
- Capability Title (alwaysVisible)
- Scope
- Status
- Next Action
- Unavailable Reason
- Last Updated

### Data & State Management

**Existing controller to reuse (do NOT recreate):**

- `integrationsWorkspaceControllerProvider` — `frontend/lib/features/integrations/presentation/controllers/integrations_workspace_controller.dart` — Already handles `applyFilter()` with `IntegrationWorkspaceFilter` values that map directly to section tabs. The kind-based filters (`integrations`, `apiKeys`, `webhooks`, `logs`, `interop`) become the section tabs. The status-based filters (`active`, `warning`, `failed`, `disabled`) remain as `AppWorkspaceSummaryNotification` badge filters in the toolbar.

**New local state (in `_IntegrationsWorkspaceContentState`):**

```dart
late IntegrationDeskSection _section;
String? _appliedRouteSignature;
```

The section determines which kind-based filter to apply AND which columns to show AND the column persistence key.

## Implementation Steps

1. **Add `IntegrationDeskSection` enum** — File: `frontend/lib/features/integrations/domain/entities/integration_entities.dart`
   - Add a new enum below the existing `IntegrationWorkspaceFilter` enum:
     ```dart
     enum IntegrationDeskSection {
       integrations,
       apiKeys,
       webhooks,
       logs,
       interop,
     }
     ```
   - This enum maps 1:1 to the kind-based `IntegrationWorkspaceFilter` values.

2. **Add deep-link support to `IntegrationWorkspaceQuery`** — File: `frontend/lib/features/integrations/domain/entities/integration_entities.dart`
   - Add a `fromUri(Uri uri)` factory constructor following `ReceptionWorkspaceQuery.fromUri()`:
     ```dart
     factory IntegrationWorkspaceQuery.fromUri(Uri uri) {
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
       final String sectionRaw = pick(<String>['section', 'panel', 'filter', 'kind']);
       final String searchRaw = pick(<String>['search', 'q']);
       return IntegrationWorkspaceQuery(
         search: searchRaw,
         filter: _filterFromSection(sectionRaw),
       );
     }
     ```
   - Add a `hasRouteTargeting` getter:
     ```dart
     bool get hasRouteTargeting => search.isNotEmpty || filter != IntegrationWorkspaceFilter.all;
     ```
   - Add a `signature` getter:
     ```dart
     String get signature => '${filter.name}|$search';
     ```
   - Add a private helper `_filterFromSection(String raw)` that maps section query values to `IntegrationWorkspaceFilter`:
     ```dart
     static IntegrationWorkspaceFilter _filterFromSection(String raw) {
       return switch (raw.trim().toLowerCase()) {
         'integrations' || 'integration' => IntegrationWorkspaceFilter.integrations,
         'api-keys' || 'apikeys' || 'api_keys' || 'keys' => IntegrationWorkspaceFilter.apiKeys,
         'webhooks' || 'webhook' || 'hooks' => IntegrationWorkspaceFilter.webhooks,
         'logs' || 'log' || 'activity' => IntegrationWorkspaceFilter.logs,
         'interop' || 'interoperability' || 'fhir' || 'hl7' => IntegrationWorkspaceFilter.interop,
         _ => IntegrationWorkspaceFilter.all,
       };
     }
     ```

3. **Update `IntegrationsWorkspacePage` constructor** — File: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - Add `initialQuery` parameter:
     ```dart
     class IntegrationsWorkspacePage extends ConsumerWidget {
       const IntegrationsWorkspacePage({this.initialQuery, super.key});
       final IntegrationWorkspaceQuery? initialQuery;
     ```
   - Pass `initialQuery` to `_IntegrationsWorkspaceContent`:
     ```dart
     dataBuilder: (BuildContext context, IntegrationWorkspaceState state) {
       return _IntegrationsWorkspaceContent(
         state: state,
         initialQuery: initialQuery,
       );
     },
     ```

4. **Add section state and deep-link handling to `_IntegrationsWorkspaceContent`** — File: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - Add `initialQuery` parameter to the widget.
   - Add state fields:
     ```dart
     late IntegrationDeskSection _section;
     String? _appliedRouteSignature;
     ```
   - In `initState`, resolve the initial section from `initialQuery`:
     ```dart
     _section = _sectionFromFilter(widget.state.query.filter);
     _scheduleRouteQuery(widget.initialQuery);
     ```
   - Add `_scheduleRouteQuery()`, `_applyDeepLink()`, and `_updateUrlForSection()` methods following the Reception pattern exactly:
     ```dart
     void _scheduleRouteQuery(IntegrationWorkspaceQuery? query) {
       if (query == null || !query.hasRouteTargeting) return;
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (!mounted) return;
         unawaited(_applyDeepLink(query));
       });
     }

     Future<void> _applyDeepLink(IntegrationWorkspaceQuery query) async {
       if (_appliedRouteSignature == query.signature) return;
       _appliedRouteSignature = query.signature;
       final IntegrationDeskSection? section = _sectionFromFilter(query.filter);
       if (section != null) {
         setState(() => _section = section);
       }
       if (query.search.isNotEmpty) {
         _searchController.text = query.search;
       }
       // Apply filter via controller
       final IntegrationWorkspaceFilter filter = _filterForSection(_section);
       await ref.read(integrationsWorkspaceControllerProvider.notifier).applyFilter(filter);
     }

     void _updateUrlForSection(IntegrationDeskSection section) {
       if (!mounted) return;
       final String sectionValue = _sectionToQueryValue(section);
       final String location = AppRoutes.integrations.location(
         queryParameters: <String, String>{
           if (sectionValue.isNotEmpty) 'section': sectionValue,
         },
       );
       GoRouter.of(context).replace<void>(location);
     }
     ```
   - Add helper methods for section ↔ filter ↔ query value mapping:
     ```dart
     static IntegrationDeskSection _sectionFromFilter(IntegrationWorkspaceFilter filter) {
       return switch (filter) {
         IntegrationWorkspaceFilter.integrations => IntegrationDeskSection.integrations,
         IntegrationWorkspaceFilter.apiKeys => IntegrationDeskSection.apiKeys,
         IntegrationWorkspaceFilter.webhooks => IntegrationDeskSection.webhooks,
         IntegrationWorkspaceFilter.logs => IntegrationDeskSection.logs,
         IntegrationWorkspaceFilter.interop => IntegrationDeskSection.interop,
         _ => IntegrationDeskSection.integrations,
       };
     }

     static IntegrationWorkspaceFilter _filterForSection(IntegrationDeskSection section) {
       return switch (section) {
         IntegrationDeskSection.integrations => IntegrationWorkspaceFilter.integrations,
         IntegrationDeskSection.apiKeys => IntegrationWorkspaceFilter.apiKeys,
         IntegrationDeskSection.webhooks => IntegrationWorkspaceFilter.webhooks,
         IntegrationDeskSection.logs => IntegrationWorkspaceFilter.logs,
         IntegrationDeskSection.interop => IntegrationWorkspaceFilter.interop,
       };
     }

     static String _sectionToQueryValue(IntegrationDeskSection section) {
       return switch (section) {
         IntegrationDeskSection.integrations => 'integrations',
         IntegrationDeskSection.apiKeys => 'api-keys',
         IntegrationDeskSection.webhooks => 'webhooks',
         IntegrationDeskSection.logs => 'logs',
         IntegrationDeskSection.interop => 'interop',
       };
     }
     ```
   - In `didUpdateWidget`, check for route query signature change (like Reception):
     ```dart
     if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
       _scheduleRouteQuery(widget.initialQuery);
     }
     ```

5. **Add `AppTabStrip` to the body layout** — File: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - Modify `_IntegrationsWorkspaceContentState.build()` to wrap the current `_IntegrationWorklistPanel` in a `Column` with `AppTabStrip` and per-section primary action button above it.
   - The `AppWorkspace.body` currently is just `_IntegrationWorklistPanel(...)`. Change to:
     ```dart
     body: Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: <Widget>[
         Row(
           children: <Widget>[
             Expanded(
               child: AppTabStrip(
                 tabs: <AppTabItem>[
                   for (final IntegrationDeskSection section in IntegrationDeskSection.values)
                     AppTabItem(
                       id: section.name,
                       icon: _sectionIcon(section),
                       label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                     ),
                 ],
                 selectedId: _section.name,
                 onTabTapped: (String tabId) {
                   for (final IntegrationDeskSection section in IntegrationDeskSection.values) {
                     if (section.name == tabId) {
                       setState(() => _section = section);
                       _updateUrlForSection(section);
                       unawaited(controller.applyFilter(_filterForSection(section)));
                       break;
                     }
                   }
                 },
               ),
             ),
             SizedBox(width: theme.spacing.sm),
             _buildSectionPrimaryAction(l10n, controller, state, canManage),
           ],
         ),
         SizedBox(height: theme.spacing.md),
         _IntegrationWorklistPanel(
           state: state,
           section: _section,
           searchController: _searchController,
           columnVisibilityController: _tableColumnController,
           onItemSelected: (IntegrationWorkItem item) {
             unawaited(_openIntegrationDetailDialog(context, item, canManage));
           },
         ),
       ],
     ),
     ```
   - Add helper methods for section icons, labels, and counts:
     ```dart
     static IconData _sectionIcon(IntegrationDeskSection section) {
       return switch (section) {
         IntegrationDeskSection.integrations => Icons.hub_outlined,
         IntegrationDeskSection.apiKeys => Icons.key_outlined,
         IntegrationDeskSection.webhooks => Icons.webhook_outlined,
         IntegrationDeskSection.logs => Icons.history_outlined,
         IntegrationDeskSection.interop => Icons.compare_arrows_outlined,
       };
     }

     String _sectionLabel(AppLocalizations l10n, IntegrationDeskSection section) {
       return switch (section) {
         IntegrationDeskSection.integrations => l10n.integrationsAllSummaryLabel,
         IntegrationDeskSection.apiKeys => l10n.integrationsApiKeysSummaryLabel,
         IntegrationDeskSection.webhooks => l10n.integrationsWebhooksSummaryLabel,
         IntegrationDeskSection.logs => 'Logs',  // Add l10n key if available
         IntegrationDeskSection.interop => 'Interop',  // Add l10n key if available
       };
     }

     int _sectionCount(IntegrationWorkspaceState state, IntegrationDeskSection section) {
       return switch (section) {
         IntegrationDeskSection.integrations => state.integrations.length,
         IntegrationDeskSection.apiKeys => state.apiKeys.length,
         IntegrationDeskSection.webhooks => state.webhooks.length,
         IntegrationDeskSection.logs => state.logs.length,
         IntegrationDeskSection.interop => state.interopStatuses.length,
       };
     }
     ```
   - Add the per-section primary action builder:
     ```dart
     Widget _buildSectionPrimaryAction(
       AppLocalizations l10n,
       IntegrationsWorkspaceController controller,
       IntegrationWorkspaceState state,
       bool canManage,
     ) {
       return switch (_section) {
         IntegrationDeskSection.integrations => AppAccessActionGate(
           requirement: _integrationsManageRequirement,
           builder: (BuildContext context, bool isAllowed) {
             return AppButton.primary(
               label: l10n.integrationsCreateIntegrationAction,
               leadingIcon: Icons.add_link_outlined,
               enabled: isAllowed,
               isLoading: state.isSaving,
               onPressed: isAllowed
                   ? () => unawaited(_openIntegrationDialog(context, controller, state))
                   : null,
             );
           },
         ),
         IntegrationDeskSection.apiKeys => AppAccessActionGate(
           requirement: _integrationsManageRequirement,
           builder: (BuildContext context, bool isAllowed) {
             return AppButton.primary(
               label: l10n.integrationsCreateApiKeyAction,
               leadingIcon: Icons.key_outlined,
               enabled: isAllowed,
               isLoading: state.isSaving,
               onPressed: isAllowed
                   ? () => unawaited(_openApiKeyDialog(context, controller))
                   : null,
             );
           },
         ),
         IntegrationDeskSection.webhooks => AppAccessActionGate(
           requirement: _integrationsManageRequirement,
           builder: (BuildContext context, bool isAllowed) {
             return AppButton.primary(
               label: l10n.integrationsCreateWebhookAction,
               leadingIcon: Icons.webhook_outlined,
               enabled: isAllowed,
               isLoading: state.isSaving,
               onPressed: isAllowed
                   ? () => unawaited(_openWebhookDialog(context, controller, state))
                   : null,
             );
           },
         ),
         IntegrationDeskSection.logs || IntegrationDeskSection.interop => const SizedBox.shrink(),
       };
     }
     ```

6. **Move primary/secondary actions from toolbar to section-contextual** — File: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - Remove the `primary` and `secondary` action buttons from `appWorkspaceToolbarWithLabels()` since they are now section-contextual via the `AppTabStrip` row.
   - Keep `summaryNotifications` in the toolbar for status-based filtering (Active, Warnings, Failed).
   - Keep `onRefresh` and `isRefreshing` in the toolbar.
   - The toolbar `AppWorkspaceSummaryNotification` badges should now show only the **status-based** notifications (Active, Warnings, Failed, Disabled) — not the kind-based ones (All, API Keys, Webhooks) since those are now tabs.

7. **Add per-section columns to `_IntegrationWorklistPanel`** — File: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - Add `section` parameter to `_IntegrationWorklistPanel`.
   - Create `_columnsForSection(AppLocalizations l10n, IntegrationDeskSection section)` method that returns different `List<AppListTableColumn<IntegrationWorkItem>>` per section:
     - **Integrations:** Name (alwaysVisible), Integration Type, Status, Owner, Has Config, Webhook Count, Log Count, Last Updated.
     - **API Keys:** Name (alwaysVisible), Key ID, Status, User, Permissions Count, Expires At, Last Used.
     - **Webhooks:** Event (alwaysVisible), Integration, Target Host, Status, Created At.
     - **Logs:** Integration (alwaysVisible), Status, Message, Logged At, Requires Attention.
     - **Interop:** Title (alwaysVisible), Scope, Status, Next Action, Unavailable Reason, Last Updated.
   - Update `AppListTable` to use per-section column persistence:
     ```dart
     columnVisibilityStorageKey: 'integrations_${section.name}',
     columnWidthStorageKey: 'integrations_cw_${section.name}',
     ```

8. **Update the route definition** — File: `frontend/lib/app/router/app_router.dart`
   - Change the integrations route builder to pass `initialQuery`:
     ```dart
     GoRoute(
       path: AppRoutes.integrations.path,
       name: AppRoutes.integrations.name,
       builder: (_, GoRouterState state) {
         return IntegrationsWorkspacePage(
           initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri),
         );
       },
     ),
     ```
   - Add `go_router` import if not already present (`GoRouterState` type).

9. **Add required imports** — File: `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
   - Add `import 'package:go_router/go_router.dart';` (for `GoRouter.of(context).replace`).
   - Add `import 'package:hosspi_hms/app/router/app_routes.dart';` (for `AppRoutes.integrations.location`).
   - Ensure `AppTabStrip`/`AppTabItem` is available via `package:hosspi_hms/shared/components/components.dart` (already imported).

10. **Update tests** — File: `frontend/test/features/integrations/` (create if needed)
    - Add test cases per the Testing Requirements section below.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Section tabs with `label`, `icon`, `id`; placed in `Row` above `AppListTable` |
| `AppListTable<T>` / `AppListTableColumn<T>` | `package:hosspi_hms/shared/components/components.dart` | Already in use; add per-section `columnVisibilityStorageKey` and section-specific columns |
| `AppListTableSearch<T>` / `AppSearchBarFilterGroup` | `package:hosspi_hms/shared/components/components.dart` | Already in use; keep advanced filter for status-based filtering |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/layout.dart` | Already in use; keep toolbar with summary notifications |
| `AppWorkspaceSummaryNotification` | `package:hosspi_hms/shared/layout/layout.dart` | Already in use; keep for status-based filtering (Active, Warnings, Failed) |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Per-section primary action button via `AppButton.primary()` |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Already in use; wrap per-section primary action |
| `AppPermissionActionButton` | `package:hosspi_hms/core/permissions/access_gate.dart` | Move from toolbar to section-contextual placement |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Already in use; keep in table cells |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/components.dart` | Already in use; keep as outer wrapper |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/layout/layout.dart` | Already in use; keep for empty/error states |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| None | All changes are modifications to existing files |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/integrations/domain/entities/integration_entities.dart` | Add `IntegrationDeskSection` enum. Add `fromUri()` factory, `hasRouteTargeting` getter, and `signature` getter to `IntegrationWorkspaceQuery`. Add `_filterFromSection()` helper. |
| `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart` | Add `initialQuery` param to `IntegrationsWorkspacePage`. Add section state, deep-link handling, URL sync, `AppTabStrip`, per-section primary action, per-section columns to `_IntegrationsWorkspaceContent`. Pass `section` to `_IntegrationWorklistPanel`. Update toolbar to remove kind-based summary notifications (now in tabs). Add per-section column persistence keys. |
| `frontend/lib/app/router/app_router.dart` | Update integrations route builder to pass `initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri)` |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| None | No files need deletion — this is an additive refactoring |

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove kind-based `AppWorkspaceSummaryNotification` entries from the toolbar (All, API Keys, Webhooks) — they are now section tabs. Keep only status-based notifications (Active, Warnings, Failed).
- [ ] Remove the `primary` and `secondary` action buttons from `appWorkspaceToolbarWithLabels()` — they are now per-section actions in the `AppTabStrip` row.
- [ ] Remove unused imports across all modified files.
- [ ] Remove any helper methods that only served the old toolbar actions (if they duplicate the new per-section action methods).
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged.

The existing `integration`, `integration_log`, `webhook_subscription`, and `api_key` tables (Prisma/MySQL, `backend/prisma/migrations/`) already contain all necessary columns. This refactoring only changes the Flutter frontend layout — no schema changes needed.

## Responsive Design Requirements

- **Desktop (≥1200px / `xl`):** Full `AppListTable` with all per-section columns visible. `AppTabStrip` rendered horizontally with all tabs visible. Per-section primary action button displayed with label + icon.
- **Tablet (600–1199px / `md`–`lg`):** `AppTabStrip` may scroll if needed. Table hides lower-priority columns (use `alwaysVisible: false` and column visibility settings). Primary action button may show icon-only.
- **Mobile (<600px / `xs`–`sm`):** `AppListTable` switches to list mode via `mobileItemBuilder` (already implemented via `_MobileIntegrationItem`). `AppTabStrip` scrollable. Primary action button hides or collapses to icon-only.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` if any explicit breakpoint checks are needed beyond `AppListTable`'s built-in adaptive display mode.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format frontend/lib/features/integrations/ frontend/lib/app/router/

# Analyze
cd frontend && dart analyze --fatal-infos

# Run tests related to this screen (if they exist)
cd frontend && flutter test test/features/integrations/

# Run shared component tests to ensure no regressions
cd frontend && flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Section tab navigation: switching tabs calls `controller.applyFilter()` with the correct kind-based filter and updates the URL
- [ ] Deep linking: constructing `IntegrationsWorkspacePage(initialQuery: IntegrationWorkspaceQuery(filter: IntegrationWorkspaceFilter.apiKeys))` renders the API Keys tab selected
- [ ] Deep linking from URL: `IntegrationWorkspaceQuery.fromUri(Uri.parse('/integrations?section=webhooks'))` returns `filter: IntegrationWorkspaceFilter.webhooks`
- [ ] Deep linking aliases: `IntegrationWorkspaceQuery.fromUri(Uri.parse('/integrations?kind=api-keys'))` returns `filter: IntegrationWorkspaceFilter.apiKeys`
- [ ] Signature: `IntegrationWorkspaceQuery(filter: IntegrationWorkspaceFilter.logs).signature` is deterministic and changes with filter
- [ ] Per-section columns: Integrations tab shows integration-specific columns, API Keys tab shows API key columns, etc.
- [ ] Per-section column persistence: `columnVisibilityStorageKey` changes per section (`integrations_integrations`, `integrations_apiKeys`, etc.)
- [ ] Per-section primary action: Integrations tab shows "New Integration", API Keys tab shows "New API Key", Logs tab shows no primary action
- [ ] Toolbar status badges: Active, Warnings, Failed badges still work for cross-section status filtering
- [ ] Search: typing in `AppListTableSearch` calls `controller.applySearch()` (unchanged behavior)
- [ ] No regressions: existing CRUD operations (create/edit/delete integration, API key, webhook), detail dialog, replay actions still work

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The integrations screen has an `AppTabStrip` with 5 section tabs (Integrations, API Keys, Webhooks, Logs, Interop) matching the Reception workspace pattern
- [ ] Each section tab label includes a count: `"Integrations (3)"`, `"API Keys (2)"`, etc.
- [ ] Switching tabs calls `controller.applyFilter()` with the corresponding kind-based filter and updates the URL query parameter
- [ ] Deep linking works: navigating to `/integrations?section=api-keys` renders the API Keys tab selected
- [ ] `IntegrationWorkspaceQuery.fromUri()` correctly parses section and search from URL query parameters
- [ ] URL updates when switching sections via `GoRouter.replace()` with query parameters
- [ ] Each section tab shows contextually relevant columns (not the same generic 7 columns for all sections)
- [ ] Column visibility and width preferences persist per-section via `columnVisibilityStorageKey: 'integrations_${section.name}'`
- [ ] Per-section primary action: "New Integration" on Integrations tab, "New API Key" on API Keys tab, "New Webhook" on Webhooks tab, none on Logs/Interop
- [ ] Toolbar still shows status-based `AppWorkspaceSummaryNotification` badges (Active, Warnings, Failed) for cross-section status filtering
- [ ] Kind-based summary notifications (All, API Keys, Webhooks) are removed from toolbar — they are now section tabs
- [ ] Primary/secondary create actions removed from toolbar — they are now per-section actions next to `AppTabStrip`
- [ ] All existing functionality preserved: CRUD operations, detail dialogs, search, advanced filter, mobile list layout, pagination, real-time refresh
- [ ] No shared component is re-implemented — only imported and used
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass
