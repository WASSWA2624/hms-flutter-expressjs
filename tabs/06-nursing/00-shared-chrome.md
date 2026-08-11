# Nursing — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.nursing` under app `ShellRoute` (`/nursing`)
- Catalog entry: `RouteAccessCatalog.nursingEntry` = ∩ `nursing:read` + module `inpatient-bed-management`
- AppRoutes: `requiredPermissions: [nursing:read]`, roles `nursingWorkspaceRoles`, module `inpatient-bed-management`
- Workspace tab/list read: `nursingWorkspaceReadRequirement` = ∪ `clinical:read` \| `patient:read` + module
- Write: `nursingWriteRequirement` = ∪ `clinical:write` \| `patient:write` \| `last_office:write` + `nursingWriteRoles` + module
- Clinical stage write (handover/transfer/discharge stages): `nursingClinicalWriteRequirement` = ∩ `clinical:write` + roles + module
- Medication administer: `nursingMedicationAdministerRequirement` (pharmacy:read ∩ clinical|pharmacy write)
- Medications panel: `nursingMedicationsPanelRequirement` = ∩ `pharmacy:read`
- Shift context: `nursingShiftContextRequirement` = ∪ roster/hr/operations/unit:read + `hr-rosters`
- Billing clearance: `nursingBillingClearanceReadRequirement` = ∩ `billing:read` + `billing-payments`
- Shell badge: `nursingWorkloadCount` = assignedWard + urgent + handoverPending
- Tabs omitted when unauthorized — not disabled; fallback prefers `all`

## Page chrome

- `AsyncStateScaffold` — loading `nursingLoadingTitle` / `nursingLoadingBody`; retry → `refresh()`; `PageMaxWidth.dataHeavy`
- Body: `ResponsivePage` + `AppTabStrip` + `NursingWorklistPanel`
- URL sync: `syncWorkspaceLocation` writes `scope` when not `all`
- Deep-link (`NursingWorkspaceQuery`): `scope`/`section`/`filter`/`queue`, `search`/`q`/`patient`, `id`/`admissionId`/`encounterId`, `panel`/`detail`
  - Focus + write panel → `openNursingFocusedAction`; else `openNursingPatientDetailDialog`

## Tab strip (all visible scopes)

- Component: `AppTabStrip` / `AppTabItem` via `nursingTabItems`
- Count `null` when 0 (`_tabCountOrNull`)
- Tones: `danger` urgent; `warning` medicationDue / transferPending; others default (unset)
- Icons: inventory_2 / local_hospital / priority_high / medication / swap_horiz / transfer_within_a_station / logout

## Table toolbar (shared pattern)

Order on search bar: **Filters → Settings → Export → Shift context**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `nursingSearchLabel` / `nursingSearchHint` | clear → `applySearch('')` |
| Filters | `nursingAdvancedFiltersLabel` → `commonAdvancedFiltersTitle` | Apply `nursingApplyFiltersLabel`; Reset `nursingResetFiltersLabel` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | |
| Export | shared table default on | **no nursing-specific export gate** in panel |
| Print (table) | — | **not mounted** (`enablePrint` false); print from detail only |
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
| `discharge` / `clearance` | discharge clearance | clinical write ∩ |

No `panel=transfer`.

## Shared dialogs (owner notes)

| Surface | Owner |
| --- | --- |
| `NursingPatientDetailDialog` | Nursing-owned (shell `AppPatientDetailDialog`) |
| `NursingShiftContextDialog` | Nursing-owned |
| `NursingHandoverDialog` / `NursingEscalationDialog` | Nursing-owned |
| `NursingVitalsDialog` → `AppRecordVitalsDialog` | Nursing wrap → **reused** |
| `NursingMedicationDialog` | Nursing-owned (`AppMedicationAdministrationForm`) |
| `NursingTransferDialog` / `NursingDischargeClearanceDialog` / `NursingNoteDialog` | Nursing-owned |
| `showNursingPrintSummary` | Nursing helper → `PrintDocumentTemplates.clinicalSummary` |
| `ClinicalFreeTextActionDialog` / prescribe / lab / radiology | **reused** clinical |
| Open billing | navigates `AppRoutes.billing` |

## Feedback patterns (cross-tab)

- Success: `nursingSavedMessage` via `nursingShowActionResult`
- Failures: `nursingShowFailureIfNeeded` / `showAppFailureSnackBar`; dialogs `AppFormInformationBanner.failure`
- Empty worklist: `nursingNoWorklistTitle` / `nursingNoWorklistBody`
- Empty detail: `nursingNoSelectionTitle` / `nursingNoSelectionBody`
- Copy: admission / encounter id copy snackbars
