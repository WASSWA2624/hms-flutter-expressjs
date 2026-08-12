# Nursing tab — Medication due

## 1. Tab strip

- Label: `nursingScopeMedicationDueLabel`
- Icon: `Icons.medication_outlined`
- Count source: `state.scopeCounts.medicationDue` / `state.medicationDueCount` via `nursingScopeTabCount` (sibling unfiltered `NursingScopeCounts`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount`
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.warning`
- Deep-link `scope`: `medication-due` (aliases `medication_due`, `medication`)
- Tab gate: `NursingMedicationDueAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (matrix View ∩ is `readIntersection`, not strip gate)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Shift context** (unauthorized Export/Print/Shift omitted)

- Search: `nursingSearchLabel` / `nursingSearchHint` (clear → `applySearch('')`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close via reception/common keys
- Export: `commonTableExportActionLabel` gated by `canExportNursingWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintNursingWorkspace`; preview-first `printNursingWorkspaceList`
- Shift context: `nursingShiftContextTitle` when `nursingShiftContextRequirement`
- Date filter: **enabled** — `nursingDateFilterLabel` / From / To

## 3. Table

- Row model: `NursingWorkItem` via `NursingWorklistPanel`
- Scope: `NursingQueueScope.medicationDue` — `matchesScope` = `hasMedicationDue` (`medicationDueCount > 0`)
- Row select → `NursingPatientDetailDialog` (generic title `nursingPatientContextLabel`; identity in body)
- Default columns (~5): patient, **medication_due_count** (if ∩ `pharmacy:read`), location, status + next_action (Next action gated by `nextActionMedication`; justified ≤5 with always-visible next_action when administer allowed)
- Column choices (Settings exposes all): shared pool (priority, task_type, admission, due_time, responsible_nurse, observations, transfer_status, discharge_status)
- Patient cell uses `bodyMedium` (no strong weight in rows — `tables.mdc`)
- Storage keys: `'nursing_medicationDue'` / `'nursing_cw_medicationDue'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Shared nursing worklist text filters + option groups + date range
- Footer: Clear filters → Apply filters → Close
- Active badge reflects filtered membership when narrowed

## 5. Primary / secondary / row actions

- Next-action always Administer medication → `NursingMedicationDialog`
- Next-action column gated by `NursingMedicationDueAtomPermissions.nextActionMedication`
- Detail complementary Quick Actions when source write allows; Administer omitted when it is the row next-action

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail | Nursing-owned; generic title `nursingPatientContextLabel`; identity in body `AppPatientDetails` |
| `NursingMedicationDialog` | Nursing-owned (`AppMedicationAdministrationForm`) |
| Complementary Nursing/Clinical dialogs | Nursing / **reused** |
| Print summary | Nursing helper → clinical summary |

Deep link `panel=medication` / `mar` / `meds` → focused med dialog when administer allowed.

## 7. Nested / follow-on

- Medications panel in detail (∩ `pharmacy:read`)
- Billing clearance panel + Open billing (`billingPanel` / `openBilling` on medication-due atom map)
- Open ICU (`RouteAccessCatalog.icuEntry`)
- Complementary vitals / note / print / clinical orders when source write allows

## 8. Forms (summary)

- Med admin: medication, dose, unit, route (`ORAL`…`OTHER`), administered date/time, confirm (`nursingConfirmMedicationLabel` / `Subtitle`)
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList`
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Shared nursing loading / empty feedback
- Stage success / validation use medication administer ∩
- Mutations refresh worklist + sibling `scopeCounts`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / detail | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| readIntersection / medicationDueCount / medicationsPanel | clinical+pharmacy read / ∩ `pharmacy:read` |
| success / validation / write / nextActionMedication / administerMedication / panelDeepLink / nestedWrite | medication administer ∩ |
| create / update / delete / clinicalWrite | `nursingClinicalWriteRequirement` |
| complementaryWrite / checklist / vitals / note / printSummary | `nursingWriteRequirement` |
| billingPanel / openBilling | ∩ `billing:read` + `billing-payments` |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| shiftContext | shift context req |
| Route entry | catalog ∩ `nursing:read` + module |
