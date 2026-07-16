# Standardize Billing Tables

## Objective

Refactor every `AppListTable` on the Billing workspace (`/billing`, `BillingWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only** on `BillingWorkspacePage`. Do not rewrite domain APIs, permissions, tab toolbar actions (Close shift / Close day / Refresh), or the nested read-only line-items table inside `BillingDetailBody` (`_InvoiceLineItemsSection` in `billing_detail_widgets.dart`). Keep Billing business behavior.

## Current State (from audit)

### Screen overview

| Field | Value |
|-------|-------|
| Route | `/billing` |
| Page widget | `BillingWorkspacePage` |
| Primary file | `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart` |
| Controller | `billingWorkspaceControllerProvider` → `BillingWorkspaceController` |
| Entity | `BillingWorkItem` (`frontend/lib/features/billing/domain/entities/billing_entities.dart`) |
| Tabs (`BillingQueueType`) | `all`, `needsIssue`, `pendingPayment`, `claimsPending`, `approvalRequired`, `overdue` |
| Deep-link params | `BillingWorkspaceQuery.fromUri` accepts `queue` or `filter` slug (e.g. `?queue=needs-issue`, `?filter=pending-payment`) plus `search`, `patientId`, `invoiceNumber`, `encounterId`, `action=pay`, etc. |

### Table inventory (workspace page)

| # | Table widget | File | Entity | Tab binding | Default columns today | Detail on row select |
|---|--------------|------|--------|-------------|----------------------|----------------------|
| 1 | `_BillingQueuePanel` | `billing_workspace_page.dart` | `BillingWorkItem` | Single table; `columns` from `_columnsForQueue(context, l10n, activeQueue)` | **6–7** per tab (see matrix below) | `_showBillingDetailDialog` ✓ |

There is **one** `AppListTable` on the workspace page. Tab switches change `activeQueue` and therefore `_columnsForQueue` output; storage keys are already per-tab: `billing_${activeQueue.name}` / `billing_cw_${activeQueue.name}`.

### Per-tab column matrix (current)

| Tab | `BillingQueueType` | Column ids (in order) | Count |
|-----|-------------------|------------------------|-------|
| All | `all` | `patient_name`, `patient_id`, `invoice`, `source`, `status`, `amount_due`, `amount_paid` | **7** |
| Needs issue | `needsIssue` | `patient_name`, `invoice`, `encounter`, `source`, `amount_due` | **5** (no status, no next_action) |
| Pending payment | `pendingPayment` | `patient_name`, `patient_id`, `invoice`, `status`, `amount_due`, `amount_paid`, `balance` | **7** |
| Claims pending | `claimsPending` | `patient_name`, `invoice`, `encounter`, `source`, `status`, `amount_due` | **6** |
| Approval required | `approvalRequired` | `patient_name`, `invoice`, `encounter`, `source`, `status`, `amount_due` | **6** |
| Overdue | `overdue` | `patient_name`, `patient_id`, `invoice`, `status`, `amount_due`, `amount_paid`, `updated` | **7** |

`columnChoices` today (hidden by default): only `balance`, `updated` — insufficient; most overflow columns are still in default `columns`.

### Search chrome (current)

```dart
search: AppListTableSearch<BillingWorkItem>(
  matcher: (_, _) => true,  // GAP: does not match column fields
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.billingFiltersLabel,      // "Filters" ✓
  advancedFilterTitle: l10n.billingFiltersLabel,          // GAP: "Filters" not "Advanced filters"
  // filterGroups, textFilters, date filter wired ✓
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,  // "Settings" ✓
// GAP: columnVisibilityTitle not set (must be "Table Settings")
```

Server-side search is debounced via `_searchController` → `BillingWorkspaceController.applySearch`. Keep that behavior; add a proper client `matcher` that covers all declared + hidden column fields (Mortuary pattern).

### Gap analysis vs `prompt.md`

| Gap | Detail |
|-----|--------|
| Column budget | All tabs except `needsIssue` exceed **5** declared columns |
| Patient split | `patient_name` + `patient_id` are separate columns; merge into one `patient` column with `AppListItemText` (name + MRN) |
| Status widget | Uses `BillingGateBadge` (`AppStatusBadge`); standardize to `AppWorkspaceStatusBadge` + `AppWorkspaceStatus` using `billingClearanceLabel` / `billingClearanceTone` / `billingClearanceIcon` from `billing_support.dart` |
| Next action | **Missing** on every tab; `BillingWorkItem` has workflow via `clearanceState` and `can*` getters |
| Search matcher | `(_, _) => true` — must match all column + `columnChoices` text |
| Filter modal title | `advancedFilterTitle` is `billingFiltersLabel` ("Filters"); must be **Advanced filters** |
| Settings modal title | `columnVisibilityTitle` missing; must be **Table Settings** |
| Adaptive display | `displayMode` not set (defaults to table); add `AppListTableDisplayMode.adaptive` |
| Mobile parity | `_BillingMobileTile` shows merged subtitle string + status badge only; **no next-action control** |
| Duplicate amounts | `pendingPayment` / `overdue` show both `amount_due` and `balance` (same `balanceDue` field) |

### What already complies

- `columnVisibilityController` + per-tab `columnVisibilityStorageKey` / `columnWidthStorageKey`
- `onRowSelected` → `_showBillingDetailDialog` with full action surface in `BillingDetailBody`
- Advanced filters wired (`filterGroups`, text filters, date range, `hasActiveFilters`)
- Realtime: `BillingWorkspaceController` listens to `RealtimeEventGroups.billingWorkspace` via `listenForRealtimeRefresh`
- Tab toolbar refresh/close actions correctly live outside table search chrome

### Workflow / next-action mapping

`BillingWorkItem` does **not** use `WorkflowActionButton` / `WorkflowActionRegistry`. Derive the primary next action from existing `can*` getters (same priority as `BillingDetailBody` callbacks in `_showBillingDetailDialog`):

| Priority | Condition | Label (existing l10n) | Handler (reuse) |
|----------|-----------|----------------------|-----------------|
| 1 | `item.canIssue` | `l10n.billingIssueAction` ("Issue") | `_showIssueDialog` |
| 2 | `item.canReceivePayment` | `l10n.billingReceivePayment` | `_showPaymentDialog` |
| 3 | `item.canApproveOrReject` | `l10n.billingApproveAction` | `_showApproveDialog` |
| 4 | `item.canSubmitClaim` | `l10n.billingSubmitClaimAction` | `_showSubmitClaimDialog` |
| 5 | `item.canReconcileClaim` | `l10n.billingReconcileClaimAction` | `_showReconcileClaimDialog` |
| 6 | `item.canApprovePreAuthorization` | `l10n.billingPreAuthApproveAction` | `_showPreAuthStatusDialog(status: 'APPROVED')` |
| 7 | `item.canRequestRefund` | `l10n.billingRequestRefund` | `_showRefundDialog` |
| 8 | `item.canRequestAdjustment` | `l10n.billingRequestAdjustment` | `_showAdjustmentDialog` |
| 9 | `item.canRequestVoid` | `l10n.billingRequestVoidAction` | `_showVoidDialog` |
| 10 | `item.canFinalizeEncounterBilling` | `l10n.billingFinalizeEncounterAction` | `_showFinalizeEncounterDialog` |
| 11 | `item.isInvoice && !_isCancelled` (issued, no higher action) | `l10n.billingSendAction` | `_showSendDialog` |
| — | none applicable | `SizedBox.shrink()` or disabled label | — |

Gate all press handlers with `canWrite` (same as detail dialog). Use `AppButton.secondary` with `compact: true` styling or a small `TextButton` that **stops row-click propagation** (see `_CompactActionButton` in `frontend/lib/shared/workflow_actions/workflow_action_button.dart` for size reference).

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` (`_MortuaryWorklist` — search matcher, Filters/Settings chrome, `_nextActionLabel`)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` (`emergencyNextActionColumn`, `WorkflowActionButton` — pattern for clickable compact action column)
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` (`_nextActionColumn` + `WorkflowActionButton` when registry applies)
- `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart` (`AppListItemText` two-line cells, `_OperationsRequestListTile` mobile parity)
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `_BillingQueuePanel` | `all` | `BillingWorkItem` | `patient`, `invoice`, `amount_due`, `status`, `next_action` | `billing_all` |
| `_BillingQueuePanel` | `needsIssue` | `BillingWorkItem` | `patient`, `invoice`, `encounter`, `status`, `next_action` | `billing_needsIssue` |
| `_BillingQueuePanel` | `pendingPayment` | `BillingWorkItem` | `patient`, `invoice`, `amount_due`, `status`, `next_action` | `billing_pendingPayment` |
| `_BillingQueuePanel` | `claimsPending` | `BillingWorkItem` | `patient`, `invoice`, `encounter`, `status`, `next_action` | `billing_claimsPending` |
| `_BillingQueuePanel` | `approvalRequired` | `BillingWorkItem` | `patient`, `invoice`, `amount_due`, `status`, `next_action` | `billing_approvalRequired` |
| `_BillingQueuePanel` | `overdue` | `BillingWorkItem` | `patient`, `invoice`, `amount_due`, `status`, `next_action` | `billing_overdue` |

### Column plan — shared column builders

Extract reusable `AppListTableColumn<BillingWorkItem>` builders (private top-level or `billing_workspace_table_columns.dart` under `presentation/widgets/`). Reuse across `_columnsForQueue` switch arms.

| Column id | Label (l10n) | Source field | Notes |
|-----------|--------------|--------------|-------|
| `patient` | `billingPatientNameColumn` (header); cell shows name + MRN | `patientDisplayName` + `effectivePatientNumber` | `AppListItemText` two-line; **remove** separate `patient_id` default column |
| `invoice` | `billingInvoiceColumn` | `effectiveDisplayId` | keep existing sort/cell |
| `encounter` | `billingEncounterLabel` | `encounterDisplayId ?? encounterId` | `columnChoices` default on tabs that don't prioritize it |
| `source` | `billingSourceColumn` | `invoiceSourceSummary` via `billingInvoiceSourceLabel` | `columnChoices` |
| `amount_due` | `billingAmountDueColumn` | `balanceDue` + `currency` via `billingMoney` | numeric |
| `amount_paid` | `billingPaidColumn` | `paidAmount` | `columnChoices` |
| `balance` | `billingBalanceColumn` | `balanceDue` | `columnChoices` (duplicate of amount_due — do not show both by default) |
| `updated` | `billingUpdatedColumn` | `timelineAt` via `billingDateTime` | `columnChoices` |
| `status` | `billingStatusColumn` | `clearanceState` | **Position 4** — `AppWorkspaceStatusBadge(status: AppWorkspaceStatus(label: billingClearanceLabel(...), tone: billingClearanceTone(...), icon: billingClearanceIcon(...)))` |
| `next_action` | **Add** `billingNextActionColumnLabel`: `"Next action"` | derived from `can*` getters | **Position 5**, `alwaysVisible: true`; compact `AppButton.secondary` |

### `columnChoices` (hidden by default, all tabs)

Include every column **not** in that tab's default five: `encounter`, `source`, `amount_paid`, `balance`, `updated`, and any tab-specific extras. Do **not** duplicate ids between `columns` and `columnChoices` for the same tab.

### Search chrome (per table)

- Implement `bool _billingWorkItemMatchesSearch(BillingWorkItem item, String query, BuildContext context)` matching (case-insensitive contains) at minimum:
  - `billingPatientName`, `effectivePatientNumber`, `effectiveDisplayId`, `encounterDisplayId`, `encounterId`, `billingInvoiceSourceLabel`, `billingClearanceLabel` for `clearanceState`, `billingMoney` for `balanceDue`/`paidAmount`, `billingDateTime` for `timelineAt`, `billingStatus`/`status` raw codes, `_billingNextActionLabel` text
- Wire `matcher: _billingWorkItemMatchesSearch` (or closure passing `context`)
- Keep debounced `onSubmitted` / `onClear` → `controller.applySearch` for server refresh
- `advancedFilterButtonLabel`: keep `l10n.billingFiltersLabel` ("Filters") **or** add shared `commonFiltersActionLabel` if present; value must be **Filters**
- `advancedFilterTitle`: `l10n.commonAdvancedFiltersTitle` → **"Advanced filters"** (add key)
- `columnVisibilityLabel`: `l10n.commonTableSettingsActionLabel` ("Settings")
- `columnVisibilityTitle`: `l10n.commonTableSettingsTitle` → **"Table Settings"** (add key)

### Row interaction

- Keep `onRowSelected` → `controller.selectItem(item)` + `_showBillingDetailDialog(...)`
- Next-action column buttons invoke the **same** `_show*Dialog` helpers as the detail dialog (not generic navigation)
- Respect `canWrite` and `state.isSaving` for enabled state

### Mobile (`_BillingMobileTile`)

Refactor to mirror desktop priority fields using `AppListItemRow` or `AppListItemText`:
- Title: patient name
- Subtitle: invoice · amount due (tab-relevant fields)
- Trailing: `AppWorkspaceStatusBadge` for clearance
- Details row or trailing: compact next-action button (same handler as column)
- Set `displayMode: AppListTableDisplayMode.adaptive` on `AppListTable`

## Implementation Steps

### 1. Add shared helpers — `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart` (new, preferred)

Create helpers to keep `billing_workspace_page.dart` manageable:

```dart
// Suggested exports:
String billingNextActionLabel(BuildContext context, BillingWorkItem item, {required bool canWrite});
Widget billingNextActionButton(BuildContext context, WidgetRef ref, BillingWorkItem item, {required bool canWrite, required bool isSaving, required VoidCallback onNeedsDetail});
bool billingWorkItemMatchesSearch(BuildContext context, BillingWorkItem item, String query);
AppListTableColumn<BillingWorkItem> billingPatientColumn(AppLocalizations l10n);
AppListTableColumn<BillingWorkItem> billingStatusColumn(AppLocalizations l10n);
AppListTableColumn<BillingWorkItem> billingNextActionColumn(...);
// + existing amount/invoice/encounter/source/updated column builders moved from page
```

`billingNextActionButton` should wrap the button in a `GestureDetector` / `InkWell` with behavior that prevents the row tap from firing when the action is pressed (match `WorkflowActionButton` propagation handling).

Alternatively, colocate in `billing_support.dart` if the file stays small.

### 2. `_BillingQueuePanel` — `billing_workspace_page.dart`

- Add `displayMode: AppListTableDisplayMode.adaptive`
- Set `columnVisibilityTitle: l10n.commonTableSettingsTitle`
- Set `advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
- Replace `matcher: (_, _) => true` with `billingWorkItemMatchesSearch`
- Refactor `_columnsForQueue` to return **exactly 5** columns per tab per target matrix
- Expand `_columnChoices` to include all non-default columns for that tab
- Replace `_BillingMobileTile` implementation for status + next-action parity
- Update `_BillingQueuePanel.build` to pass `ref`, `canWrite`, `isSaving` into next-action column builder

### 3. Status badge migration

In the status column `cellBuilder`, replace `BillingGateBadge` with:

```dart
AppWorkspaceStatusBadge(
  status: AppWorkspaceStatus(
    label: billingClearanceLabel(context, item.clearanceState),
    tone: billingClearanceTone(item.clearanceState),
    icon: billingClearanceIcon(item.clearanceState),
  ),
),
```

Keep `BillingGateBadge` in `billing_detail_widgets.dart` for the detail dialog unless you update both for consistency (optional; detail dialog is out of primary scope).

### 4. l10n — `frontend/lib/l10n/app_en.arb` only

Add if missing:

```json
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings",
"billingNextActionColumnLabel": "Next action"
```

Keep `billingFiltersLabel` as **Filters** for the button. Run codegen if the project requires it after arb edits.

### 5. Tests — `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`

Update/add tests:

- Each tab's `AppListTable.columns.length == 5`
- `columnVisibilityTitle` / `advancedFilterTitle` resolve to **Table Settings** / **Advanced filters**
- `displayMode == AppListTableDisplayMode.adaptive`
- Mobile breakpoint: status badge + next-action control visible for a actionable item (e.g. draft invoice on Needs issue shows **Issue**)
- Existing tests for tab strip, deep links, toolbar actions, and Filters button must still pass

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableDisplayMode` | same | Adaptive layout |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Patient two-line cell |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/components/components.dart` | Status column |
| `AppButton` | same | Next-action compact buttons |
| `billingClearanceLabel` / `billingClearanceTone` / `billingClearanceIcon` | `package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart` | Status formatting |
| `BillingDetailBody` / `_showBillingDetailDialog` | `billing_workspace_page.dart` + `billing_detail_widgets.dart` | Row detail + action parity |
| `billingWorkspaceControllerProvider` | `package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart` | Data + realtime |

Do **not** introduce a new table widget, custom search bar, or duplicate filter modal.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| **Modify** | `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart` |
| **Create** (recommended) | `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart` |
| **Modify** (optional) | `frontend/lib/features/billing/presentation/widgets/billing_support.dart` |
| **Modify** | `frontend/lib/l10n/app_en.arb` |
| **Modify** | `frontend/test/features/billing/presentation/billing_workspace_page_test.dart` |
| **Delete** | None |

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only
- Prefer shared keys: `commonTableSettingsActionLabel`, new `commonAdvancedFiltersTitle`, new `commonTableSettingsTitle`
- Reuse existing billing action labels for next-action button text (`billingIssueAction`, `billingReceivePayment`, etc.)

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/billing/
```

## Testing Requirements

- [ ] Each tab: search, Filters, Settings only in chrome (no extra trailing actions)
- [ ] Advanced filters modal title is **Advanced filters**; Settings modal title is **Table Settings**
- [ ] Column visibility persists for session per `billing_<queue>` storage key
- [ ] ≤5 default columns per tab; row number is automatic
- [ ] Patient column uses single two-line field (name + MRN)
- [ ] Status column uses `AppWorkspaceStatusBadge` with clearance labels
- [ ] Next-action column shows explicit verb labels per `can*` state; press opens correct dialog
- [ ] Row tap opens `_showBillingDetailDialog`
- [ ] Mobile list shows same priority fields, status, and next action
- [ ] Search matcher finds values in hidden `columnChoices` fields
- [ ] Realtime refresh still updates rows after mutations/events (`billingWorkspaceControllerProvider`)
- [ ] Permissions still gate write actions (`canWrite` / `AppPermissions.billingWrite`)
- [ ] Tab toolbar (Close shift / Close day / Refresh) unchanged

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for `_BillingQueuePanel` on every `BillingQueueType` tab
- [ ] Domain logic preserved (queues, filters, deep links, payment auto-open, shift/day close)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/billing/` passes
