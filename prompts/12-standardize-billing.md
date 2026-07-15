# Standardize Billing Screen

## Objective

Refactor the Billing workspace to match the standardized tab-and-table layout used by the Reception workspace. The billing screen currently uses a flat single-table layout with summary notification chips for queue filtering. This refactor introduces routable `AppTabStrip` tabs per `BillingQueueType`, URL-driven section navigation, per-tab column sets, and extracts the six embedded dialog form widgets into dedicated files — aligning the billing workspace with the canonical Reception workspace pattern while preserving all existing billing domain logic.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Billing screen files

| File | Type | Summary |
|------|------|---------|
| `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart` | Page (1871 lines) | Main workspace with `AsyncStateScaffold`, `AppWorkspace`, single `AppListTable`, 6 embedded dialog form classes |
| `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart` | Controller | `BillingWorkspaceController` — `AsyncNotifier<Result<BillingWorkspaceState>>` with queue/filter/CRUD operations |
| `frontend/lib/features/billing/domain/entities/billing_entities.dart` | Entities | `BillingQueueType` enum, `BillingWorkItem`, `BillingWorkspaceState`, `BillingWorkspaceQuery`, drafts |
| `frontend/lib/features/billing/domain/repositories/billing_repository.dart` | Repository interface | `BillingRepository` abstract interface |
| `frontend/lib/features/billing/data/repositories/billing_repository_impl.dart` | Repository impl | Concrete API calls |
| `frontend/lib/features/billing/data/dtos/billing_dtos.dart` | DTOs | Wire serialization |
| `frontend/lib/features/billing/presentation/widgets/billing_detail_widgets.dart` | Widget | `BillingGateBadge`, `BillingDetailBody` |
| `frontend/lib/features/billing/presentation/widgets/billing_support.dart` | Helpers | `billingMoney()`, `billingQueueLabel()`, `billingQueueIcon()`, clearance label/tone/icon functions |
| `frontend/lib/features/billing/presentation/widgets/billing_receive_payment_dialog.dart` | Widget | Payment receipt dialog |
| `frontend/lib/features/billing/presentation/widgets/billing_ledger_dialog.dart` | Widget | Patient ledger dialog |
| `frontend/lib/features/billing/presentation/billing_invoice_print_helpers.dart` | Helpers | Invoice printing |
| `frontend/lib/app/router/app_routes.dart` | Route config | `AppRoutes.billing` — path `/billing`, `billingWorkspaceRoles` |
| `frontend/lib/app/router/app_router.dart` | Router | `GoRoute` for `/billing` → `BillingWorkspacePage(initialQuery: BillingWorkspaceQuery.fromUri(state.uri))` |
| `test/features/billing/presentation/billing_workspace_controller_test.dart` | Test | Controller unit tests |
| `test/features/billing/data/billing_dtos_test.dart` | Test | DTO serialization tests |

### Current layout structure

- `BillingWorkspacePage` uses `AsyncStateScaffold<BillingWorkspaceState>` → `_BillingWorkspaceContent`
- `_BillingWorkspaceContent` uses `AppWorkspace` with a `toolbar` (summary notification chips + "Close Shift" / "Close Day" buttons) and a single `AppListTable<BillingWorkItem>` body
- Queues are switched via `AppWorkspaceSummaryNotification` chips in the toolbar, which call `controller.applyQueue(queueType)` — **NOT** via `AppTabStrip` tabs
- **No URL updates** when switching queues — the URL stays at `/billing`
- **Same columns** shown for all queues
- **No per-tab column visibility storage keys**
- **Six dialog form widgets** (`_RefundForm`, `_AdjustmentForm`, `_ReasonForm`, `_NotesForm`, `_CloseForm`, `_ClaimReconcileForm`) are private classes embedded in the 1871-line page file

### Problems/inconsistencies

