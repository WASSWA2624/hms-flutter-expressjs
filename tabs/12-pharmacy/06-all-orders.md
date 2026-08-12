# Pharmacy tab — All orders

## 1. Tab strip

- Label: `pharmacyFilterAll` (`All orders`)
- Icon: `Icons.receipt_long_outlined`
- Count source: `summary.totalOrders` (active tab uses filtered `workbench.orders.totalItemCount` via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all` (aliases: `all-orders`, `orders`)
- Filter: `PharmacyOrderFilter.all`
- Tab gate: `PharmacyAllOrdersAtomPermissions.tab` = ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**
- Deep-link note: some flows force `allOrders` when opening an order from outside scope

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`; date filter enabled
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_allOrders` / `pharmacy_cw_allOrders`
- Export: `commonTableExportActionLabel` — omit without ∩ `evidence:export` (`canExportPharmacyWorkspace`)
- Print: `commonPrintActionLabel` — preview-first (`printPharmacyListTable`); same export gate
- Open reports: `pharmacyOpenReportsAction` when analytics allowed
- Walk-in: `pharmacyWalkInOrderAction` — omitted without ∩ `pharmacy:write`

## 3. Table

- Default columns (**5** — all/cancelled set):
  1. Patient
  2. Location
  3. Items (`pharmacyItemsColumnLabel`)
  4. Status
  5. Next action (always visible)
- Optional columns: shared `_optionalPharmacyWorklistColumns` (Settings lists all; payment optional when billing read)

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + date.  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in (after Print; create still write-gated)
- Full detail mutation surface depending on order next-actions (dispense/attest/return/cancel/payment)
- Unauthorized actions omitted

## 6–9. Dialogs / nested / forms / print

Same as [01-queue.md](01-queue.md). Controlled-drug audit ∩ documented — **no dedicated chrome** on All orders. Print triggers use `commonPrintActionLabel`.

## 10. Loading / empty / error / success

Same patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `PharmacyAllOrdersAtomPermissions` read ∩ |
| Export / Print (table toolbar) | ∩ `evidence:export` |
| Mutations | write ∩ |
| Record payment | billing write ∩ |
| Print instructions / invoice | print ∩ `pharmacy:read` |
| Catalog nested | catalog write ∪ |
| Controlled-drug audit | pharmacy:read ∩ compliance:read — not mounted |
| Route entry | ∪ pharmacy\|operations read |
