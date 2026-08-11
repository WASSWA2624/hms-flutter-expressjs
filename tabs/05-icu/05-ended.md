# ICU tab — Ended stays

## 1. Tab strip

- Label: `icuEndedStaysLabel`
- Icon: `Icons.output_outlined`
- Count source: page items with `isEndedIcu`.length
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `ended`
- Tab gate: `IcuEndedStaysAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**; Export / Print **absent**; no date filter.

## 3. Table

- Scope: `IcuBoardScope.ended`
- Default columns: patient, bed, **icu_start** (`icuColumnStartLabel`), status, next_action (readers keep column)
- Row select → stay detail
- Storage: shared `'icu_board'`

## 4. Advanced filters / search fields

Same client board filters; no date.

## 5. Primary / secondary / row actions

- Next-action: always `openIpd`
- Detail may still expose eligible writes via `canRecordIcuAction`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail | ICU-owned |
| Eligible ICU mutation dialogs | ICU-owned |
| Clinical order / Rx | **reused** |

## 7. Nested / follow-on

- Open IPD navigation
- Billing when authorized

## 8. Forms (summary)

- Same ICU mutation forms when still eligible for the stay

## 9. Print / labels / preview

- Table Print: **absent**; detail print summary when readable

## 10. Loading / empty / error / success

Same board feedback as Active.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / printSummary | read |
| Mutations | write |
| nextAction / nextActionOpenIpd | `icuNavigationRequirement` |
| openBilling / billingPanel | billing read |
