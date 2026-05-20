You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and latest screenshots. Align the work with the existing Flutter/Riverpod frontend, Express backend, current shared action/dialog patterns, and current patient/clinical workflow behavior.

## Goal

Standardize reusable patient, appointment, OPD, triage, admission, clinical order, referral, follow-up, disposition, and report/print dialogs across the app.

Do not create duplicate local dialogs when an equivalent dialog already exists.

## Main reuse sources

Use these existing implementations as the source of truth before creating anything new:

- Patient creation: `PatientFormDialog`
- Emergency registration: `EmergencyPatientFormDialog`
- Appointment creation: `_PatientAppointmentQuickDialog`
- OPD check-in: patient quick-action OPD check-in flow
- Triage: existing patient/emergency/triage form patterns
- Admission request/admit patient: existing clinical admission dialog and patient admission flow
- Diagnosis: `ClinicalDiagnosisActionDialog`
- Lab request: `ClinicalLabOrderActionDialog`
- Radiology request: `ClinicalRadiologyOrderActionDialog`
- Prescription: `ClinicalPrescriptionActionDialog`
- Procedure: `ClinicalProcedureActionDialog`
- Referral: `ClinicalReferralActionDialog`
- Follow-up: `ClinicalFollowUpActionDialog`
- Disposition: `ClinicalDispositionActionDialog`
- Report/print: existing shared printing/report components

## Required updates

### 1. Patient creation

Use the Patient screen’s `PatientFormDialog` as the reusable patient creation dialog everywhere a new patient is created.

- First name is required.
- Last name must be optional.
- Update frontend validation.
- If backend validation currently requires last name, update backend validation so last name is optional.
- Preserve existing patient payload shape as much as possible.
- Do not add new patient fields.

### 2. Emergency registration

Fix emergency registration so the existing emergency registration form works.

- Keep the current emergency registration action.
- Preserve the intended submit flow through patient creation.
- Do not add a new emergency workflow.

### 3. Appointment scheduling

Reuse the existing patient appointment dialog everywhere appointments are created or scheduled.

Do not redefine separate appointment dialogs for equivalent scheduling behavior.

### 4. OPD check-in

Reuse the existing OPD check-in dialog/flow everywhere an OPD patient is checked in.

Do not duplicate OPD check-in forms.

### 5. Triage

Reuse one shared triage form/dialog everywhere triage is performed.

Preserve existing triage fields, validation, submit behavior, and controller calls.

### 6. Clinical visit

Remove the Clinical visit quick-action/dialog from the Patient details quick actions.

Do not remove unrelated clinical workspace functionality.

### 7. Billing

Keep consultation billing behavior as currently implemented.

Do not replace it unless the same consultation billing dialog is duplicated elsewhere.

### 8. Admission

Standardize admission request/admit patient dialogs.

- Reuse the existing clinical admission/request admission dialog where admission is requested.
- Preserve current admission behavior.
- When a patient is admitted/requested for admission, they must appear in the inpatient/IPD workflow as pending admission for the relevant ward/room/bed context.
- Do not add new admission fields unless already required by the existing dialog/API.

### 9. Reports and printing

When reports/print is clicked, open the print preview flow directly.

Use the same shared report/print flow globally.

The print preview must allow choosing what to print and what not to print if that behavior already exists.

### 10. OPD actions

Review OPD actions and replace duplicated dialogs with shared ones where equivalent:

- Consultation/payment: reuse existing consultation billing behavior.
- Assign doctor/provider: preserve current behavior.
- Doctor review: replace duplicated diagnosis/order/prescription/procedure behavior with the existing shared clinical dialogs where equivalent.
- Print summary: use the shared print/report flow.

### 11. Clinical actions

Reuse existing shared clinical dialogs globally:

- Add diagnosis
- Request lab
- Request radiology
- Prescribe
- Add procedure
- Refer
- Request admission
- Follow up
- Complete disposition
- Print summary

Remove the Care plan action/component where it appears as a clinical action.

### 12. Lab requests

Remove standalone “Request lab” entry points that create lab requests without first selecting a patient.

Lab requests should be initiated from a selected patient/encounter context and must reuse the shared clinical lab request dialog.

### 13. Radiology

Review radiology actions, but only standardize actions already clearly duplicated elsewhere.

Do not redesign unclear radiology-specific flows such as assign, start imaging, or perform study in this task.

## Implementation rules

- Do not add new workflows.
- Do not add new fields unless needed only to preserve an existing dialog/API.
- Do not add new permissions.
- Do not change unrelated backend behavior.
- Do not duplicate dialogs.
- Keep feature-specific submit callbacks and controller/repository calls in feature code.
- Move only reusable dialog/action UI into shared components.
- Preserve existing labels, icons, validation, loading states, success/error handling, refresh behavior, and payload mapping.
- Preserve current table, search, filter, summary-card, and workspace layout behavior.

## Acceptance criteria

- Patient creation uses one reusable patient dialog.
- Last name is optional in frontend and backend validation.
- Emergency registration works.
- Appointment scheduling uses one reusable appointment dialog.
- OPD check-in uses one reusable OPD check-in flow.
- Triage uses one reusable triage dialog.
- Clinical visit quick action is removed from Patient details.
- Care plan action is removed.
- Shared clinical dialogs are reused for diagnosis, lab, radiology, prescription, procedure, referral, admission, follow-up, and disposition.
- Lab requests require selected patient/encounter context.
- Print/report actions open the shared print preview flow directly.
- No duplicate equivalent dialogs remain where a shared dialog exists.
- Existing business behavior is preserved.