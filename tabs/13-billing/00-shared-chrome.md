# Billing — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.billing` under app `ShellRoute`
- Workspace entry: `billingWorkspaceEntryRequirement` — (`billing:read` ∪ `billing:write`) ∩ `billing-payments`
- Read chrome: `billingWorkspaceReadRequirement` — ∩ `billing:read` + `billing-payments`
- Write mutations: ∩ `billing:write` + `billing-payments`
- Approvals decide: ∩ `billing:write` + `financial:approve`
- Claims pending tab: (`billing:read` ∪ `billing:write`) ∩ `billing-payments` ∩ `insurance-claims`
- Claims mutations: `billingClaimsWriteRequirement` (claims write vocabulary)
- List Export / table Print: ∩ `evidence:export` (`billingWorkspaceExportRequirement` / `canExportBillingWorkspace` / `canPrintBillingWorkspace`)
- `BillingQueueType.overdue` is **not** a desk tab (`isDeskSection == false` / `canViewBillingQueue` returns false)

## Page chrome

- `AsyncStateScaffold<BillingWorkspaceState>` over `billingWorkspaceControllerProvider`
  - App bar: `billingWorkspaceTitle`
  - Loading: `billingLoadingTitle` / `billingLoadingBody`
  - Retry → controller `refresh()`
- Body: `ResponsivePage` + `AppTabStrip` + `_BillingQueuePanel` or `BillingPriceBookPanel`
- In-desk URL: `syncWorkspaceLocation` with `?section=<queue>` (+ `overdue=yes` on Collect when filtered; price-book flag)
- Deep-link actions (e.g. `action=pay`) open payment only when write-authorized

## Tab strip

- Desk queues from `BillingQueueType.values` where `canViewBillingQueue`
- Extra tab: Price book (`id: prices`, `billingPriceBookTab`) when `canViewBillingPriceBook`
- Counts: sibling model = dedicated unfiltered `summary.countFor(queue)`; active tab with search/advanced filters uses filtered `workItems.totalItemCount` via `billingQueueTabCount`
- Price book uses `billingPriceBookActiveCountProvider` + `billingPriceBookCountTone` (`info`)
- Count tones: `warning` for issue/collect/claims/approvals; `info` for open work / price book; overdue enum would be `danger` but is not a tab
- Icons via `billingQueueIcon`; tooltips via `billingQueueTooltip`

## Queue table toolbar pattern

Order: **Filters → Settings → Export → Print → context trailing (owner-tab only)**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `billingSearchSemanticLabel` / `billingSearchHint` | Clear `billingClearSearch` |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettings*` | keys `billing_<section>_v1` via `billingTableSettingsKey` |
| Export | `commonTableExportActionLabel` | omitted without ∩ `evidence:export` |
| Print | `commonPrintActionLabel` | preview-first via `printBillingWorkspaceList`; omitted without ∩ `evidence:export` |
| Charge | `billingChargeAction` | **Open work only**; write ∩ |
| Issue all | `billingIssueAllAction` | **To issue only**; write ∩ |
| Close day / Close shift | `billingCloseDay` / `billingCloseShift` | **Collect due only**; write ∩ |

Date filter: **enabled** — `billingIssuedDateFilterLabel`.

Text filters: patient / invoice / encounter helpers (`_billingTextFilters`).

## Shared dialogs / reuse

| Surface | Owner |
| --- | --- |
| Work item detail | Billing-owned (`BillingDetailBody`) |
| Quick charge | Billing-owned `showBillingQuickChargeDialog` |
| Charge similarity | Billing-owned |
| Receive payment | Billing-owned `showBillingReceivePaymentDialog` → receipt print helpers |
| Issue / Issue all / Refund / Adjust / Void / Send / Approve / Reject | Billing form dialogs |
| Refund / adjustment similarity | Billing-owned |
| Claim submit / reconcile / pre-auth | Billing-owned (claims write ∩) |
| Ledger | Billing-owned `showBillingLedgerDialog` (**reused** accounts-facing ledger UI) |
| Price book create/edit | Billing-owned price book dialogs |
| Print invoice / receipt / claim / approval / price book / worklist | Billing print helpers |

Detail Print triggers use `commonPrintActionLabel` (`Print`); document-specific meaning stays in tooltips (`billingPrintInvoiceTooltip` / claim / approval).

## Feedback patterns

- Empty: queue-specific bodies (`billingEmptyReadyToIssueBody`, `billingEmptyCollectDueBody`, …); short-copy queues use body as title
- Mutations: `_showMutationResult` snackbars
- Detail Print/Download omitted when unauthorized (no disabled stubs)
- List Export / Print omitted when unauthorized (no disabled stubs)
