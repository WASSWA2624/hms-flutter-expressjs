# ICU tab — Critical

## 1. Tab strip

- Label: `icuCriticalAlertsLabel`
- Icon: `Icons.priority_high_outlined`
- Count source: `state.criticalCount` (`hasCriticalAlert`)
- Sibling tabs: page-derived scope counts
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `critical`
- Tab gate: `IcuCriticalAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Same as Active; Export / Print / strip context **absent**
- Date filter: **not present**

## 3. Table

- Row model: `IcuPatientSummary`; scope `IcuBoardScope.critical`
- Row select → stay detail
- Default columns: patient, bed, **alert** (`icuColumnAlertLabel`), status, next_action (column mounts when write allowed)
- Critical rows tinted via `errorContainer`
- Storage: shared `'icu_board'`

## 4. Advanced filters / search fields

Same client board filters as Active (alert / bed / source); no date.

## 5. Primary / secondary / row actions

- Next-action: `acknowledgeAlert` when `hasCriticalAlert`
- Detail complementary actions (raise alert, observations, orders, …)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail | ICU-owned |
| Alert dialog (`openIcuAlertDialog`) | ICU-owned |
| Other ICU mutation dialogs | ICU-owned |
| Clinical order / Rx | **reused** |

Deep link `panel=alerts` → alert dialog when write allowed.

## 7. Nested / follow-on

Same as Active (IPD / billing / discharge clearance / clinical nested).

## 8. Forms (summary)

- Alert raise/acknowledge; shared ICU mutation forms when eligible

## 9. Print / labels / preview

- Table Print: **absent**
- Stay detail print summary (clinicalSummary) when readable

## 10. Loading / empty / error / success

Same board feedback as Active (`icuNoPatients*`, `icuChangesSavedMessage`).

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / alertColumn / detail / printSummary | read |
| nextActionAcknowledge / acknowledgeAlert / raiseAlert / panelDeepLink / writes | write |
| navigate / openIpd / openDischargeClearance | `icuNavigationRequirement` |
| openBilling / billingPanel | billing read |
