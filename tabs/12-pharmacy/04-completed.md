# Pharmacy tab — Completed

## 1. Tab strip

- Label: `pharmacyDeskCompletedOrdersLabel`
- Icon: `Icons.done_all_outlined`
- Count source: `summary.dispensedOrders`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `completed`
- Filter: `PharmacyOrderFilter.completed`
- Tab gate: `PharmacyCompletedAtomPermissions.tab` = ∩ `pharmacy:read`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same order chrome as Queue (**Filters → Settings → Reports? → Walk-in?**). Export/table Print absent. Date filter enabled.

## 3. Table

- Default columns: Patient / Location / Dispense progress / Status / Next action (same as Queue)
- Storage: `pharmacy_completed`
- Optional columns: shared set

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + date.

## 5. Primary / secondary / row actions

- Strip: Reports / Walk-in
- Detail often emphasizes Print / Return / Attest residual; Dispense omitted when not preparable

## 6–9. Dialogs / nested / forms / print

Same Pharmacy-owned + billing-reuse surfaces as [01-queue.md](01-queue.md). Print instructions common on completed fills.

## 10. Loading / empty / error / success

Same patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `PharmacyCompletedAtomPermissions` read ∩ |
| Mutations | write ∩ |
| Record payment | billing write ∩ |
| Print | print ∩ `pharmacy:read` |