1. No `AppTabStrip` — queue switching is via toolbar notification chips, not standard tabs
2. No URL-based section routing — switching queues doesn't update the browser URL
3. Same columns for all queue types — no tab-specific column sets
4. No per-section `columnVisibilityStorageKey` / `columnWidthStorageKey`
5. Massive 1871-line page file with 6 embedded dialog form classes
6. Does not use `ResponsivePage` directly (uses `AppWorkspace` which internally wraps it)

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key patterns |
|------|-------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `AppTabStrip` with `ReceptionDeskSection` enum, `_updateUrlForSection()`, `_sectionFromQuery()`, per-section columns via `_columnsForSection()`, `ResponsivePage` with `AppListTable`, `WorkflowActionButton` in cells, mobile item builder |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery` with `fromUri()`, `ReceptionDeskSection` enum |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip(tabs:, selectedId:, onTabTapped:)`, `AppTabItem(id:, icon:, label:)` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor: `items:`, `page:`, `columns:`, `columnChoices:`, `columnVisibilityController:`, `columnVisibilityStorageKey:`, `columnWidthStorageKey:`, `columnVisibilityLabel:`, `search:`, `isLoading:`, `shrinkWrap:`, `physics:`, `onRowSelected:`, `itemKeyBuilder:`, `emptyBuilder:`, `mobileItemBuilder:`, `onPageChanged:`, `pageLabelBuilder:` |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace(title:, leadingIcon:, toolbar:, body:)`, `AppWorkspaceStatusBadge`, `AppWorkspaceStatePanel` |
| `frontend/lib/shared/layout/app_workspace_summary_notification.dart` | `AppWorkspaceSummaryNotification` — used in the toolbar "More" menu |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage(maxWidth:, child:)` |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints.sm=360, md=600, lg=840, xl=1200, xxl=1600`, `AppBreakpoint.isMobile` |

## Target Architecture

### Tab Configuration

The billing workspace will use `BillingQueueType` values as tabs. The `all` queue remains the default landing tab.

| Tab Name | Tab ID | Route Query Value | Description | Primary Action Button |
|----------|--------|-------------------|-------------|----------------------|
| All Work Items | `all` | `all` | Full billing worklist | — (toolbar has Close Shift / Close Day) |
| Needs Issue | `needsIssue` | `needs-issue` | Draft invoices awaiting issuance | — |
| Awaiting Payment | `pendingPayment` | `pending-payment` | Issued invoices awaiting payment | — |
| Claims Pending | `claimsPending` | `claims-pending` | Insurance claims queued | — |
| Approval Required | `approvalRequired` | `approval-required` | Refund/void/adjustment approvals | — |
| Overdue | `overdue` | `overdue` | Past-due invoices | — |

### Routing

The billing route already supports deep-link query parameters via `BillingWorkspaceQuery.fromUri()`. The tab/section will be driven by the existing `queue` query parameter.

**Pattern** (mirroring Reception):
1. When a tab is tapped, call `GoRouter.of(context).replace<void>(location)` with `?queue=<tab-route-value>`
2. On init / `didUpdateWidget`, read `initialQuery.queue` to set the active tab
3. The `queue` parameter maps to `BillingQueueType` using the existing `BillingQueueType.fromServer()` or a new helper function

**Router file**: `frontend/lib/app/router/app_router.dart` — NO changes needed. The existing `GoRoute` already passes `BillingWorkspaceQuery.fromUri(state.uri)` which reads the `queue` parameter.

### Page Layout

```
AsyncStateScaffold<BillingWorkspaceState>
  └─ AppWorkspace
       ├─ toolbar: appWorkspaceToolbarWithLabels(...)
       │    ├─ summaryNotifications (keep existing queue count chips)
       │    ├─ Close Shift button
       │    └─ Close Day button
       └─ body: Column
            ├─ Row
            │    ├─ Expanded(AppTabStrip)    ← NEW: tabs for BillingQueueType
            │    └─ (no primary action button — actions are in toolbar)
            ├─ SizedBox(height: spacing.md)
            └─ AppListTable<BillingWorkItem>
                 ├─ columnVisibilityStorageKey: 'billing_${queue.name}'  ← NEW
                 ├─ columnWidthStorageKey: 'billing_cw_${queue.name}'    ← NEW
                 ├─ columns: _columnsForQueue(queue)                      ← NEW
                 ├─ search: (keep existing AppListTableSearch with filters)
                 └─ mobileItemBuilder: (keep existing _BillingMobileTile)
```

### Data & State Management

**No changes** to the controller or repository. The existing `BillingWorkspaceController` already has:
- `applyQueue(BillingQueueType)` — perfect for tab switching
- `applySearch(String)` / `applyFilters(BillingWorkspaceQuery)` / `clearFilters()`
- `changePage(AppPageRequest)`
- `refresh()`, `selectItem()`, and all mutation methods

The only state-related addition is tracking the active tab locally in the `_BillingWorkspaceContentState` to drive the `AppTabStrip.selectedId` and per-tab column sets. The controller's `state.query.queue` already holds the server-side filter.

## Implementation Steps

### 1. Extract dialog form widgets — File: `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`

- **Create** this new file
- **Move** the following private classes from `billing_workspace_page.dart` into this file and make them **public** (remove underscore prefix):
  - `_RefundForm` → `BillingRefundForm`
  - `_AdjustmentForm` → `BillingAdjustmentForm`
  - `_ReasonForm` → `BillingReasonForm`
  - `_NotesForm` → `BillingNotesForm`
  - `_CloseForm` → `BillingCloseForm`
  - `_ClaimReconcileForm` → `BillingClaimReconcileForm`
- Add all necessary imports in the new file:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
  import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
  import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
  import 'package:hosspi_hms/l10n/app_localizations.dart';
  import 'package:hosspi_hms/l10n/app_localizations_x.dart';
  import 'package:hosspi_hms/shared/components/components.dart';
  import 'package:hosspi_hms/shared/forms/forms.dart';
  ```
