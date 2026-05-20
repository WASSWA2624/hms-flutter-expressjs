You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and any attached latest screenshots. Align the refactor with the existing Flutter/Riverpod frontend implementation, current shared UI patterns, and the current backend/API behavior.

## Goal

Standardize repeated action buttons, action panels, and modal dialogs across the app by converting duplicated local action UI into reusable shared components.

Use the existing OPD, Clinical, and Patient action implementations as the starting point. Reuse the action components and dialogs already defined there first. For similar actions already implemented in other modules, replace duplicated local UI with the shared version. If a repeated action/dialog pattern does not already exist in OPD, Clinical, or Patient code, create the missing reusable component under the shared frontend folders and use it consistently.

## Current implementation anchors

Start from these existing shared frontend files:

- `lib/shared/actions/actions.dart`
- `lib/shared/actions/app_action_item.dart`
- `lib/shared/actions/app_action_panel.dart`
- `lib/shared/actions/app_action_dialogs.dart`
- `lib/shared/clinical_actions/clinical_actions.dart`
- `lib/shared/clinical_actions/clinical_action_items.dart`
- `lib/shared/clinical_actions/clinical_actions_panel.dart`
- `lib/shared/clinical_actions/clinical_action_dialogs.dart`
- `lib/shared/clinical_actions/clinical_order_action_dialogs.dart`
- `lib/shared/components/app_dialog.dart`
- `lib/shared/components/app_patient_detail_dialog.dart`
- `lib/shared/components/app_permission_action.dart`
- `lib/shared/components/app_record_vitals_dialog.dart`
- `lib/shared/components/app_report_actions.dart`
- `lib/shared/components/app_triage_components.dart`
- `lib/shared/components/app_vitals_form.dart`
- `lib/shared/layout/app_workspace.dart`

Use these existing APIs before creating new ones:

- `AppActionItem`
- `AppActionList`
- `AppActionPanel`
- `ClinicalActionItem`
- `ClinicalActionsPanel`
- `AppDialog`
- `showAppDialog`
- `showAppWorkspaceActionDialog`
- `AppConfirmActionDialog`
- `AppTextActionDialog`
- `AppPermissionActionButton`
- `AppRecordVitalsDialog`
- `AppVitalsForm`
- `AppTriage...` components
- `AppReportActionButton`

## Hard constraints

Do not add, remove, rename, or change:

- workflows
- actions
- fields
- labels
- icons
- modal titles
- modal contents
- enabled/disabled states
- loading states
- permission gates
- validation behavior
- API calls
- backend behavior
- controller/repository calls
- payload shape
- success/error handling
- refresh behavior

Do not introduce new backend routes, frontend-only workflow states, new permissions, new feature behavior, or new business rules.

Do not undo the current workspace, table, search, filter, or layout improvements.

Treat app-planner and backend as alignment references for existing behavior only. This task is a frontend UI refactor, not a backend behavior change.

## Refactor rules

1. Keep feature-specific business logic in the existing feature pages, controllers, and repositories.
2. Move only reusable UI/action/dialog structure into shared components.
3. Prefer a declarative action list model over repeated button markup.
4. Use shared action panels for groups of actions.
5. Use shared dialogs for repeated modal patterns.
6. Keep unique module-specific forms local when they are not reusable.
7. If a dialog pattern is reused or equivalent across modules, extract the reusable structure into `lib/shared/...` and keep only module-specific submit callbacks, payload mapping, and controller calls in the feature code.
8. Preserve existing nested dialog behavior, including OPD nested action dialogs and patient quick-action dialogs opened from patient detail flows.
9. Preserve generated report/print behavior. Do not print visible UI screens.
10. Preserve the same localization keys or existing string constants already used by each module.

## Starting points to normalize

### 1. Patient detail quick actions

Review and refactor the Patient quick-action implementation in:

- `lib/features/patients/presentation/pages/patient_registry_page.dart`

Use or extract shared components for the existing patient detail actions:

- Schedule appointment
- OPD check-in
- Triage
- Clinical visit
- Billing
- Admission
- Patient report

