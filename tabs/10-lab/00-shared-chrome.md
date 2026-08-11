# Lab — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.lab` under app `ShellRoute` (`/lab`)
- Catalog entry: `RouteAccessCatalog.labEntry` / `labWorkspaceCatalogEntryRequirement` — ∩ `lab:read` + module `lab-workflows`
- Route gate: ∪ `lab:read` | `clinical:read` | `clinical:write` + module (+ `labWorkspaceRoles`)
- Workspace read: `labWorkspaceReadRequirement` — ∩ `lab:read` + `lab-workflows`
- Workspace write: `labWorkspaceWriteRequirement` — ∩ `lab:write` + `lab-workflows`
- If `labAllowedSections` empty: `AppWorkspaceStatePanel.empty` (`labNoOrdersTitle` / `labNoOrdersBody`) — not `AppFailureStateView` forbidden
- Route-only clinical readers (∪ clinical without `lab:read`): worklist tabs kept; Follow-ups omitted

## Page chrome

- `AsyncStateScaffold<LabWorkspaceState>` over `labWorkspaceControllerProvider`
  - Loading: `labLoadingTitle` / `labLoadingBody`
  - Retry: `LabWorkspaceController.refresh()`
  - `keepPreviousDataDuringRefresh`: default **false**
- Body: `ResponsivePage` + `AppTabStrip` + (`AppListTable<LabOrderSummary>` | **reused** `FollowUpWorklistPanel`)
- No dedicated painted page title; no Refresh / Orders↔Patients / Lab Configurations strip (tests assert absent)
- In-desk URL: `syncWorkspaceLocation` with canonical `?section=`
- Deep-link (`LabWorkspaceQuery.fromUri`):
  - `section` | `panel` | `filter` | `scope` → desk section
  - `search` | `q`
  - `orderId` / `order_id` / `order` → open result entry
  - `encounterId` / `encounter_id` / `encounter` → open matching row
- Default landing: `LabDeskPreferences` default tab, else `LabDeskSection.collection`

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`
- Tabs omitted when unauthorized (`labSectionTabRequirement`) — not disabled
- Order: Pending → Critical → Completed → Follow-ups → All patients
- Counts: patient-view summary (`LabWorkbenchView.patients`) — `collectionForView` / `criticalForView` / `completedForView` / `totalForView`; Follow-ups via `followUpTabCountProvider(FollowUpWorklistScope())`
- Count tones: Critical `danger`; Pending `warning`; Completed / Follow-ups / All `info`
- Icons: biotech / priority_high / task_alt / phone_callback / assignment

## Workbench view

- Enum: `LabWorkbenchView.patients` | `orders`
- **UI always patients**; `orders` removed from Lab UI; controller `applyView` remains

## Table toolbar (worklist tabs)

Order on search bar: **Filters → Settings → Export → Create Lab Order**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `labSearchLabel` / hint `labSearchHint` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction` |
| Settings | `commonTableSettingsActionLabel` → **Lab-owned** `showLabDeskSettingsDialog` (`labDeskSettingsTitle`) | Apply/Reset `labApplyColumnsAction` / `labResetColumnsAction` |
| Export | default AppListTable Export | **no** ∩ `evidence:export` / `canExport` gate |
| Print (table) | — | **not mounted** |
| Create | `labCreateAction` | omitted without `labStripCreateRequirement` (∩ `lab:write`) |

Column visibility: `lab_$sectionName` / widths `lab_cw_$sectionName`.  
Desk prefs: `lab_desk_default_tab`, `lab_desk_page_size` (`10|25|50`, default 25).  
Date filter: **enabled** — `labOrderedDateFilterLabel`.

## Shared strip / row actions → dialogs

| Action | Owner |
| --- | --- |
| Create Lab Order | **shared** `LabOrderContextDialog` → **reused** `ClinicalLabOrderActionDialog`; nested register **reused** `showRegisterNewPatientDialog` when ∩ `patient:write` |
| Row / next-action Enter result | Lab-owned `LabResultEntryDialog` |
| Report preview / settings | Lab-owned `_LabReportPreviewDialog` / `showLabReportPreviewSettingsDialog` |
| Reopen verified | Lab-owned `_ReopenSavedResultDialog` |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |
| Collect (`labCollectSampleAction`) | **not mounted** (controller methods remain) |
| Open billing | **not mounted** (Await payment text only) |
| Edit / additional order helpers | defined on page — **no call sites** from current chrome |

## Feedback patterns (cross-tab)

- Success: `labSavedMessage`; `labResultsVerifiedMessage` / `labBatchPartialSaveMessage`; `labVerifiedResultReopenedMessage`
- Failures: `showAppFailureSnackBar`; result-entry banners
- Empty worklist: `labNoPatientsTitle` / `labNoPatientsBody`
- Detail empty/loading: `labNoSelectionTitle`/`Body`, `labDetailLoadingTitle`/`Body`
- Follow-ups empty/error: Reception follow-up + unexpected error keys
