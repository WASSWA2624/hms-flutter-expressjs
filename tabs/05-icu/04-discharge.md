# ICU tab — Discharge ready

## 1. Tab strip

- Label: `icuDischargeReadyLabel`
- Icon: `Icons.fact_check_outlined`
- Count source: `state.dischargeReadyCount` ← `scopeCounts.discharge` (server `totalItemCount` for `IcuBoardScope.discharge`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered membership (search → board `totalItemCount`; option/date filters → client filter of current page)
- Sibling tabs: dedicated unfiltered `IcuScopeCounts`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `discharge`
- Tab gate: `IcuDischargeReadyAtomPermissions.tab` = `icuWorkspaceReadRequirement`
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
- Scope: `IcuBoardScope.discharge`
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns (≤5): Patient, Bed, Admitted, Status, Next action (**kept for readers** — navigate clearance; write kinds gate via `AppAccessActionGate`)
- Column choices (Settings): alert, source, icu_start, transfer, encounter (plus defaults when not already visible)
- Storage keys: `'icu_discharge'` / `'icu_cw_discharge'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`) + date range on `admittedAt`
- Client-side filter on current page for option/date groups; search reloads server scope
- Discharge badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Strip context: none
- Next-action cell: `openDischargeClearance` when `isDischargePlanned`, else `markReadiness`; workflow `nextStep` wins when registered
- Row select → stay detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail (`ICU stay`) | ICU-owned `IcuStayDetailPanel` |
| `openIcuReadinessDialog` | ICU-owned |
| Other ICU mutation dialogs / clinical orders | ICU-owned / **reused** clinical |

Deep link `panel=discharge` → readiness dialog when write allowed.

## 7. Nested / follow-on

- Clearance navigation → IPD with `panel=discharge`
- From stay detail: Open IPD / Open billing; Print (`commonPrintActionLabel`); complementary writes

## 8. Forms (summary)

- Readiness: `icuReadinessDialogTitle`, `icuReadinessDescription`, `icuReadinessNoteLabel`, `icuReadinessMarkActionLabel`; no tenant/facility/session fields

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList`
- Stay detail Print: `commonPrintActionLabel` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Board empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Workspace load/retry: `AsyncStateScaffold` + `IcuWorkspaceController.refresh`
- Mutations refresh board + sibling `scopeCounts` (incl. discharge badge)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Mark readiness + write mutations | `icuWorkspaceWriteRequirement` |
| Open discharge clearance / Open IPD | `icuNavigationRequirement` |
| Nested billing | ∩ `billing:read` + `billing-payments` |
| `panel=discharge` deep link | `icuFocusedPanelRequirement` (write) |
| Route entry | catalog ∩ `icu:read` + module |
