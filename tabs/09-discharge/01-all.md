# Discharge tab — All patients

## 1. Tab strip

- Label: `dischargeSectionAll`
- Icon: `Icons.inventory_2_outlined`
- Count source: `state.queue.items.length` (loaded queue)
- Sibling tabs: client-filtered counts from same queue; Follow-ups provider separate
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all`
- Tab gate: `DischargeAllPatientsAtomPermissions.tab` = workspace read ∪
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export**

- Search hint: `dischargeQueueSearchHint`
- Filters / Settings: shared labels
- Export: ungated default Export
- Print (toolbar): **not mounted**
- Strip Plan/Clearance: **not mounted**
- Date filter: **off**

## 3. Table

- Row model: `IpdAdmissionSummary`
- Row select → discharge detail
- Default columns (**5**):
  1. Patient (`dischargePatientColumnLabel`)
  2. Location (`dischargeLocationColumnLabel`)
  3. Target date (`dischargeTargetColumnLabel`)
  4. Status (`dischargeStatusColumnLabel`)
  5. Next action (`dischargeNextActionColumnLabel`)
- Column choices: clearance phase (`ipdDischargeClearancePhaseLabel`), blocking item (`dischargeStatusSummaryPending`), discharged at (`ipdDischargedAtLabel`), admitted at (`ipdAdmittedAtColumnLabel`)
- Storage: `discharge_all` / `discharge_cw_all`
- Mobile: location, status, discharged date

## 4. Advanced filters / search fields

- Groups: Status (`dischargeStatusFilterLabel`) — planned / summaryPending / pharmacyPending / nursingPending / billingPending / insurancePending / documentsReady / completed
- Search: patient + location/status/next-action/dates/phase/stage matcher
- Date filter: **off**

## 5. Primary / secondary / row actions

- Next-action:
  - Unplanned incomplete → `dischargeStartPlanAction` (write)
  - Planned → `dischargeManageClearanceAction` (write)
  - Completed → `dischargePrintSummaryAction` (read)
- Row select → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail (`dischargeDetailTitle`) | Discharge-owned |
| Planning (`showDischargePlanningDialog`) | Discharge-owned |
| Pharmacy request (`_PharmacyDialog`) | Discharge-owned |
| Print clinical summary | **reused** printing (`PrintDocumentTemplates.clinicalSummary`) |

## 7. Nested / follow-on

From planning: Save plan / Finalize; Open Billing / IPD / Nursing / Pharmacy / Housekeeping; pending-order Continue to other modules.  
From detail: Request medicines → pharmacy form; Open billing → navigate.

## 8. Forms (summary)

- Plan: summary text (`dischargeSummaryFieldLabel`)
- Finalize: blockers + override (`ipdDischargeOverrideLabel`)
- Pharmacy: drug, prescription, quantity, route, frequency, instructions

## 9. Print / labels / preview

- Table Print: **absent**
- Detail / completed next-action → `PrintDocumentTemplates.clinicalSummary` (`dischargeReportTitle`, summary/medicines/billing sections, doctor/nurse signatures)

## 10. Loading / empty / error / success

- Loading: `dischargeLoadingTitle` / `dischargeLoadingBody`
- Empty: `dischargeEmptyQueueTitle` / `dischargeEmptyQueueBody`
- Success: `dischargeSavedMessage`
- After mutations: refresh queue + visible tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / empty / loading / retry / rowSelect / detail | `DischargeAllPatientsAtomPermissions.*` → workspace read ∪ |
| nextActionPlan / nextActionClearance / continue / requestPharmacy / write | clinical write |
| nextActionPrint / printSummary | workspace read ∪ |
| openBilling / billingPanel | billing read ∩ |
| medicinesPanel / openPharmacy | pharmacy read ∩ |
| roomTurnover / openHousekeeping | operations read ∩ |
| openNursing | ∩ `last_office:read` |
| openIpd | workspace read ∪ |
| Export | ungated |
| Table Print | n/a |
