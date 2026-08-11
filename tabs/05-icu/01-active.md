# ICU tab — Active

## 1. Tab strip

- Label: `icuActiveIcuLabel`
- Icon: `Icons.bed_outlined`
- Count source: `state.activeCount` (page items matching `isActiveIcu`)
- Sibling tabs: page-derived scope counts (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active` (default `/icu` omits `section`; alias `''`)
- Tab gate: `IcuActiveIcuAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Search hint: `icuSearchHint`
- Filters: `icuAdvancedFiltersLabel` → `icuAdvancedFiltersTitle`; Apply `icuApplyFiltersLabel`; Reset `icuResetFiltersLabel`
- Settings: `commonTableSettingsActionLabel` → `icuTableSettingsTitle`
- Export / Print (toolbar): **absent**
- Context strip actions: **none**
- Date filter: **not present** (client board filters only)

## 3. Table

- Row model: `IcuPatientSummary` via `IcuBoardPanel`
- Scope: `IcuBoardScope.active`
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns:
  1. Patient (`opdPatientColumnLabel`)
  2. Bed (`icuColumnBedLabel`)
  3. Source (`icuColumnSourceLabel`)
  4. Status (`opdStatusColumnLabel`)
  5. Next action (`icuNextActionColumnLabel`, alwaysVisible) when `icuBoardShowsNextActionColumn`
- Column choices (Settings): alert, icu_start, transfer, admitted, encounter (plus defaults)
- Storage keys: shared `'icu_board'` / `'icu_cw_board'`

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`)
- Client-side filter on current page (`filterIcuBoardItems` / `icuBoardDisplayPage`) — does not reload server scope
- No date range

## 5. Primary / secondary / row actions

- Next-action cascade (`_resolveIcuNextAction`): startStay → acknowledge → manageTransfer → openDischargeClearance → assignBed → openIpd → recordObservation
- Detail `IcuActionPanel` complementary writes / nav / print (omits board next-action kind)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay detail | ICU-owned |
| Observation / vitals / alert / round / start stay / transfer / manage transfer / readiness / assign bed | ICU-owned |
| Lab / radiology / Rx order dialogs | **reused** clinical |
| Billing panel | **reused** clinical (billing read) |

## 7. Nested / follow-on

- Open IPD (`openIpdWorkspace`)
- Open billing (`openIcuBillingWorkspace`)
- Open discharge clearance → IPD with `panel=discharge`
- Clinical order / Rx nested billing when authorized

## 8. Forms (summary)

- Observation; vitals (`AppVitalsForm`); alert; round (+ optional billing); start stay; transfer; manage transfer; readiness; assign bed; lab/imaging/Rx

## 9. Print / labels / preview

- Table Print: **absent**
- Stay detail: `icuPrintSummaryLabel` → `PrintDocumentTemplates.clinicalSummary` (sections alerts / observations / vitals / transfer)
- No ICU-owned label print on this tab

## 10. Loading / empty / error / success

- Loading: `icuLoadingBoardTitle` / `icuLoadingBoardBody`
- Empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Error: scaffold retry; `showAppFailureSnackBar`
- Success: `icuChangesSavedMessage`
- After mutations: refresh board + visible tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / empty / loading / retry / row select / detail / printSummary / nestedRead | `icuWorkspaceReadRequirement` |
| Mutations / next-action writes / panel deep-link / nestedWrite | `icuWorkspaceWriteRequirement` |
| Open IPD / discharge clearance / navigation | `icuNavigationRequirement` |
| Open billing / billing panel | `icuBillingReadRequirement` |
| Route entry | `RouteAccessCatalog.icuEntry` |