- In `billing_workspace_page.dart`, remove the moved classes and add:
  ```dart
  import 'package:hosspi_hms/features/billing/presentation/widgets/billing_form_dialogs.dart';
  ```
- Update all references to the renamed classes in the top-level dialog-show functions (e.g., `_RefundForm(...)` → `BillingRefundForm(...)`).

### 2. Add `AppTabStrip` tabs to the billing page — File: `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`

- **Add imports**:
  ```dart
  import 'package:go_router/go_router.dart';
  import 'package:hosspi_hms/app/router/app_routes.dart';
  import 'package:hosspi_hms/shared/components/app_tab_strip.dart';
  ```

- **Add a `_section` field** to `_BillingWorkspaceContentState`:
  ```dart
  late BillingQueueType _section;
  ```
  Initialize in `initState()`:
  ```dart
  _section = widget.state.query.queue;
  ```

- **Add helper**: Map `BillingQueueType` to a URL-friendly slug:
  ```dart
  static String _queueToQueryValue(BillingQueueType queue) {
    return switch (queue) {
      BillingQueueType.all => 'all',
      BillingQueueType.needsIssue => 'needs-issue',
      BillingQueueType.pendingPayment => 'pending-payment',
      BillingQueueType.claimsPending => 'claims-pending',
      BillingQueueType.approvalRequired => 'approval-required',
      BillingQueueType.overdue => 'overdue',
    };
  }
  ```

