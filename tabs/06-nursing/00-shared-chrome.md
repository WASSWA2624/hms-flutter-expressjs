# Nursing — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.nursing` under app `ShellRoute` (`/nursing`)
- Catalog entry: `RouteAccessCatalog.nursingEntry` = ∩ `nursing:read` + module `inpatient-bed-management`
- AppRoutes: `requiredPermissions: [nursing:read]`, roles `nursingWorkspaceRoles`, module `inpatient-bed-management`
- Workspace tab/list read: `nursingWorkspaceReadRequirement` = ∩ `nursing:read` + module (aligned with route entry)
- Write: `nursingWriteRequirement` = ∪ `clinical:write` \| `patient:write` \| `last_office:write` + `nursingWriteRoles` + module
- Clinical stage write (handover/transfer/discharge stages): `nursingClinicalWriteRequirement` = ∩ `clinical:write` + roles + module
- Medication administer: `nursingMedicationAdministerRequirement` (pharmacy:read ∩ clinical|pharmacy write)
- Medications panel: `nursingMedicationsPanelRequirement` = ∩ `pharmacy:read`
- Export / Print: `nursingWorkspaceExportRequirement` / `canExportNursingWorkspace` / `canPrintNursingWorkspace` = ∩ `evidence:export`
- Shift context: `nursingShiftContextRequirement` = ∪ roster/hr/operations/unit:read + `hr-rosters`
- Billing clearance: `nursingBillingClearanceReadRequirement` = ∩ `billing:read` + `billing-payments`
- Open ICU / navigation: `nursingNavigationRequirement` = `RouteAccessCatalog.icuEntry`
- Shell badge: `nursingWorkloadCount` = assignedWard + urgent + handoverPending
- Tabs omitted when unauthorized — not disabled; fallback prefers `all`

## Page chrome

- `AsyncStateScaffold` — loading `nursingLoadingTitle` / `nursingLoadingBody`; retry → `refresh()`; `PageMaxWidth.dataHeavy`
- Body: `ResponsivePage` + `AppTabStrip` + `NursingWorklistPanel`
- URL sync: `syncWorkspaceLocation` writes `scope` when not `all`
- Deep-link (`NursingWorkspaceQuery`): `scope`/`section`/`filter`/`queue`, `search`/`q`/`patient`, `id`/`admissionId`/`encounterId`, `panel`/`detail`
  - Focus + write panel → `openNursingFocusedAction`; else `openNursingPatientDetailDialog`

## Tab strip (all visible scopes)

- Component: `AppTabStrip` / `AppTabItem` via `nursingTabItems` (passes `activeScope`)
- Counts: sibling model = dedicated unfiltered `NursingScopeCounts` from catalog; active tab uses filtered `worklist.totalItemCount` when search/advanced filters narrow; badges always show including `0`
- Tones: `danger` urgent; `warning` medicationDue / handoverPending / transferPending / dischargePending; `info` all / assignedWard
- Icons: inventory_2 / local_hospital / priority_high / medication / swap_horiz / transfer_within_a_station / logout

## Table toolbar (shared pattern)

Order on search bar: **Filters → Settings → Export → Print → Shift context**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `nursingSearchLabel` / `nursingSearchHint` | clear → `applySearch('')` |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | Apply/Reset/Close via reception/common keys |
| Export | `commonTableExportActionLabel` | gated by `canExportNursingWorkspace` (omit when denied) |
| Print (table) | `commonPrintActionLabel` | gated by `canPrintNursingWorkspace`; preview-first via `printNursingWorkspaceList` / `PrintDocumentTemplates.registry` |
| Shift context | `nursingShiftContextTitle` | omitted without `nursingShiftContextRequirement` |

Column storage: `'nursing_${scope.name}'` / `'nursing_cw_${scope.name}'`.  
Date filter: **enabled** — `nursingDateFilterLabel` / From / To.

## Detail panels (`NursingDetailPanel`)

| Panel tokens | Opens | Gate notes |
| --- | --- | --- |
| `checklist` / `admission` | detail (checklist) | write steps need write |
| `vitals` / `observations` | vitals focus / detail | write for focused |
| `medication` / `mar` / `meds` | medication dialog | medication administer ∩ |
| `handover` | handover dialog | clinical write ∩ |
| `transfer` | transfer dialog | clinical write ∩ |
| `discharge` / `clearance` | discharge clearance | clinical write ∩ |

## Shared dialogs (owner notes)

| Surface | Owner |
| --- | --- |
| `NursingPatientDetailDialog` | Nursing-owned (shell `AppPatientDetailDialog`); generic title `nursingPatientContextLabel`; identity in body `AppPatientDetails` |
| `NursingShiftContextDialog` | Nursing-owned |
| `NursingHandoverDialog` / `NursingEscalationDialog` | Nursing-owned |
| `NursingVitalsDialog` → `AppRecordVitalsDialog` | Nursing wrap → **reused** |
| `NursingMedicationDialog` | Nursing-owned (`AppMedicationAdministrationForm`) |
| `NursingTransferDialog` / `NursingDischargeClearanceDialog` / `NursingNoteDialog` | Nursing-owned |
| `showNursingPrintSummary` | Nursing helper → `PrintDocumentTemplates.clinicalSummary`; trigger label `Print` |
| List Print | `nursing_workspace_print_helpers.dart` → registry preview |
| `ClinicalFreeTextActionDialog` / prescribe / lab / radiology | **reused** clinical |
| Open billing | navigates `AppRoutes.billing` |
| Open ICU | navigates `AppRoutes.icu` when `icuEntry` allowed |

## Feedback patterns (cross-tab)

- Success: `nursingSavedMessage` via `nursingShowActionResult`
- Failures: `nursingShowFailureIfNeeded` / `showAppFailureSnackBar`; dialogs `AppFormInformationBanner.failure`
- Empty worklist: `nursingNoWorklistTitle` / `nursingNoWorklistBody`
- Empty detail: `nursingNoSelectionTitle` / `nursingNoSelectionBody`
- Copy: admission / encounter id copy snackbars
- Mutations: `_mutateSelected` refreshes primary worklist (+ `scopeCounts`), selected detail, and shift context

## Justified product exceptions (tested)

- **Responsible nurse column** — synthetic handover/shift summary text (no assignee API field on `NursingPatientSummary`); documented in helpers + print path.
- **No dedicated Handover strip toolbar** — handover work is tab + next-action + detail; Shift context covers roster/ops context.