Relevant current local implementation includes:

- `_QuickActions`
- `_openQuickAction`
- `_PatientAppointmentQuickDialog`
- `_PatientFlowQuickDialog`
- `_PatientReportDialog`

### 2. OPD workflow actions

Review and refactor OPD workflow action patterns in:

- `lib/features/opd/presentation/pages/opd_workspace_page.dart`

Normalize repeated action buttons, sections, and dialogs for:

- Pay consultation
- Assign doctor
- Record vitals
- Routing decision
- Doctor review
- Refer
- Follow up
- Correct stage
- Print summary

Relevant current local implementation includes:

- `FlowActionsDialog`
- `_OpdWorkflowSection`
- `_OpdWorkflowAction`
- `ConsultationPaymentDialog`
- `AssignDoctorDialog`
- `RecordVitalsDialog`
- `RoutingDecisionDialog`
- `DoctorReviewDialog`
- `ReferralDialog`
- `FollowUpDialog`
- `CorrectStageDialog`
- `PrintOpdSummaryDialog`

Reuse existing shared clinical dialogs where already used, such as referral and follow-up dialogs.

### 3. Clinical workspace actions

Review and preserve the existing shared clinical action implementation in:

- `lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- `lib/shared/clinical_actions/`

Reuse the existing shared clinical action components and dialogs for:

- Add note
- Add diagnosis
- Request lab
- Request radiology
- Prescribe
- Add procedure
- Care plan
- Refer
- Request admission
- Follow up
- Complete disposition
- Print summary

Relevant current implementation includes:

- `_ClinicalActionBar`
- `ClinicalActionsPanel`
- `ClinicalActionItem`
- `ClinicalFreeTextActionDialog`
- `ClinicalDiagnosisActionDialog`
- `ClinicalProcedureActionDialog`
- `ClinicalLabOrderActionDialog`
- `ClinicalRadiologyOrderActionDialog`
- `ClinicalPrescriptionActionDialog`
- `ClinicalReferralActionDialog`
- `ClinicalFollowUpActionDialog`
- `ClinicalAdmissionActionDialog`
- `ClinicalDispositionActionDialog`

### 4. Emergency actions

Review and refactor Emergency action patterns in:

- `lib/features/emergency/presentation/pages/emergency_workspace_page.dart`

Convert emergency action buttons/dialogs to shared reusable patterns where they match existing action/dialog behavior:

- Priority
- Triage
- Response
- Dispatch
- Dispatch status
- Start trip
- Complete trip
- Handoff
- Print summary

Relevant current local implementation includes:

- `_EmergencyActionPanel`
- `_PriorityDialog`
- `_TriageDialog`
- `_ResponseDialog`
- `_DispatchDialog`
- `_DispatchStatusDialog`
- `_HandoffDialog`

Preserve all current controller calls, success messages, confirmation behavior, and report printing behavior.

### 5. Other modules

Review these modules for equivalent repeated action bars, action buttons, confirmation dialogs, text-entry dialogs, status-update dialogs, report/print actions, and patient-context action panels:

- Patients
- Billing
- Claims
- OPD
- Emergency
- IPD
- ICU
- Nursing
- Clinical
- Lab
- Radiology
- Pharmacy
- Discharge
- Theater
- Settings
- Setup / Tenant Facility

Where equivalent behavior exists, replace duplicated local UI with the shared reusable components. Do not refactor unique module-specific forms unless the same UI/dialog/action structure is clearly reused elsewhere.

## Acceptance criteria

- Repeated action button groups use shared action components.
- Repeated modal dialog patterns use shared dialog components.
- OPD, Clinical, Patient, and Emergency actions remain visually and behaviorally consistent with the current implementation and screenshots.
- Other modules use the same shared action/dialog patterns where equivalent actions exist.
- Existing labels, icons, permissions, validation, modal behavior, submit behavior, success/error handling, and refresh behavior are preserved.
- Feature-specific business logic remains in feature pages/controllers/repositories.
- No new functionality, workflow, backend behavior, permission, field, API call, or payload change is introduced.