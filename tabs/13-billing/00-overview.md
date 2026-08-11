# Billing workspace UI inventory

Source: `tabs-lister/13-billing.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `BillingWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/billing` (`AppRoutes.billing`)  
**Page:** `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`  
**Access:** `frontend/lib/features/billing/presentation/billing_access.dart`  
**Queue enum:** `BillingQueueType` (desk sections via `isDeskSection`; `overdue` is Collect filter, not a primary tab)

Cross-check note: inventory naming aligns with historical `prompts/01-billing/` tab prompts (`01-open-work` … `06-price-book`) when present in the workspace tree; this pass writes under `tabs/13-billing/` only.

## Desk tabs (order)

| Enum / surface | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `all` | `work` | `all`, `inbox` | [01-open-work.md](01-open-work.md) |
| `needsIssue` | `issue` | `needs-issue`, `ready-to-issue` | [02-to-issue.md](02-to-issue.md) |
| `pendingPayment` | `collect` | `pending-payment`, `awaiting-payment`; `overdue` slug → collect + `overdue=yes` | [03-collect-due.md](03-collect-due.md) |
| `claimsPending` | `claims` | `claims-pending` | [04-open-claims.md](04-open-claims.md) |
| `approvalRequired` | `approvals` | `approval-required` | [05-need-approval.md](05-need-approval.md) |
| Price book (not queue enum) | price-book URL / `prices` tab id | | [06-price-book.md](06-price-book.md) |

Helpers: `BillingQueueType.sectionQueryValue` / `resolveDeskSlug` / `BillingWorkspaceQuery` in `billing_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
- `frontend/lib/features/billing/presentation/billing_access.dart`
- `frontend/lib/features/billing/domain/entities/billing_entities.dart`
- `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_form_dialogs.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_receive_payment_dialog.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_quick_charge_dialog.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_ledger_dialog.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_price_book_dialogs.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_price_book_panel.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_workspace_table_support.dart`
- `frontend/lib/features/billing/presentation/widgets/billing_support.dart`
- `frontend/lib/features/billing/presentation/billing_receipt_print_helpers.dart`
- `frontend/lib/features/billing/presentation/billing_invoice_print_helpers.dart`
- `frontend/lib/features/billing/presentation/billing_claim_print_helpers.dart`
- `frontend/lib/features/billing/presentation/billing_approval_print_helpers.dart`
- `frontend/test/features/billing/`
