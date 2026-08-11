# Pharmacy tab — All orders

## 1. Tab strip

- Label: `pharmacyFilterAll`
- Icon: `Icons.receipt_long_outlined`
- Count source: `summary.totalOrders`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all`
- Filter: `PharmacyOrderFilter.all`
- Tab gate: `PharmacyAllOrdersAtomPermissions.tab` = ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Deep-link note: some flows force `allOrders` when opening an order from outside scope

## 2. Search / Filters / Settings / Export / Print / context

Same order chrome as Queue. Export/table Print absent. Date filter enabled.

## 3. Table

- Default columns: Patient / Location / Items / Status / Next action (same as Cancelled)
- Storage: `pharmacy_allOrders`
- Optional columns: shared set (payment optional when billing read)

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + date.

## 5. Primary / secondary / row actions

Full strip + detail mutation surface depending on order next-actions (dispense/attest/return/cancel/payment).

## 6–9. Dialogs / nested / forms / print

Same as [01-queue.md](01-queue.md). Controlled-drug audit ∩ documented — **no dedicated chrome** on All orders.

## 10. Loading / empty / error / success

Same patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `PharmacyAllOrdersAtomPermissions` read ∩ |
| Mutations | write ∩ |
| Record payment | billing write ∩ |
| Print | print ∩ |
| Catalog nested | catalog write ∪ |
| Controlled-drug audit | pharmacy:read ∩ compliance:read — not mounted |
