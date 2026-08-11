# Pharmacy tab — In progress (Partial)

## 1. Tab strip

- Label: `pharmacySummaryPartialLabel`
- Icon: `Icons.pending_actions_outlined`
- Count source: `summary.partiallyDispensedQueue`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `in-progress`
- Filter: `PharmacyOrderFilter.partial`
- Tab gate: `PharmacyPartialAtomPermissions.tab` = ∩ `pharmacy:read`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same order chrome as Queue: **Filters → Settings → Reports? → Walk-in?**

- Export / table Print: **absent**
- Date filter: **enabled**

## 3. Table

- Same default column set as Queue (Patient / Location / Dispense progress / Status / Next action)
- Storage: `pharmacy_inProgress`
- Optional columns: shared `_optionalPharmacyWorklistColumns`

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + order date.

## 5. Primary / secondary / row actions

Same strip + detail mutation set as Queue (partial fills emphasize remaining dispense / attest).

## 6–9. Dialogs / nested / forms / print

Same Pharmacy-owned detail / dispense / attest / return / cancel / walk-in / payment / print chain as [01-queue.md](01-queue.md). Owners unchanged.

## 10. Loading / empty / error / success

Same empty / refresh / snackbar patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `PharmacyPartialAtomPermissions` read ∩ |
| Mutations / Walk-in | write ∩ |
| Record payment | billing write ∩ |
| Print | print ∩ `pharmacy:read` |
| Reports | analytics gate |
