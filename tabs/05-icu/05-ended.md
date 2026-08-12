# ICU tab — Ended stays

## 1. Tab strip

- Label: `icuEndedStaysLabel`
- Icon: `Icons.output_outlined`
- Count source: `state.endedCount` ← `scopeCounts.ended` (server `totalItemCount` for `IcuBoardScope.ended`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered membership (search → board `totalItemCount`; option/date filters → client filter of current page)
- Sibling tabs: dedicated unfiltered `IcuScopeCounts`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `ended`
- Tab gate: `IcuEndedStaysAtomPermissions.tab` = `icuWorkspaceReadRequirement`
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
- Scope: `IcuBoardScope.ended`
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns (≤5): Patient, Bed, ICU start, Status, Next action (**kept for readers** — navigate Open IPD)
- Column choices (Settings): alert, source, transfer, admitted, encounter (plus defaults when not already visible)
- Storage keys: `'icu_ended'` / `'icu_cw_ended'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`) + date range on `admittedAt`
- Client-side filter on current page for option/date groups; search reloads server scope
- Ended badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Strip context: none
- Next-action cell: always `openIpd` on Ended tab; workflow `nextStep` wins when registered
- Detail may still expose eligible writes via `canRecordIcuAction`
- Row select → stay detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail (`ICU stay`) | ICU-owned `IcuStayDetailPanel` |
| Eligible ICU mutation dialogs | ICU-owned |
| Clinical order / Rx | **reused** clinical |

## 7. Nested / follow-on

- Open IPD navigation
- From stay detail: Open billing when authorized; Print (`commonPrintActionLabel`); complementary writes when still eligible

## 8. Forms (summary)

- Same ICU mutation forms when still eligible for the stay; no tenant/facility/session fields

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList`
- Stay detail Print: `commonPrintActionLabel` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Board empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Workspace load/retry: `AsyncStateScaffold` + `IcuWorkspaceController.refresh`
- Mutations refresh board + sibling `scopeCounts` (incl. ended badge)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Eligible write mutations | `icuWorkspaceWriteRequirement` |
| Next-action Open IPD | `icuNavigationRequirement` |
| Nested billing | ∩ `billing:read` + `billing-payments` |
| Route entry | catalog ∩ `icu:read` + module |
