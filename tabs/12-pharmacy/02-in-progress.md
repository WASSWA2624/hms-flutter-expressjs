# Pharmacy tab — In progress (Partial)

## 1. Tab strip

- Label: `pharmacySummaryPartialLabel` (`Partial`)
- Icon: `Icons.pending_actions_outlined`
- Count source: `summary.partiallyDispensedQueue` (active tab uses filtered `workbench.orders.totalItemCount` via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `in-progress` (aliases: `partial`, `in_progress`)
- Filter: `PharmacyOrderFilter.partial`
- Tab gate: `PharmacyPartialAtomPermissions.tab` = ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open reports? → Walk-in order?**

- Search: `pharmacySearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`; date filter enabled
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_inProgress` / `pharmacy_cw_inProgress`
- Export: `commonTableExportActionLabel` — omit without ∩ `evidence:export` (`canExportPharmacyWorkspace`)
- Print: `commonPrintActionLabel` — preview-first (`printPharmacyListTable`); same export gate
- Open reports: `pharmacyOpenReportsAction` when analytics allowed
- Walk-in: `pharmacyWalkInOrderAction` — omitted without ∩ `pharmacy:write`

## 3. Table

- Same default column set as Queue (**5**): Patient / Location / Dispense progress / Status / Next action (always visible)
- Optional columns: shared `_optionalPharmacyWorklistColumns` (Settings lists all)

## 4. Advanced filters / search fields

Same Location / Priority / Partial stock / Urgent + order date.  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

Same strip + detail mutation set as Queue (partial fills emphasize remaining dispense / attest). Unauthorized actions omitted.

## 6–9. Dialogs / nested / forms / print

Same Pharmacy-owned detail / dispense / attest / return / cancel / walk-in / payment / print chain as [01-queue.md](01-queue.md). Print triggers use `commonPrintActionLabel`. Owners unchanged.

## 10. Loading / empty / error / success

Same empty / refresh / snackbar patterns as Queue.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `PharmacyPartialAtomPermissions` read ∩ |
| Export / Print (table toolbar) | ∩ `evidence:export` |
| Mutations / Walk-in | write ∩ |
| Record payment | billing write ∩ |
| Print instructions / invoice | print ∩ `pharmacy:read` |
| Reports | analytics gate |
| Controlled-drug audit | documented ∩ — **no dedicated chrome** |
| Route entry | ∪ pharmacy\|operations read |