- **Add URL update method** (mirrors Reception's `_updateUrlForSection`):
  ```dart
  void _updateUrlForQueue(BillingQueueType queue) {
    if (!mounted) return;
    final String tab = _queueToQueryValue(queue);
    final String location = AppRoutes.billing.location(
      queryParameters: <String, String>{
        if (tab != 'all') 'queue': tab,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }
  ```

- **Modify the `build()` method** of `_BillingWorkspaceContentState`:
  - Replace the current body which only has `_BillingQueuePanel` with a `Column` containing:
    1. A `Row` with an `Expanded(AppTabStrip)` (no primary action button — toolbar has the actions)
    2. `SizedBox(height: theme.spacing.md)`
    3. The existing `_BillingQueuePanel` or its `AppListTable` equivalent

  - The `AppTabStrip` configuration:
    ```dart
    AppTabStrip(
      tabs: <AppTabItem>[
        for (final BillingQueueType queue in BillingQueueType.values)
          AppTabItem(
            id: queue.name,
            icon: billingQueueIcon(queue),
            label: '${billingQueueLabel(context, queue)} (${state.overview.summary.countFor(queue)})',
          ),
      ],
      selectedId: _section.name,
      onTabTapped: (String tabId) {
        for (final BillingQueueType queue in BillingQueueType.values) {
          if (queue.name == tabId) {
            setState(() => _section = queue);
            _updateUrlForQueue(queue);
            ref.read(billingWorkspaceControllerProvider.notifier).applyQueue(queue);
            break;
          }
        }
      },
    )
    ```

- **Sync `_section` with route changes** in `_scheduleRouteQuery` / `_applyRouteQuery`:
  - When `initialQuery.queue` changes, update `_section` accordingly:
    ```dart
    if (query.queue != _section) {
      setState(() => _section = query.queue);
    }
    ```

- **Sync `_section` in `didUpdateWidget`**: If the parent rebuilds with a new `state.query.queue`, update `_section`.

### 3. Add per-queue column sets — File: `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`

- **Add a `_columnsForQueue` method** to `_BillingQueuePanel` or `_BillingWorkspaceContentState` that returns different `AppListTableColumn<BillingWorkItem>` lists based on the active `BillingQueueType`:

  - **`all`**: patient_name, patient_id, invoice, source, status, amount_due, amount_paid (current default)
  - **`needsIssue`**: patient_name, invoice, encounter, source, amount_due (draft invoices — no payment columns)
  - **`pendingPayment`**: patient_name, patient_id, invoice, status, amount_due, amount_paid, balance
  - **`claimsPending`**: patient_name, invoice, encounter, source, status, amount_due (insurance-focused)
  - **`approvalRequired`**: patient_name, invoice, encounter, source, status, amount_due (approval-focused)
  - **`overdue`**: patient_name, patient_id, invoice, status, amount_due, amount_paid, updated (urgency-focused)

- **Pass the active queue** to `_BillingQueuePanel` or compute columns inline.

### 4. Add per-tab column visibility and width storage keys — File: `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`

- In the `AppListTable<BillingWorkItem>` constructor within `_BillingQueuePanel`, add:
  ```dart
  columnVisibilityStorageKey: 'billing_${_section.name}',
  columnWidthStorageKey: 'billing_cw_${_section.name}',
  ```
  where `_section` is the active `BillingQueueType`.

- This requires passing the active queue (`BillingQueueType`) into `_BillingQueuePanel` as a constructor parameter.

### 5. Update `BillingWorkspaceQuery.fromUri` to handle tab slugs — File: `frontend/lib/features/billing/domain/entities/billing_entities.dart`

- The existing `fromUri` already reads `queue` from query parameters and maps it via name/serverValue matching. Ensure the new slug values (`needs-issue`, `pending-payment`, etc.) are also handled. Add matching for the kebab-case slugs in the factory:

  ```dart
  // Add after the existing loop over BillingQueueType.values:
  if (queue == BillingQueueType.all && queueRaw.isNotEmpty) {
    final Map<String, BillingQueueType> slugMap = <String, BillingQueueType>{
      'needs-issue': BillingQueueType.needsIssue,
      'pending-payment': BillingQueueType.pendingPayment,
      'claims-pending': BillingQueueType.claimsPending,
      'approval-required': BillingQueueType.approvalRequired,
    };
    queue = slugMap[queueRaw.toLowerCase()] ?? BillingQueueType.all;
  }
  ```

### 6. Ensure `billingQueueIcon` covers all queue types — File: `frontend/lib/features/billing/presentation/widgets/billing_support.dart`

- Verify that `billingQueueIcon(BillingQueueType queue)` returns an appropriate `IconData` for every `BillingQueueType` value (including `all`). If missing, add:
  ```dart
  IconData billingQueueIcon(BillingQueueType queue) {
    return switch (queue) {
      BillingQueueType.all => Icons.inventory_2_outlined,
      BillingQueueType.needsIssue => Icons.receipt_long_outlined,
      BillingQueueType.pendingPayment => Icons.payments_outlined,
      BillingQueueType.claimsPending => Icons.health_and_safety_outlined,
      BillingQueueType.approvalRequired => Icons.rule_outlined,
      BillingQueueType.overdue => Icons.warning_amber_outlined,
    };
  }
  ```

### 7. Verify `billingQueueLabel` covers all queue types — File: `frontend/lib/features/billing/presentation/widgets/billing_support.dart`

- Ensure `billingQueueLabel(BuildContext context, BillingQueueType queue)` returns a proper localized label for every queue type including `all`. If the function doesn't exist or is incomplete, add it using the l10n keys already referenced in the summary notifications:
  - `all` → `l10n.billingAllWorkItems`
  - `needsIssue` → `l10n.billingIssueQueue`
  - `pendingPayment` → `l10n.billingAwaitingPayment`
  - `claimsPending` → `l10n.billingClaimsPending`
  - `approvalRequired` → `l10n.billingApprovals`
  - `overdue` → `l10n.billingOverdue`

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Tab bar for queue types |
| `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Tab item data class |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` | Already used — add `columnVisibilityStorageKey` and `columnWidthStorageKey` params |
| `AppListTableColumn<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` | Already used |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` | Already used |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` | Already used |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Already used — wrapper stays |
| `AppWorkspaceSummaryNotification` | `package:hosspi_hms/shared/layout/app_workspace_summary_notification.dart` | Already used — keep in toolbar |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Already used |
| `AppDialog` | `package:hosspi_hms/shared/components/components.dart` | Already used |
| `AppFormShell` | `package:hosspi_hms/shared/forms/forms.dart` | Already used in form dialogs |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Breakpoint utilities |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` | Used internally by `AppWorkspace` |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart` | Extracted dialog forms: `BillingRefundForm`, `BillingAdjustmentForm`, `BillingReasonForm`, `BillingNotesForm`, `BillingCloseForm`, `BillingClaimReconcileForm` |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart` | 1. Remove 6 embedded dialog form classes (moved to new file). 2. Add `AppTabStrip` with `BillingQueueType` tabs. 3. Add URL update on tab switch via `GoRouter.replace`. 4. Add `_section` state field synced with route query. 5. Add per-queue column sets via `_columnsForQueue()`. 6. Add `columnVisibilityStorageKey` and `columnWidthStorageKey` per tab. 7. Import new form dialogs file. 8. Import `go_router`, `app_routes`, `app_tab_strip`. |
| `frontend/lib/features/billing/domain/entities/billing_entities.dart` | Add kebab-case slug matching in `BillingWorkspaceQuery.fromUri()` for the new tab URL values |
| `frontend/lib/features/billing/presentation/widgets/billing_support.dart` | Verify/add `billingQueueIcon()` and `billingQueueLabel()` helper functions cover all queue types |

## Files to Delete (if any)

None — no files are being deleted; code is being moved and refactored.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the 6 private form class declarations from `billing_workspace_page.dart` after confirming they are in the new file
- [ ] Remove unused imports across all modified files
- [ ] Ensure no orphaned `_`-prefixed helper functions remain in the page file that were only used by the moved classes
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them
- [ ] Verify no test files reference deleted private symbols — update or remove stale tests

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor is purely a frontend UI restructuring. The billing data model, API contracts, and query parameters remain the same. The existing `BillingWorkspaceQuery.queue` field already supports all the tab filtering needed.

## Responsive Design Requirements

- **Desktop (≥840px / `AppBreakpoint.lg`+):** Full table view with all columns visible per the active tab's column set. `AppTabStrip` renders horizontally with icon + label. Toolbar actions ("Close Shift", "Close Day") show with text labels.
- **Tablet (600–839px / `AppBreakpoint.md`):** Table view with condensed columns. `AppTabStrip` wraps if needed. Toolbar actions show as icon-only buttons.
- **Mobile (<600px / `AppBreakpoint.xs`, `AppBreakpoint.sm`):** `AppListTable` automatically switches to `mobileItemBuilder` rendering card-based `_BillingMobileTile` rows. `AppTabStrip` wraps into multiple lines. Toolbar actions in "More" overflow menu.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` for breakpoint detection. `AppListTable` already handles the table-to-list adaptive switch internally — no manual breakpoint code needed in the billing page.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format frontend/lib/features/billing/ frontend/test/features/billing/

# Analyze
cd frontend && dart analyze --fatal-infos

# Run billing tests
cd frontend && flutter test test/features/billing/

# Run shared component tests to ensure no regressions
cd frontend && flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL query parameter `queue`
- [ ] Deep linking: navigating to `/billing?queue=pending-payment` renders the "Awaiting Payment" tab selected
- [ ] Deep linking: navigating to `/billing?queue=needs-issue` renders the "Needs Issue" tab selected
- [ ] Table data: each tab applies the correct queue filter via the controller
- [ ] Search: typing in the search bar filters table rows (existing behavior preserved)
- [ ] Filter dialog: filter button opens the filter UI and applies filters (existing behavior preserved)
- [ ] Per-tab columns: the "All" tab shows the full column set while "Needs Issue" shows draft-focused columns
- [ ] Responsive layout: on mobile, the table switches to the mobile tile builder
- [ ] No regressions: existing billing workspace functionality (payments, refunds, adjustments, void, approve/reject, claims, close shift/day) still works through the extracted dialog forms

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The billing screen uses `AppTabStrip` tabs for each `BillingQueueType` matching the Reception workspace pattern
- [ ] Each tab has its own URL via the `queue` query parameter that supports deep linking
- [ ] Tab counts are displayed in the tab labels (e.g., "Awaiting Payment (5)")
- [ ] The page body uses `AppListTable<BillingWorkItem>` with per-tab column sets
- [ ] Per-tab `columnVisibilityStorageKey` and `columnWidthStorageKey` are configured
- [ ] The 6 dialog form widgets are extracted to `billing_form_dialogs.dart` — no private form classes remain in the page file
- [ ] The toolbar summary notification chips, "Close Shift", and "Close Day" buttons are preserved
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (using `AppBreakpoints`)
- [ ] All billing domain logic (payments, refunds, adjustments, void, approve/reject, claims, pre-auth, close shift/day, ledger, print/download) is preserved
- [ ] `BillingWorkspaceQuery.fromUri()` handles the new kebab-case tab URL slugs
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] The billing page file is significantly shorter (~800–900 lines vs. current 1871 lines) due to form extraction
