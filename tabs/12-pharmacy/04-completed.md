# Pharmacy tab — Completed

## 1. Tab strip

- Label: `pharmacyDeskCompletedOrdersLabel` (`Completed orders`)
- Icon: `Icons.done_all_outlined`
- Count source: `summary.dispensedOrders` (active tab uses filtered `workbench.orders.totalItemCount` via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `completed` (alias: `dispensed`)
- Filter: `PharmacyOrderFilter.completed`
- Tab gate: `PharmacyCompletedAtomPermissions.tab` = ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`; date filter enabled
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_completed` / `pharmacy_cw_completed`
- Export: `commonTableExportActionLabel` — omit without ∩ `evidence:export` (`canExportPharmacyWorkspace`)
- Print: `commonPrintActionLabel` — preview-first (`printPharmacyListTable`); same export gate
- Open reports: `pharmacyOpenReportsAction` when analytics allowed
- Walk-in: `pharmacyWalkInOrderAction` — omitted without ∩ `pharmacy:write`

## 3. Table

- Default columns (**5**): Patient / Location / Dispense progress / Status / Next action (always visible)
- Optional columns: shared `_optionalPharmacyWorklistColumns` (Settings lists all)

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + date.  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in (after Print)
- Detail often emphasizes Print / Return / Attest residual; Dispense omitted when not preparable
- Unauthorized actions omitted

## 6–9. Dialogs / nested / forms / print

Same Pharmacy-owned + billing-reuse surfaces as [01-queue.md](01-queue.md). Print triggers use `commonPrintActionLabel`. Print instructions common on completed fills.

## 10. Loading / empty / error / success

Same patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `PharmacyCompletedAtomPermissions` read ∩ |
| Export / Print (table toolbar) | ∩ `evidence:export` |
| Mutations | write ∩ |
| Record payment | billing write ∩ |
| Print instructions / invoice | print ∩ `pharmacy:read` |
| Controlled-drug audit | documented ∩ — **no dedicated chrome** |
| Route entry | ∪ pharmacy\|operations read |
