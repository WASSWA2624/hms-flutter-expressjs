# Billing tab — Collect due (`pendingPayment` / `collect`)

## 1. Tab strip

- Label: `billingCollectDue`
- Tooltip: `billingCollectDueTooltip`
- Icon: `Icons.payments_outlined`
- Count source: `summary.pendingPayment` (overview overdue count exists but is **not** a separate tab badge)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `collect` (aliases `pending-payment`, `awaiting-payment`)
- Overdue: filter only — `?section=collect&overdue=yes` or slug `overdue` normalizes to Collect + `overdueOnly`
- Tab gate: Collect uses entry/read maps (`BillingAwaitingPaymentAtomPermissions` / overdue filter map `BillingOverdueAtomPermissions` for overdue subset)
- **Omitted when unauthorized**
- `BillingQueueType.overdue` desk tab: **not shown**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Close day → Close shift**

- Settings key: `billing_collect_v1` (also used for overdue filter persistence)
- Export / table Print: **absent**
- Context: Close day (`billingCloseDay`), Close shift (`billingCloseShift`) — omitted without write ∩
- Charge / Issue all: **not mounted**

## 3. Table

- Default columns: Patient / Invoice / Amount due / Status / Next action (when shown)
- Column choices include Age (`billingAgeColumnId`) for Collect/overdue
- Row select → detail (Receive payment primary when due)

## 4. Advanced filters / search fields

- Groups: Source, Status (collect choices), **Overdue** (`billingOverdueFilterLabel`), Age (`billingAgeFilterLabel`)
- Text filters + issued date
- Overdue filter drives `query.overdueOnly` (not a tab)

## 5. Primary / secondary / row actions

- Strip: Close day / Close shift dialogs
- Next action Receive payment → payment dialog → receipt print
- Detail: refund / adjust (waive synonym) / void / send (dunning) when exposed + write ∩

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Billing-owned |
| Receive payment | Billing-owned |
| Refund / Adjust (+ similarity) | Billing-owned |
| Void / Send | Billing-owned |
| Close day / Close shift | Billing-owned form dialogs |
| Ledger | Billing-owned |
| Receipt print | Billing receipt helpers |

## 7. Nested / follow-on

Payment → optional receipt print; refund/adjust similarity; deep link `action=pay` write-gated.

## 8. Forms (summary)

- Payment tender / amount / method
- Refund / adjust / void / send notes
- Close day / close shift period fields

## 9. Print / labels / preview

- Table Print: **absent**
- Detail invoice Print/Download; post-payment receipt (`printBillingReceipt`)

## 10. Loading / empty / error / success

- Empty: `billingEmptyCollectDueBody` (short); overdue empty body exists for filter subset copy
- Saving disables close actions

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | awaiting-payment / entry read maps |
| Overdue filter atoms | `BillingOverdueAtomPermissions` (filter, not tab) |
| Close day / shift / Pay / Refund / Adjust / Void / Send | write ∩ |
| Approve nested | approve ∩ |
| Ledger / Print | read / document ∩ |
| Claims strip | claims pending tab |
