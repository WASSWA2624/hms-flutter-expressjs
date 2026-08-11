# ICU tab — All ICU

## 1. Tab strip

- Label: `icuAllIcuLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `_pageTotal(board)` = `totalItemCount ?? items.length`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all`
- Tab gate: `IcuAllAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**; Export / Print **absent**; no date filter.

## 3. Table

- Scope: `IcuBoardScope.all`
- Default columns: patient, bed, source, status, next_action (same shape as Active)
- Row select → stay detail
- Storage: shared `'icu_board'`

## 4. Advanced filters / search fields

Same client board filters; no date.

## 5. Primary / secondary / row actions

- Same next-action cascade as Active (`_resolveIcuNextAction`)
- Detail complementary panel actions

## 6. Dialogs from this tab

Same stack as Active (ICU stay detail + mutation dialogs + **reused** clinical orders).

## 7. Nested / follow-on

Same as Active (IPD / billing / discharge clearance / clinical nested).

## 8. Forms (summary)

Same ICU + clinical order forms as Active.

## 9. Print / labels / preview

- Table Print: **absent**; detail print summary when readable

## 10. Loading / empty / error / success

Same board feedback as Active.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / detail / printSummary / nestedRead | read |
| Mutations / next-action writes / panelDeepLink / nestedWrite | write |
| Navigation / openIpd / openDischargeClearance | navigation |
| openBilling / billingPanel | billing read |
| routeEntry / catalogEntry | `RouteAccessCatalog.icuEntry` |
