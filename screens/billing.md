# Action inventory — `/billing`

Primary surface: `BillingWorkspacePage` (`frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`).

Permission helpers: `frontend/lib/features/billing/presentation/billing_access.dart`.

| Concern | Gate |
| --- | --- |
| View / read UI, list, filters, detail, print/download, ledger | `billingWorkspaceReadRequirement` (`billing:read` ∩ `billing-payments`) |
| Close shift / close day / invoice mutations / next-action (non-approve, non-claim) | `billingWorkspaceWriteRequirement` (`billing:write` ∩ `billing-payments`) |
| Approve / reject financial holds | `billingApprovalDecisionRequirement` (`billing:write` ∩ `financial:approve` ∩ `billing-payments`) |
| Claims pending tab | `billingClaimsPendingTabRequirement` (`billing:read` ∩ `billing-payments` ∩ `insurance-claims`) |
| Claim submit / reconcile / pre-auth | `billingClaimsWriteRequirement` → `claimsWorkspaceWriteRequirement` |
| Claims pending atom map | `BillingClaimsPendingAtomPermissions` (tab/list/detail/claimWrite/close/routeEntry) |
| All atom map | `BillingAllAtomPermissions` (tab/list/detail/issue/receivePayment/close/approve/claims) |
| Awaiting payment atom map | `BillingAwaitingPaymentAtomPermissions` (tab/list/detail/receivePayment/refund/adjust/void/send/close/approve/claims) |
| Overdue atom map | `BillingOverdueAtomPermissions` (tab/list/detail/receivePayment/adjust/waive/void/dunningSend/close) |
| Needs issue atom map | `BillingNeedsIssueAtomPermissions` (tab/list/detail/issue/close) |
| Approval required atom map | `BillingApprovalRequiredAtomPermissions` (tab/list/detail/approve/create/update/close) |

Route entry any-of: `billing:read` \| `billing:write` + `billing-payments`. Backend remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary or secondary by tab) | Reload queue | **Removed** — list refreshes after mutations, realtime, scaffold retry |
| Rotating primary (**Close shift** / **Close day** / **Refresh** by tab) | Same close / reload goals | **Merged** — stable **Close shift** primary + **Close day** secondary on every tab |
| Advanced filters **Queue** group vs tab strip | Select queue | **Removed** from advanced filters — tabs own queue; clear filters preserves tab |
| **Finalize financial clearance** confirm + snackbar | No billing mutation | **Removed** — client-only shell never called the backend |
| Optional **Balance** column vs **Amount due** | Same `balanceDue` value | **Removed** Balance from column choices — Amount due remains |
| Row **Next action** vs row select → detail actions | Start primary / all item actions | **Kept** — next-action is the labeled minimal path; detail holds secondary actions + print/download |
| Disabled close toolbar when read-only | Close shift / day | **Unauthorized UI absent** — toolbar omitted without `billingWrite` |
| Approve via facility-manage | Approve / reject | **Mapped** to `billingApprovalDecisionRequirement` (`financial:approve` ∩ `billing:write`) |

---

## Billing workspace screen

### Tab strip

