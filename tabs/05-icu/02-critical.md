# ICU tab — Critical

## 1. Tab strip

- Label: `icuCriticalAlertsLabel`
- Icon: `Icons.priority_high_outlined`
- Count source: `state.criticalCount` ← `scopeCounts.critical` (server `totalItemCount` for critical scope); when this tab is selected and search/advanced filters narrow the list, badge uses filtered membership (search → board `totalItemCount`; option/date filters → client filter of current page)
- Sibling tabs: dedicated unfiltered `IcuScopeCounts`
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `critical`
- Tab gate: `IcuCriticalAtomPermissions.tab` = `icuWorkspaceReadRequirement`
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
- Scope: `IcuBoardScope.critical`
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns (≤5): Patient, Bed, Alert, Status, Next action (Next action **omitted** without write — Critical/Transfers write-only next-action column)
- Column choices (Settings): source, icu_start, transfer, admitted, encounter (plus defaults when not already visible)
- Storage keys: `'icu_critical'` / `'icu_cw_critical'`
- Critical rows tinted via `errorContainer` (`IcuBoardPanel._rowColor`)
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`) + date range on `admittedAt`
- Client-side filter on current page for option/date groups; search reloads server scope
- Critical badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Strip context: none
- Next-action cell: Prefer `acknowledgeAlert` when `hasCriticalAlert` on Critical tab; otherwise shared stage ladder; workflow `nextStep` wins when registered
- Row select → stay detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail (`ICU stay`) | ICU-owned `IcuStayDetailPanel` |
| Alert dialog (`openIcuAlertDialog`) | ICU-owned |
| Observation / vitals / round / start stay / transfer / manage transfer / readiness / assign bed | ICU-owned `icu_action_dialogs.dart` |
| Lab / radiology / Rx order | **reused** clinical |
| `ClinicalRequestBillingPanel` | **reused** clinical (billing read) |

Deep link `panel=alerts` → alert dialog when write allowed.

## 7. Nested / follow-on

From stay detail: complementary writes; Open IPD / Open billing; Print (`commonPrintActionLabel`); `panel=` deep links under write gate. Same cross-module handoffs as Active.

## 8. Forms (summary)

Alert raise/acknowledge and shared ICU mutation forms; ward→room→bed dependent resets; no tenant/facility/session fields on operator forms.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList`
- Stay detail Print: `commonPrintActionLabel` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Board empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Workspace load/retry: `AsyncStateScaffold` + `IcuWorkspaceController.refresh`
- Mutations refresh board + sibling `scopeCounts` (incl. critical badge)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select / alert column | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Next-action Acknowledge / write mutations | `icuWorkspaceWriteRequirement` |
| Nested billing | ∩ `billing:read` + `billing-payments` |
| Open IPD / discharge clearance | `icuNavigationRequirement` |
| `panel=` deep link | `icuFocusedPanelRequirement` (write) |
| Route entry | catalog ∩ `icu:read` + module |
