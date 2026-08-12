# Pharmacy tab — Pending payment

## 1. Tab strip

- Label: `pharmacyFilterPendingPayment` (`Pending payment`)
- Icon: `Icons.payments_outlined`
- Count source: `summary.pendingPaymentQueue` (active tab uses filtered `workbench.orders.totalItemCount` via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `pending-payment` (aliases: `payment`, `pending_payment`)
- Filter: `PharmacyOrderFilter.pendingPayment`
- Tab gate: `PharmacyPendingPaymentAtomPermissions.tab` = ∩ `pharmacy:read` + `billing:read`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`; date filter enabled
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_pendingPayment` / `pharmacy_cw_pendingPayment`
- Export: `commonTableExportActionLabel` — omit without ∩ `evidence:export` (`canExportPharmacyWorkspace`)
- Print: `commonPrintActionLabel` — preview-first (`printPharmacyListTable`); same export gate
- Open reports: `pharmacyOpenReportsAction` when analytics allowed
- Walk-in: `pharmacyWalkInOrderAction` — omitted without ∩ `pharmacy:write`

## 3. Table

- Default columns (**5** when billing read present — tab gate requires it):
  1. Patient
  2. Payment (`pharmacyPaymentColumnLabel`) — **only if** `canReadPharmacyBillingStatus` (∩ `billing:read`)
  3. Ordered at (`pharmacyOrderedAtColumn`)
  4. Status
  5. Next action (often confirm billing / record payment guidance) — always visible
- Optional columns: shared optional set (payment column gated)

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + order date.  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in (after Print)
- Detail emphasizes Record payment (**reused** billing) when `pharmacyRecordPaymentRequirement` allows
- Dispense may remain blocked while payment required
- Unauthorized actions omitted

## 6. Dialogs from this tab

Same detail / dispense / attest / return / cancel / walk-in set; Record payment is the primary billing handoff (**reused**). Titles remain surface-type generics.

## 7. Nested / follow-on

Payment dialog → billing receive-payment / clearance fields (`pharmacyPaymentClearanceFieldLabel`, amount labels in helpers).

## 8. Forms (summary)

- Payment: billing draft / clearance / amount (**reused**)
- Other mutation forms same as Queue when eligible

## 9. Print / labels / preview

- Table Print: present after Export when `canPrintPharmacyWorkspace`; preview-first
- Detail Print (`commonPrintActionLabel`) when ∩ `pharmacy:read`

## 10. Loading / empty / error / success

Same as Queue; empty uses shared no-orders copy.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | ∩ `pharmacy:read` + `billing:read` |
| Export / Print (table toolbar) | ∩ `evidence:export` |
| Payment column | billing read ∩ |
| Record payment | billing write ∩ |
| Dispense / other pharmacy mutations | pharmacy write ∩ |
| Print instructions / invoice | pharmacy read ∩ |
| Walk-in | pharmacy write ∩ |
| Controlled-drug audit | documented ∩ — **no dedicated chrome** |
| Route entry | ∪ pharmacy\|operations read |
