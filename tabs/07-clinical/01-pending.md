# Clinical tab — Pending (`all`)

## 1. Tab strip

- Label: `clinicalSectionPendingLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `state.pendingCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: omit / empty (aliases `pending`, `all`, legacy waiting-review / in-consultation variants → `all`)
- Tab gate: `ClinicalAllAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Search / Filters / Settings: shared clinical keys
- Export / Print (toolbar): **absent**
- Context strip actions: **none**
- Date filter: **enabled** — `clinicalLastUpdatedLabel`

## 3. Table

- Row model: clinical worklist entry via `_ClinicalWorklistPanel`
- Scope: `ClinicalQueueScope.all` (non-terminal OP)
- Row select → `_ClinicalEncounterDialog` / Open encounter
- Default columns: patient, queue, provider, status, nextAction
- Column choices: patient, patientId, phone, ageSex, queue, status, nextAction, provider, lastUpdated, encounter, admission, encounterType, location
- Status chips: urgent / results-ready when authorized atoms allow
- Storage: `clinical_all` / `clinical_cw_all`

## 4. Advanced filters / search fields

- Text: general, patient, patient id, phone, encounter, queue, provider, status, location
- Option groups: source, status, provider (+ unassigned), encounter type, location, urgency, results ready
- Date range on last updated
- Sentinels: `__URGENT__`, `__NOT_URGENT__`, `__RESULTS_READY__`, `__RESULTS_NOT_READY__`

## 5. Primary / secondary / row actions

- Next action priority: `RECORD_VITALS` → workflow button → disposition → `clinicalOpenEncounterAction`
- Detail Quick Actions order: vitals → notes → diagnosis → lab → radiology → prescribe → procedure → refer → follow-up → disposition → admission → Print summary

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Encounter shell | Clinical-owned |
| Clinical action dialogs (notes/vitals/dx/orders/Rx/procedure/referral/follow-up/admission/disposition) | **reused** |
| Print summary | **reused** |
| Discharge planning (admission context) | **reused** Discharge |

## 7. Nested / follow-on

- Detail sections: patient context, vitals/triage, notes, pharmacy, diagnoses, lab, radiology, procedures, referrals, follow-ups, admissions, care plans
- Order dialogs nest catalogs + billing / cancel confirms

## 8. Forms (summary)

- Notes; vitals; diagnosis; lab/radiology/pharmacy/procedure + billing; referral; follow-up schedule; admission reason; disposition reasons (`TREATMENT_COMPLETED`, … `OTHER`)

## 9. Print / labels / preview

- Table Print: **absent**
- Encounter: `showClinicalPrintSummaryDialog` — `clinicalConsultationSummaryTitle`; copy/print/cancel actions
- No list labels

## 10. Loading / empty / error / success

- Loading: `clinicalLoadingTitle` / `Body`
- Empty: `clinicalNoWorklistTitle` / `Body`
- Success: `clinicalSavedMessage`
- After mutations: refresh worklist + visible tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / pagination / empty / loading / retry / rowSelect / detail / nextActionReview / printSummary / nestedRead | `clinicalWorkspaceReadRequirement` |
| success / validation / create/update/delete/write / notes / vitals / diagnosis / procedure / refer / followUp / disposition / nestedWrite | `clinicalWorkspaceWriteRequirement` |
| requestLab / nestedLabWrite | lab order write ∪ |
| requestRadiology / nestedRadiologyWrite | radiology order write ∪ |
| prescribe / nestedPharmacyWrite | pharmacy order write ∪ |
| requestAdmission | admission write ∪ |
| dischargeFinancialRead | billing read ∩ |
| followUpsTab | follow-ups read |
| entry / routeEntry | catalog entry |
