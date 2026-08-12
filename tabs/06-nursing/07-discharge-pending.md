# Nursing tab — Discharge pending

## 1. Tab strip

- Label: `nursingScopeDischargePendingLabel`
- Icon: `Icons.logout_outlined`
- Count source: `state.scopeCounts.dischargePending` / `state.dischargePendingCount` via `nursingScopeTabCount` (sibling unfiltered `NursingScopeCounts`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount`
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.warning`
- Deep-link `scope`: `discharge-pending` (aliases `discharge_pending`, `discharge`)
- Tab gate: `NursingDischargePendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (∩ `nursing:read` + `inpatient-bed-management`)
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
- Scope: `NursingQueueScope.dischargePending` (`matchesScope` → `isDischargePending`)
- Row select → `NursingPatientDetailDialog`
- Default columns (~5): patient, location, **discharge_status**, status + next_action (Next action **omitted** when clinical write gate fails)
- Column choices (Settings): shared pool beyond defaults
- Storage keys: `'nursing_dischargePending'` / `'nursing_cw_dischargePending'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Shared filters including `discharge_status` (PLANNED / DISCHARGE_PLANNED / COMPLETED / DISCHARGED) + date; label `dischargeStatusFilterLabel`
- Active badge reflects filtered membership when narrowed

## 5. Primary / secondary / row actions

- Next-action Discharge clearance → `NursingDischargeClearanceDialog`
- Detail Quick Action when discharge pending; complementary writes when source write allows

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `NursingDischargeClearanceDialog` | Nursing-owned |
| Patient detail + complementary | Nursing / **reused** |
| Print summary | Nursing helper → clinical summary |

Deep link `panel=discharge` / `clearance` → focused clearance when `nursingClinicalWriteRequirement` allows.

## 7. Nested / follow-on

- Billing clearance panel + Open billing (`billingPanel` / `openBilling`; `dischargeOpenBillingAction`)
- nestedRead ∪ billing \| last_office; nestedBillingRead / nestedLastOfficeRead
- Meds panel; Open ICU (`RouteAccessCatalog.icuEntry`)
- `panel=` deep links under matching write gates (incl. `transfer`)

## 8. Forms (summary)

- Clearance checks: medication education, wound care, follow-up, belongings returned, identity band (`nursingClearance*` labels) + notes + confirm
- Title: `nursingDischargeClearanceTitle`
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList`
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Shared nursing loading / empty feedback
- Stage success / validation use `nursingClinicalWriteRequirement`
- Mutations refresh worklist + sibling `scopeCounts`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / discharge_status chrome | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| write / nextActionDischarge / panelDeepLink / stage success / validation | `nursingClinicalWriteRequirement` |
| complementaryWrite / checklist / vitals / note / prescribe / orders | `nursingWriteRequirement` |
| medicationsPanel / administerMedication | pharmacy / med administer ∩ |
| billingPanel / openBilling / nestedBillingRead | ∩ `billing:read` + `billing-payments` |
| nestedRead | billing \| last_office |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| shiftContext | shift context req |
| Route entry | catalog ∩ `nursing:read` + module |
