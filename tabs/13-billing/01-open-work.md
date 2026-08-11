# Billing tab — Open work (`all` / `work`)

## 1. Tab strip

- Label: `billingOpenWork`
- Tooltip: `billingOpenWorkTooltip`
- Icon: `Icons.inventory_2_outlined`
- Count source: `summary.countFor(all)` / workload
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `work` (aliases `all`, `inbox`)
- Tab gate: `BillingAllAtomPermissions.tab` / `billingWorkspaceEntryRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Charge**

- Filters label: `billingFiltersLabel`; date: `billingIssuedDateFilterLabel`
- Settings: `billing_work_v1`
- Export / table Print: **absent**
- Context: Charge (`billingChargeAction` / `billingChargeTooltip`) — omitted without ∩ `billing:write`
- Close shift/day / Issue all: **not mounted** here

## 3. Table

- Row model: `BillingWorkItem`
- Row select → detail dialog
- Default columns:
  1. Patient
  2. Invoice
  3. Amount due
  4. Status
  5. Next action — only if `billingQueueShowsNextActionColumn` (write / approve / claims)
- Column choices: non-default builders excluding approval-only / claims-only / next-action ids (encounter, source, paid, updated, age when applicable, …)

## 4. Advanced filters / search fields

- Groups: Source (`billingSourceFilterLabel`), Status (open-work choices)
- Text filters: patient / invoice / encounter
- Date range on issued date
- Overdue filter group: **not** on Open work (Collect owns it)

## 5. Primary / secondary / row actions

- Strip: Charge → quick charge → similarity → may land To issue
- Next action: Issue / Pay / Approve / claim actions per item gates
- Deep link `action=pay` write-gated

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Billing-owned |
| Quick charge + similarity | Billing-owned |
| Issue / Pay / Refund / Adjust / Void / Send | Billing-owned |
| Approve / Reject | Billing-owned (approve ∩) |
| Claim / pre-auth | Billing-owned (claims write) |
| Ledger | Billing-owned |

## 7. Nested / follow-on

Detail → mutation dialogs → similarity where applicable → receipt print after payment; Charge success → switch to To issue queue.

## 8. Forms (summary)

- Charge: patient / lines / amounts
- Issue notes; payment tender; refund/adjust/void/send notes; approval notes; claim submit/reconcile/pre-auth fields

## 9. Print / labels / preview

- Table Print: **absent**
- Detail: Print/Download invoice; claim/pre-auth statement; approval packet when kind matches + document read ∩
- After payment: `printBillingReceipt`

## 10. Loading / empty / error / success

- Empty: short copy `billingEmptyBody` as title
- Loading / retry via scaffold; saving disables trailing Charge

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | entry / All atom map |
| Charge / Issue / Pay / Refund / Adjust / Void / Send | write ∩ |
| Approve / Reject | write ∩ financial:approve |
| Claim mutations | claims write ∩ |
| Ledger | read / nested claims read by kind |
| Print/Download | document read ∩ |
| Claims pending strip | insurance-claims tab requirement |
