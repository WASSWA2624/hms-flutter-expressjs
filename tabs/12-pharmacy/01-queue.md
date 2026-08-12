# Pharmacy tab — Queue (Ready)

## 1. Tab strip

- Label: `pharmacyDeskNewOrdersLabel`
- Icon: `Icons.medication_liquid_outlined`
- Count source: `summary.orderedQueue` (active tab uses filtered `workbench.orders.totalItemCount` via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `queue` (aliases: `ready`, `new`, `new-orders`, `dispense`)
- Filter: `PharmacyOrderFilter.ready`
- Tab gate: `PharmacyReadyAtomPermissions.tab` = ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`; date filter enabled
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_queue` / `pharmacy_cw_queue`
- Export: `commonTableExportActionLabel` — omit without ∩ `evidence:export` (`canExportPharmacyWorkspace`)
- Print: `commonPrintActionLabel` — preview-first (`printPharmacyListTable`); same export gate
- Open reports: `pharmacyOpenReportsAction` → `/reports?dataset=pharmacy_drug_consumption` when analytics allowed
- Walk-in: `pharmacyWalkInOrderAction` — omitted without ∩ `pharmacy:write`

## 3. Table

- Row model: `PharmacyOrder`
- Row select → order detail dialog
- Default columns (**5**):
  1. Patient (`pharmacyPatientColumnLabel`) — subtitle display id
  2. Location (`pharmacyLocationFieldLabel`)
  3. Dispense progress (`pharmacyDispenseColumnLabel`)
  4. Status (`pharmacyStatusColumnLabel`)
  5. Next action (`pharmacyNextActionColumnLabel`) — always visible
- Column choices (Settings): Order, Items, Dispense progress, Payment (if billing read), Ordered at, Patient ID, Encounter, Priority, Prescriber, Order source, Pending attestation, Remaining qty, (+ other optional ids in `_optionalPharmacyWorklistColumns`)

## 4. Advanced filters / search fields

- Groups: Location, Priority, Partial stock, Urgent
- Date range on order date
- Search: `pharmacyOrderSearchMatcher`
- Footer: Clear filters → Apply filters → Close

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in (after Print)
- Next action / detail: Dispense, Attest, Return, Cancel, Record payment (when eligible) — omitted when unauthorized
- Payment-before-dispense can block Dispense until billing write records payment

## 6. Dialogs from this tab

| Dialog | Owner | Title key / notes |
| --- | --- | --- |
| Order detail | Pharmacy-owned | `pharmacyPrescriptionDetailTitle` (surface type) |
| Dispense / Dispense all / batch | Pharmacy-owned | `pharmacyDispenseDialogTitle` |
| Attest | Pharmacy-owned | |
| Return (+ edit line) | Pharmacy-owned | |
| Cancel order / cancel item | Pharmacy-owned | `pharmacyCancelDialogTitle` |
| Walk-in order | Pharmacy-owned | `pharmacyWalkInOrderDialogTitle` (`Create order`) |
| Record payment | **reused** billing | |
| Print instructions / invoice / batch | Pharmacy print helpers | trigger `commonPrintActionLabel` |

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

- Table Print: present after Export when `canPrintPharmacyWorkspace`; preview-first
- Detail: Print (`commonPrintActionLabel`) when ∩ `pharmacy:read`
- Dispense batch / history Print; order invoice helpers when invoked from print options sections
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
| Export / Print (table toolbar) | ∩ `evidence:export` |
| Dispense / Attest / Return / Cancel / Walk-in | write ∩ `pharmacy:write` |
| Record payment | billing write ∩ (`pharmacyRecordPaymentRequirement`) |
| Payment column (optional) | billing read ∩ |
| Print instructions / invoice | print ∩ `pharmacy:read` |
| Open reports | pharmacy read + `reports:read` + reporting module |
| Catalog CRUD (from nested) | catalog write ∪ |
| Controlled-drug audit | documented ∩ — **no dedicated chrome** on Ready |
| Route entry | ∪ pharmacy\|operations read |
