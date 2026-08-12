# ICU tab — Transfers

## 1. Tab strip

- Label: `icuTransfersLabel`
- Icon: `Icons.compare_arrows_outlined`
- Count source: `state.transferCount` ← `scopeCounts.transfers` (server `totalItemCount` for `IcuBoardScope.transfer`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered membership (search → board `totalItemCount`; option/date filters → client filter of current page)
- Sibling tabs: dedicated unfiltered `IcuScopeCounts`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `transfers`
- Tab gate: `IcuTransfersAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

- Search hint: `icuSearchHint` (submit/clear → `applySearch`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close = Reset columns / Apply columns / Close
- Export: `commonTableExportActionLabel` gated by `canExportIcuWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintIcuWorkspace`; preview-first `printIcuWorkspaceList`
- Context strip actions: **none**
- Date filter: admitted-at (`ipdAdmittedAtColumnLabel`) — shared board filter chrome

## 3. Table

- Row model: `IcuPatientSummary` via `IcuBoardPanel`
- Scope: `IcuBoardScope.transfer` (section enum `transfers`)
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns (≤5): Patient, Bed, Transfer, Status, Next action (Next action **omitted** without write — Critical/Transfers write-only next-action column)
- Column choices (Settings): alert, source, icu_start, admitted, encounter (plus defaults when not already visible)
- Storage keys: `'icu_transfers'` / `'icu_cw_transfers'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`) + date range on `admittedAt`
- Client-side filter on current page for option/date groups; search reloads server scope
- Transfers badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Strip context: none
- Next-action cell: `manageTransfer` when `hasOpenTransfer`, else `requestTransfer`; workflow `nextStep` wins when registered
- Row select → stay detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail (`ICU stay`) | ICU-owned `IcuStayDetailPanel` |
| `openIcuTransferDialog` / `AppTransferRequestDialog` | ICU + **reused** shared |
| `openIcuManageTransferDialog` | ICU-owned |
| Other ICU mutation dialogs / clinical orders | ICU-owned / **reused** clinical |

Deep link `panel=transfer` → transfer dialog when write allowed.

## 7. Nested / follow-on

- After complete → `promptIcuEndStayAfterStepDown` confirm
- Empty manage: `icuTransferNoOpenLabel`
- From stay detail: Open IPD / Open billing; Print (`commonPrintActionLabel`); complementary writes

## 8. Forms (summary)

- Transfer request: target ward (`icuTransferDialogTitle`, `icuTransferTargetWardLabel`, …); no tenant/facility/session fields
- Manage: approve / start / complete / cancel (`icuTransferAction*`); complete may require bed; dependent field resets on ward change

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList`
- Stay detail Print: `commonPrintActionLabel` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Board empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Workspace load/retry: `AsyncStateScaffold` + `IcuWorkspaceController.refresh`
- Mutations refresh board + sibling `scopeCounts` (incl. transfers badge)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / transfer column / row select | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Manage / Request transfer + write mutations | `icuWorkspaceWriteRequirement` |
| Nested billing | ∩ `billing:read` + `billing-payments` |
| Open IPD / discharge clearance | `icuNavigationRequirement` |
| `panel=transfer` deep link | `icuFocusedPanelRequirement` (write) |
| Route entry | catalog ∩ `icu:read` + module |
