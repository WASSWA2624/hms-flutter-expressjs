# Radiology tab — All orders

## 1. Tab strip

- Label: `radiologyAllOrdersSummaryLabel`
- Icon: `Icons.assignment_outlined`
- Count source: sibling `state.historyCount`; when active, `state.orders.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all` (aliases `all_orders`, `all-orders`, `history`, `order-history`, `order_history`)
- Stage applied: `HISTORY`
- Tab gate: `RadiologyAllOrdersAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same order-board chrome as Worklist: **Filters → Settings → Request imaging**

- Export / table Print: **absent**
- Request imaging omitted without ∩ `radiology:write`

## 3. Table

- Same `RadiologyOrder` board and column sets as Worklist
- Unfiltered history scope via `applyStage('HISTORY')`
- Storage: `radiology_allOrders_<view>`

## 4. Advanced filters / search fields

Same as Worklist (including optional billing gate).

## 5. Primary / secondary / row actions

- Strip: Request imaging
- Row / next-action → detail / print / report shortcuts by status
- Assign / Start imaging: **not mounted**

## 6. Dialogs from this tab

Same as Worklist (detail, report, print, cancel, request imaging, configurations-not-strip).

## 7. Nested / follow-on

Same chains as Worklist.

## 8. Forms (summary)

Same as Worklist.

## 9. Print / labels / preview

- Table Print: **absent**
- Detail Print report → `PrintDocumentTemplates.clinicalResult`

## 10. Loading / empty / error / success

Same as Worklist.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `RadiologyAllOrdersAtomPermissions.*` read ∩ |
| Mutations / Request imaging / configure | write ∩ |
| Billing filter/column | billing hold ∩ |
| Print report | print ∩ `radiology:read` |
