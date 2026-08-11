# Pharmacy tab — Pending payment

## 1. Tab strip

- Label: `pharmacyFilterPendingPayment`
- Icon: `Icons.payments_outlined`
- Count source: `summary.pendingPaymentQueue`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `pending-payment`
- Filter: `PharmacyOrderFilter.pendingPayment`
- Tab gate: `PharmacyPendingPaymentAtomPermissions.tab` = ∩ `pharmacy:read` + `billing:read`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same order chrome: **Filters → Settings → Reports? → Walk-in?**

- Export / table Print: **absent**
- Date filter: **enabled**
- Walk-in still ∩ `pharmacy:write` when mounted

## 3. Table

- Default columns (differs from Queue):
  1. Patient
  2. Payment (`pharmacyPaymentColumnLabel`) — **only if** `canReadPharmacyBillingStatus` (∩ `billing:read`)
  3. Ordered at (`pharmacyOrderedAtColumn` / ordered-at label)
  4. Status
  5. Next action (often confirm billing / record payment guidance)
- Storage: `pharmacy_pendingPayment`
- Optional columns: shared optional set (payment column gated)

## 4. Advanced filters / search fields

Same advanced groups + date as other order tabs.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in
- Detail emphasizes Record payment (**reused** billing) when `pharmacyRecordPaymentRequirement` allows
- Dispense may remain blocked while payment required

## 6. Dialogs from this tab

Same detail / dispense / attest / return / cancel / walk-in set; Record payment is the primary billing handoff (**reused**).

## 7. Nested / follow-on

Payment dialog → billing receive-payment / clearance fields (`pharmacyPaymentClearanceFieldLabel`, amount labels in helpers).

## 8. Forms (summary)

- Payment: billing draft / clearance / amount (**reused**)
- Other mutation forms same as Queue when eligible

## 9. Print / labels / preview

- Table Print: **absent**
- Detail print instructions when ∩ `pharmacy:read`

## 10. Loading / empty / error / success

Same as Queue; empty uses shared no-orders copy.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | ∩ `pharmacy:read` + `billing:read` |
| Payment column | billing read ∩ |
| Record payment | billing write ∩ |
| Dispense / other pharmacy mutations | pharmacy write ∩ |
| Print | pharmacy read ∩ |
| Walk-in | pharmacy write ∩ |
