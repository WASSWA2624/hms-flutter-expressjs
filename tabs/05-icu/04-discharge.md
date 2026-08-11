# ICU tab — Discharge ready

## 1. Tab strip

- Label: `icuDischargeReadyLabel`
- Icon: `Icons.fact_check_outlined`
- Count source: `state.dischargeReadyCount` (`isDischargePlanned`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `discharge`
- Tab gate: `IcuDischargeReadyAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**; Export / Print **absent**; no date filter.

## 3. Table

- Scope: `IcuBoardScope.discharge`
- Default columns: patient, bed, **admitted** (`icuAdmittedLabel`), status, next_action (**kept for readers** — navigate clearance)
- Row select → stay detail
- Storage: shared `'icu_board'`

## 4. Advanced filters / search fields

Same client board filters; no date.

## 5. Primary / secondary / row actions

- Next-action: `openDischargeClearance` if planned else `markReadiness`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `openIcuReadinessDialog` | ICU-owned |
| Stay detail | ICU-owned |

Deep link `panel=discharge` → readiness dialog when write allowed.

## 7. Nested / follow-on

- Clearance navigation → IPD with `panel=discharge`
- Billing / IPD from detail when authorized

## 8. Forms (summary)

- Readiness: `icuReadinessDialogTitle`, `icuReadinessDescription`, `icuReadinessNoteLabel`, `icuReadinessMarkActionLabel`

## 9. Print / labels / preview

- Table Print: **absent**; detail print summary when readable

## 10. Loading / empty / error / success

Same board feedback as Active.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / printSummary | read |
| nextActionMarkReadiness / writes | write |
| nextActionOpenDischargeClearance / openDischargeClearance / navigate | navigation |
| openBilling / billingPanel | billing read |
