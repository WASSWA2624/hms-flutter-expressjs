# ICU tab — Transfers

## 1. Tab strip

- Label: `icuTransfersLabel`
- Icon: `Icons.compare_arrows_outlined`
- Count source: `state.transferCount` (`hasOpenTransfer`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `transfers`
- Tab gate: `IcuTransfersAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**; Export / Print **absent**; no date filter.

## 3. Table

- Scope: `IcuBoardScope.transfer`
- Default columns: patient, bed, **transfer** (`icuColumnTransferLabel`), status, next_action (write-gated mount)
- Row select → stay detail
- Storage: shared `'icu_board'`

## 4. Advanced filters / search fields

Same client board filters; no date.

## 5. Primary / secondary / row actions

- Next-action: `manageTransfer` if open transfer else `requestTransfer`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `openIcuTransferDialog` / `AppTransferRequestDialog` | ICU + **reused** shared |
| `openIcuManageTransferDialog` | ICU-owned |
| Stay detail | ICU-owned |

Deep link `panel=transfer` → transfer dialog when write allowed.

## 7. Nested / follow-on

- After complete → `promptIcuEndStayAfterStepDown` confirm
- Empty manage: `icuTransferNoOpenLabel`
- IPD / billing from detail

## 8. Forms (summary)

- Transfer: target ward (`icuTransferDialogTitle`, `icuTransferTargetWardLabel`, …)
- Manage: approve / start / complete / cancel (`icuTransferAction*`); complete may require bed

## 9. Print / labels / preview

- Table Print: **absent**; detail print summary when readable

## 10. Loading / empty / error / success

Same board feedback as Active.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / transferColumn / list chrome / detail / printSummary | read |
| nextActionManageTransfer / nextActionRequestTransfer / manageTransfer / requestTransfer / writes | write |
| navigate / openIpd / openDischargeClearance | navigation |
| openBilling / billingPanel | billing read |
