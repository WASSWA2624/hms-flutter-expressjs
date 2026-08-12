# Pharmacy tab — Cancelled

## 1. Tab strip

- Label: `pharmacyDeskCancelledOrdersLabel` (`Cancelled orders`)
- Icon: `Icons.cancel_outlined`
- Count source: `summary.cancelledOrders` (active tab uses filtered `workbench.orders.totalItemCount` via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `cancelled` (alias: `canceled`)
- Filter: `PharmacyOrderFilter.cancelled`
- Tab gate: reuses `PharmacyAllOrdersAtomPermissions.tab` (∩ `pharmacy:read` + `pharmacy-dispensing`) — read-only history
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`; date filter enabled
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_cancelled` / `pharmacy_cw_cancelled`
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
- Optional columns: shared `_optionalPharmacyWorklistColumns` (Settings lists all)

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + date.  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in (after Print; create still write-gated)
- Row → detail primarily for read / print; cancel mutations typically not re-applicable on cancelled orders
- Unauthorized actions omitted

## 6–9. Dialogs / nested / forms / print

Detail dialog still opens; mutation actions omitted when `nextActions` disallow. Print triggers use `commonPrintActionLabel`.

## 10. Loading / empty / error / success

Same empty / refresh patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | All-orders read ∩ (reused for cancelled) |
| Export / Print (table toolbar) | ∩ `evidence:export` |
| Write mutations | write ∩ when next-actions allow |
| Print instructions / invoice | print ∩ `pharmacy:read` |
| Walk-in strip | pharmacy write ∩ |
| Route entry | ∪ pharmacy\|operations read |
