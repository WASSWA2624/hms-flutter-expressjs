# Pharmacy tab — Cancelled

## 1. Tab strip

- Label: `pharmacyDeskCancelledOrdersLabel`
- Icon: `Icons.cancel_outlined`
- Count source: `summary.cancelledOrders`
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `cancelled`
- Filter: `PharmacyOrderFilter.cancelled`
- Tab gate: reuses `PharmacyAllOrdersAtomPermissions.tab` (∩ `pharmacy:read`) — read-only history
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same order chrome (**Filters → Settings → Reports? → Walk-in?**). Export/table Print absent. Date filter enabled.

## 3. Table

- Default columns (all/cancelled set):
  1. Patient
  2. Location
  3. Items (`pharmacyItemsColumnLabel`)
  4. Status
  5. Next action
- Storage: `pharmacy_cancelled`
- Optional columns: shared set

## 4. Advanced filters / search fields

Same advanced groups + date as other order tabs.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in (create still write-gated globally)
- Row → detail primarily for read / print; cancel mutations typically not re-applicable on cancelled orders

## 6–9. Dialogs / nested / forms / print

Detail dialog still opens; mutation actions omitted when `nextActions` disallow. Print instructions when authorized.

## 10. Loading / empty / error / success

Same empty / refresh patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | All-orders read ∩ (reused for cancelled) |
| Write mutations | write ∩ when next-actions allow |
| Print | print ∩ `pharmacy:read` |
| Walk-in strip | pharmacy write ∩ |