- **All / Needs issue / Awaiting payment / Approval required / Overdue**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?queue=…`, applies queue via controller.
  - Condition: `billingWorkspaceReadRequirement`.

- **Claims pending**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to claims queue.
  - Condition: `billingClaimsPendingTabRequirement`; omitted without insurance module / billing read.

- **Close shift** (primary)
  - Location: Tab-strip primary (`billingCloseShift`).
  - Opens modal: Yes — shift close form.
  - Immediate result: Closes shift; snackbar; workspace refresh.
  - Condition: `billingWorkspaceWriteRequirement`; omitted when unauthorized.

- **Close day** (secondary)
  - Location: Tab-strip secondary (`billingCloseDay`).
  - Opens modal: Yes — day close form.
  - Immediate result: Closes day; snackbar; workspace refresh.
  - Condition: `billingWorkspaceWriteRequirement`; omitted when unauthorized.

Tab-strip **Refresh** was removed. Queue work refreshes after mutations, realtime sync, and scaffold **Try again**.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` or `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Filters/search/column visibility for the active queue (`billing_{queue}`).
  - Condition: Always on the worklist when the queue is visible.

#### Advanced filters (from **Filters**)

Fields: patient ID, invoice #, encounter #; source module; billing status; issued date from/to.

- **Apply filters** / **Clear filters** / **Close**
  - Location: Panel footer / chrome.
  - Immediate result: Applies or clears advanced filters **without changing the active queue tab**.

### Row activation

- **Row select** (desktop / mobile)
  - Location: Table row / mobile list item.
  - Opens modal: Billing detail dialog (`BillingDetailBody`).
  - Immediate result: Selects item and opens the single detail surface (actions, amounts, lines, payments, adjustments).
  - Condition: When rows exist.

- **Next action** (labeled primary row control)
  - Location: Next-action column (`billingNextActionColumnLabel`).
  - Opens modal: The mutation dialog for the item’s top allowed action (issue, receive payment, approve, submit/reconcile claim, pre-auth approve, refund, adjust, void, or send).
  - Immediate result: Completes that mutation path without opening the full detail first.
  - Condition: `billingNextActionRequirement(item)`; column omitted when the user has no mutation rights for that queue (`billingQueueShowsNextActionColumn` — Approval required needs approve ∩); absent when unauthorized for that item.

### Detail dialog (from row select)

Invoice actions (`billingWorkspaceWriteRequirement`); approve/reject (`billingApprovalDecisionRequirement`); claim/pre-auth (`billingClaimsWriteRequirement`). Progressive disclosure: financial summary, line items, payments, adjustments.

- **View ledger** — nested ledger dialog when patient id known (read chrome).
- **Print** / **Download** invoice — dialog footer when item is an invoice and `canReadBillingDocument`.
- Nested forms: receive payment, issue notes, refund, adjustment, void reason, send email, approval notes/reason, claim submit/reconcile, pre-auth notes.
- Deep link `action=pay` opens payment only when write-authorized.

### Empty / no-results / validation

- Empty queue: `billingEmptyTitle` / `billingEmptyBody`.
- Search/filter no matches: same empty panel after filter application.
- Form validation stays inside each mutation dialog; success/pending-approval/error via snackbar (`billingActionSaved` / `billingActionPendingApproval` / failure message).
- No visible queues (missing billing read / module): forbidden state for restricted access.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/billing/presentation/billing_workspace_page_test.dart`, `billing_access_test.dart`, `billing_all_permissions_test.dart`, `billing_needs_issue_permissions_test.dart`, and `billing_approval_required_permissions_test.dart` prove:
  - `BillingAllAtomPermissions` reuses read/write/approve/claims helpers; widget tests in `billing_all_permissions_test.dart` (∩ denial for read-only, ∪ route entry, subscription strip, nested Claims pending, Issue sync path, `action=pay` write gate, empty/error/retry, light/dark, mobile/desktop).
  - **Refresh** is absent from the tab strip on every queue (desktop/mobile).
  - **Close shift** is the sole primary and **Close day** the sole secondary, stable across tabs when write-authorized.
  - Unauthorized users see no Close shift / Close day / next-action controls.
  - Writer without `financial:approve` sees no Approve next-action / detail buttons; approver with both sees them.
  - `BillingApprovalRequiredAtomPermissions` reuses approve/write helpers; widget tests in `billing_approval_required_permissions_test.dart` (∩ denial for write-without-approve and financial-approve-without-write, ∪ route entry, subscription strip, nested Claims pending, approve dialog sync path, light/dark, mobile/desktop).
  - Claims pending tab and claim mutations absent without `insurance-claims`.
  - `BillingClaimsPendingAtomPermissions` reuses tab/claim-write/close/route-entry helpers; widget tests in `billing_claims_pending_permissions_test.dart` (∩ denial for read-only and missing `insurance-claims`, ∪ route entry, subscription strip, Record insurer response for SUBMITTED, pre-auth Approve/Deny, submit-claim sync path, empty/error/retry, light/dark, mobile/desktop).
  - `BillingNeedsIssueAtomPermissions` reuses read/write/issue helpers; widget tests in `billing_needs_issue_permissions_test.dart` (∩ denial for read-only, ∪ route entry, subscription strip, nested Claims pending absent/restored, nestedWrite denial without insurance, Issue mutation sync path, document Print/Download for readers, empty/error/retry, light/dark, mobile/desktop).
  - `BillingAwaitingPaymentAtomPermissions` reuses read/write/approve/claims helpers; widget tests in `billing_awaiting_payment_permissions_test.dart` (∩ denial for read-only, ∪ route entry, subscription strip, nested Claims pending, receive-payment sync path, empty/error chrome, `action=pay` write gate, light/dark, mobile/desktop).
  - `BillingOverdueAtomPermissions` reuses read/write/approve/claims helpers; widget tests in `billing_overdue_permissions_test.dart` (∩ denial for read-only, ∪ route entry, subscription strip, nested Claims pending, receive-payment sync path, empty/error chrome, `action=pay` write gate, light/dark, mobile/desktop).
  - Advanced filters omit a Queue group; clearing filters does not reset the active tab queue.
  - Finalize financial clearance is absent from next-action and detail actions.
  - Next-action and detail entry points still open for representative issue / pay paths.
  - Light + dark and mobile + desktop viewports keep authorized chrome.
