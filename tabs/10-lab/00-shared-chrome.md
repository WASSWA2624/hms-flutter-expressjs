# Lab — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.lab` under app `ShellRoute` (`/lab`)
- Catalog entry: `RouteAccessCatalog.labEntry` / `labWorkspaceCatalogEntryRequirement` — ∩ `lab:read` + module `lab-workflows`
- Route gate: ∪ `lab:read` | `clinical:read` | `clinical:write` + module (+ `labWorkspaceRoles`)
- Workspace read: `labWorkspaceReadRequirement` — ∩ `lab:read` + `lab-workflows`
- Workspace write: `labWorkspaceWriteRequirement` — ∩ `lab:write` + `lab-workflows`
- Export / Print: `labWorkspaceExportRequirement` / `labWorkspacePrintRequirement` — ∩ `evidence:export` (omit when denied)
- If `labAllowedSections` empty: `AppFailureStateView` forbidden (Reception-style)
- Route-only clinical readers (∪ clinical without `lab:read`): worklist tabs kept; Follow-ups omitted

## Page chrome

- `AsyncStateScaffold<LabWorkspaceState>` over `labWorkspaceControllerProvider`
  - Loading: `labLoadingTitle` / `labLoadingBody`
  - Retry: `LabWorkspaceController.refresh()`
  - `keepPreviousDataDuringRefresh`: **true**
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
- Sibling-count model: dedicated unfiltered patient-view summary (`labSectionTabCount` / `LabWorkbenchView.patients`)
- Active tab with search / ordered date / client advanced filters: filtered total (`worklist.totalItemCount` or client-filtered page length)
- Follow-ups: `followUpTabCountProvider` + `onNarrowedCountChanged` when filters narrow
- Count tones: Critical `danger`; Pending `warning`; Completed / Follow-ups / All `info` (`labSectionCountTone`)
- Icons: biotech / priority_high / task_alt / phone_callback / assignment

## Workbench view

- Enum: `LabWorkbenchView.patients` | `orders`
- **UI always patients**; `orders` removed from Lab UI; controller `applyView` remains (justified residual — no UI toggle)

## Table toolbar (worklist tabs)

Order on search bar: **Filters → Settings → Export → Print → Create Lab Order**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `labSearchLabel` / hint `labSearchHint` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettingsActionLabel` → **Lab-owned** `showLabDeskSettingsDialog` (`labDeskSettingsTitle`) | Apply/Reset `labApplyColumnsAction` / `labResetColumnsAction` |
| Export | `commonTableExportActionLabel` | gated `canExportLabWorkspace` (∩ `evidence:export`); omit when denied |
| Print | `commonPrintActionLabel` | gated `canPrintLabWorkspace`; preview-first via `printLabWorkspaceList` / `PrintDocumentTemplates.registry` |
| Create | `labCreateAction` | omitted without `labStripCreateRequirement` (∩ `lab:write`) |

Column visibility: `lab_$sectionName` / widths `lab_cw_$sectionName`.  
Desk prefs: `lab_desk_default_tab`, `lab_desk_page_size` (`10|25|50`, default 25).  
Date filter: **enabled** — `labOrderedDateFilterLabel`.

## Follow-ups toolbar

- Settings: panel-owned column dialog (`lab_follow_ups_cols`) — not Lab desk settings
- Export / Print: same ∩ `evidence:export` gates; Print uses `printLabWorkspaceList`
- Create: Create Lab Order when write ∩

## Shared strip / row actions → dialogs

| Action | Owner |
| --- | --- |
| Create Lab Order | **shared** `LabOrderContextDialog` → **reused** `ClinicalLabOrderActionDialog`; nested register **reused** `showRegisterNewPatientDialog` when ∩ `patient:write` |
| Row / next-action Enter result | Lab-owned `LabResultEntryDialog` |
| Report preview / settings | Lab-owned `_LabReportPreviewDialog` / `showLabReportPreviewSettingsDialog` (Print = `commonPrintActionLabel`; pinned footers) |
| Reopen verified | Lab-owned `_ReopenSavedResultDialog` |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |
| Collect (`labCollectSampleAction`) | **not mounted** (product exception — enter-result path covers operator work) |
| Open billing | **not mounted** (Await payment text only; Billing owns settle) |
| Edit / additional order helpers | defined on page — **no call sites** (product exception) |

Shared dialog footers: desk settings, report settings, and Create Lab Order context use `pinActionsToBottom: true`.

## Feedback patterns (cross-tab)

- Success: `labSavedMessage`; `labResultsVerifiedMessage` / `labBatchPartialSaveMessage`; `labVerifiedResultReopenedMessage`
- Failures: `showAppFailureSnackBar`; result-entry banners
- Empty worklist: `labNoPatientsTitle` / `labNoPatientsBody`
- Detail empty/loading: `labNoSelectionTitle`/`Body`, `labDetailLoadingTitle`/`Body`
- Follow-ups empty/error: Reception follow-up + unexpected error keys
- Zero authorized tabs: forbidden failure view
