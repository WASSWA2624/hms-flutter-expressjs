# Radiology tab — All orders

## 1. Tab strip

- Label: `radiologyAllOrdersSummaryLabel` → `Order history`
- Icon: `Icons.assignment_outlined`
- Count source: sibling `state.historyCount` (unfiltered summary); when active + narrowed, `state.orders.totalItemCount` via `radiologySectionTabCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all` (aliases `all_orders`, `all-orders`, `history`, `order-history`, `order_history`)
- Stage applied: `HISTORY`
- Tab gate: `RadiologyAllOrdersAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Request imaging**

- Labels / date filter / Export+Print gates: identical to [01-worklist.md](01-worklist.md)
  - Filters: `commonFiltersActionLabel`; Apply / Clear / Close shared footers
  - Settings: `commonTableSettings*`; Close `commonCloseActionLabel`
  - Export: ∩ `evidence:export` (`RadiologyAllOrdersAtomPermissions.export`)
  - Print: `commonPrintActionLabel` → preview-first `printRadiologyWorkspaceList`; same export gate
- Request imaging omitted without ∩ `radiology:write`

## 3. Table

- Same `RadiologyOrder` board, **5** default columns, and billing-optional column as Worklist
- History scope via `applyStage('HISTORY')`
- Storage: `radiology_allOrders_<view>` / `radiology_cw_…`

## 4. Advanced filters / search fields

Same as Worklist (Stage / Status / Modality / Priority / optional Billing gate + ordered date). Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip: Request imaging
- Row / next-action → detail / print / report shortcuts by status
- Assign / Start imaging: **not mounted**

## 6. Dialogs from this tab

Same as Worklist (detail, report composer, print preview, cancel, request imaging, configurations-not-strip). Print dialog title: `printPreviewTitle`.

## 7. Nested / follow-on

Same chains as Worklist.

## 8. Forms (summary)

Same as Worklist.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first list print (gated ∩ `evidence:export`)
- Detail / reported next-action: `Print` → `printPreviewTitle` → `PrintDocumentTemplates.clinicalResult`

## 10. Loading / empty / error / success

Same as Worklist (scaffold retry; mutation snackbars).

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / search / filters / settings | `RadiologyAllOrdersAtomPermissions.*` read ∩ |
| Desk Export / table Print | ∩ `evidence:export` |
| Mutations / Request imaging / configure | write ∩ |
| Billing filter/column | billing hold ∩ |
| Print report (detail/composer) | print ∩ `radiology:read` |
| Request-from-clinical | clinical radiology ∪ (not strip) |
| Deep-link entry | ∪ radiology\|clinical\|billing |
