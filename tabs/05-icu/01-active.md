# ICU tab — Active

## 1. Tab strip

- Label: `icuActiveIcuLabel`
- Icon: `Icons.bed_outlined`
- Count source: `state.activeCount` ← `scopeCounts.active` (server `totalItemCount` for active scope); when this tab is selected and search/advanced filters narrow the list, badge uses filtered membership (search → board `totalItemCount`; option/date filters → client filter of current page)
- Sibling tabs: dedicated unfiltered `IcuScopeCounts`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active` (default `/icu` omits `section`; alias `''`)
- Tab gate: `IcuActiveIcuAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

- Search hint: `icuSearchHint` (submit/clear → `applySearch`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close = Reset columns / Apply columns / Close
- Export: `commonTableExportActionLabel` gated by `canExportIcuWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintIcuWorkspace`; preview-first `printIcuWorkspaceList`
- Context strip actions: **none**
- Date filter: admitted-at (`ipdAdmittedAtColumnLabel`)

## 3. Table

- Row model: `IcuPatientSummary` via `IcuBoardPanel`
- Scope: `IcuBoardScope.active`
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns (≤5): Patient, Bed, Source, Status, Next action (Next action **omitted** when tab gate fails; Active keeps column for readers — write kinds hide via gate)
- Column choices (Settings): alert, icu_start, transfer, admitted, encounter (plus defaults)
- Storage keys: `'icu_active'` / `'icu_cw_active'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`) + date range on `admittedAt`
- Client-side filter on current page for option/date groups; search reloads server scope
- Active badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Strip context: none
- Next-action cell (`IcuNextActionButton`): start stay → acknowledge alert → manage transfer → open discharge clearance → assign bed → open IPD → record observation (stage-aware); workflow `nextStep` wins when registered
- Row select → stay detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail (`ICU stay`) | ICU-owned `IcuStayDetailPanel` |
| Observation / vitals / alert / round / start stay / transfer / manage transfer / readiness / assign bed | ICU-owned `icu_action_dialogs.dart` |
| Lab / radiology / Rx order | **reused** clinical |
| `ClinicalRequestBillingPanel` | **reused** clinical (billing read) |
| `AppTransferRequestDialog` | **reused** shared |

## 7. Nested / follow-on

From stay detail: complementary writes; Open IPD / Open billing; Print (`commonPrintActionLabel`); `panel=` deep links (vitals/alerts/observations/orders/transfer/discharge) under write gate.

## 8. Forms (summary)

Shared clinical admission / order / transfer dialogs; ward→room→bed dependent resets; no tenant/facility/session fields on operator forms.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList`
- Stay detail Print: `commonPrintActionLabel` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Board empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Workspace load/retry: `AsyncStateScaffold` + `IcuWorkspaceController.refresh`
- Mutations refresh board + sibling `scopeCounts`

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Next-action writes | `icuWorkspaceWriteRequirement` (Open IPD / clearance = navigation) |
| Nested billing | ∩ `billing:read` + `billing-payments` |
| `panel=` deep link | `icuFocusedPanelRequirement` (write) |
| Route entry | catalog ∩ `icu:read` + module |
