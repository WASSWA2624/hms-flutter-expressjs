# Pharmacy tab — Queue (Ready)

## 1. Tab strip

- Label: `pharmacyDeskNewOrdersLabel`
- Icon: `Icons.medication_liquid_outlined`
- Count source: `summary.orderedQueue` (active tab may use filtered membership)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `queue`
- Filter: `PharmacyOrderFilter.ready`
- Tab gate: `PharmacyReadyAtomPermissions.tab` = ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `pharmacyQueueFilterLabel` (+ date filter enabled)
- Settings: common table settings; storage `pharmacy_queue`
- Export / table Print: **absent**
- Open reports: `pharmacyOpenReportsAction` → `/reports?dataset=pharmacy_drug_consumption` when analytics allowed
- Walk-in: `pharmacyWalkInOrderAction` — omitted without ∩ `pharmacy:write`

## 3. Table

- Row model: `PharmacyOrder`
- Row select → order detail dialog
- Default columns:
  1. Patient (`pharmacyPatientColumnLabel`) — subtitle display id
  2. Location (`pharmacyLocationFieldLabel`)
  3. Dispense progress (`pharmacyDispenseColumnLabel`)
  4. Status (`pharmacyStatusColumnLabel`)
  5. Next action (`pharmacyNextActionColumnLabel`)
- Column choices (Settings): Order, Items, Dispense progress, Payment (if billing read), Ordered at, Patient ID, Encounter, Priority, Prescriber, Order source, Pending attestation, Remaining qty, (+ other optional ids in `_optionalPharmacyWorklistColumns`)

## 4. Advanced filters / search fields

- Groups: Location, Priority, Partial stock, Urgent
- Date range on order date
- Search: `pharmacyOrderSearchMatcher`

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in
- Next action / detail: Dispense, Attest, Return, Cancel, Record payment (when eligible) — omitted when unauthorized
- Payment-before-dispense can block Dispense until billing write records payment

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Order detail | Pharmacy-owned |
| Dispense / Dispense all / batch | Pharmacy-owned |
| Attest | Pharmacy-owned |
| Return (+ edit line) | Pharmacy-owned |
| Cancel order / cancel item | Pharmacy-owned |
| Walk-in order | Pharmacy-owned |
| Record payment | **reused** billing |
| Print instructions / invoice / batch | Pharmacy print helpers |

## 7. Nested / follow-on

Detail → items panel → line Dispense / Cancel item; Dispense history → batch dialog → print batch HTML; Return → line edit dialog; Cancel → `PharmacyCancelReasonsSection`; Walk-in → created order detail; Record payment → billing receive-payment flow.

## 8. Forms (summary)

- Dispense lines: qty / pack / stock map / price source
- Attest: guidance + confirm
- Return: return qty per line
- Cancel: multi-select cancel reasons + notes
- Walk-in: patient / items / OTC order fields
- Payment: billing payment draft fields (**reused**)

## 9. Print / labels / preview

- Table Print: **absent**
- Detail: Print instructions (`pharmacyPrintInstructionsAction`) when ∩ `pharmacy:read`
- Dispense batch print; order invoice helpers when invoked from print options sections
- No desk-level label chrome beyond helpers

## 10. Loading / empty / error / success

- Loading: `state.isRefreshingOrders` on table
- Empty: `pharmacyNoOrdersTitle` / `pharmacyNoOrdersBody`
- Success: walk-in snackbar; mutation snackbars
- Failures: snackbars / dialog banners

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action view | `PharmacyReadyAtomPermissions` read ∩ |
| Dispense / Attest / Return / Cancel / Walk-in | write ∩ `pharmacy:write` |
| Record payment | billing write ∩ (`pharmacyRecordPaymentRequirement`) |
| Payment column (optional) | billing read ∩ |
| Print instructions / invoice | print ∩ `pharmacy:read` |
| Open reports | pharmacy read + `reports:read` + reporting module |
| Catalog CRUD (from nested) | catalog write ∪ |
| Controlled-drug audit | documented ∩ — **no dedicated chrome** on Ready |
| Route entry | ∪ pharmacy\|operations read |
