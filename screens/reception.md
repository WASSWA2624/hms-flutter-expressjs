## Appointment, queue, and workflow actions

| Action button / control             | Locations                                                                              | Modal opened or function                                                                                                                                                                                                                                                                  |
| ----------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prioritize                          | Queue-actions grid; prioritize dialog footer                                           | Opens `AppTextActionDialog`; in that dialog, submits the optional priority reason.                                                                                                                                                                                                      |
| Change status                       | Queue-actions grid; change-status dialog footer                                        | Opens `_ChangeQueueStatusDialog`; in that dialog, updates visit-queue status only.                                                                                                                                                                                                      |
| Assign doctor / Change doctor       | Queue-actions grid; Active visits next-action/`FlowActionsDialog`; assignment dialog footers | Queue hub opens `_AssignQueueDoctorDialog` (Assign vs Change by provider). Active visits opens `AssignDoctorDialog`.                                                                                               |
| Start consultation                  | Queue next-action column/mobile action; queue-actions grid; confirmation footer        | For a queue row with an ID, the workflow control is disabled because `START_CONSULTATION` has no registry definition. The blank-ID fallback opens the row hub. From the grid it opens `AppConfirmActionDialog`, whose footer starts the consultation. |
| Record vitals / Edit vitals         | Active visits next-action label; `FlowActionsDialog`; vitals dialog footer             | Reception next-action labels are read-only text. From Active visits the flow hub opens `RecordVitalsDialog`; its footer saves vitals and any inline routing selection.                                                                            |
| Doctor review                       | Active visits next-action label; `FlowActionsDialog`; clinical free-text dialog footer | The flow hub opens `ClinicalFreeTextActionDialog`; its footer submits the required clinical note.                                                                                                           |
| Collect sample / diagnostic handoff | Active visits next-action label; `FlowActionsDialog` dynamic handoff                   | Routes to Laboratory or the module appropriate for the current diagnostic stage.                                                                                                                           |
| Perform imaging                     | Active visits next-action label; `FlowActionsDialog` dynamic handoff                   | Routes to Radiology.                                                                                                                                                                                       |
| Dispense medicine                   | Active visits next-action label; `FlowActionsDialog` dynamic handoff                   | Routes to Pharmacy.                                                                                                                                                                                        |
| Disposition / Complete disposition  | Active visits next-action label; `FlowActionsDialog`                                   | The flow hub opens `OpdDispositionDialog`.                                                                                                                                                                 |
| Unsupported action code             | Active visits next-action label                                                        | Displays a generated title-cased label but remains disabled.                                                                                                                                               |
| Add diagnosis                       | `FlowActionsDialog`; diagnosis dialog footer                                           | Opens `ClinicalDiagnosisActionDialog`; its footer submits selected diagnoses.                                                                                                                              |
| Request lab                         | `FlowActionsDialog`; lab-order dialog footer                                           | Opens `ClinicalLabOrderActionDialog`; its footer submits the staged lab requests.                                                                                                                          |
| Request radiology                   | `FlowActionsDialog`; radiology-order dialog footer                                     | Opens `ClinicalRadiologyOrderActionDialog`; its footer submits the staged studies.                                                                                                                         |
| Prescribe                           | `FlowActionsDialog`; prescription dialog footer                                        | Opens `ClinicalPrescriptionActionDialog`; its footer submits the prescription.                                                                                                                             |
| Record procedure                    | `FlowActionsDialog`; procedure dialog footer                                           | Opens `ClinicalProcedureActionDialog`; its footer records the selected procedure.                                                                                                                          |
| Refer                               | `FlowActionsDialog`                                                                    | Opens `ReferralDialog`.                                                                                                                                                                                    |
| Follow up                           | `FlowActionsDialog`                                                                    | Opens `FollowUpDialog`.                                                                                                                                                                                    |
| Correct stage                       | `FlowActionsDialog`; stage-correction dialog footer                                    | Opens `CorrectStageDialog`; its footer saves the corrected stage and required reason.                                                                                                                      |
| Print summary                       | `FlowActionsDialog`                                                                    | Opens `PrintOpdSummaryDialog`.                                                                                                                                                                             |
| Open inpatient admission            | `FlowActionsDialog`; post-Admit handoff footer                                         | Navigates to IPD for the pending admission.                                                                                                                                                                |

## Patient, appointment, and encounter dialog actions

| Action button / control          | Locations                                                       | Modal opened or function                                                             |
| -------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Select                           | Patient-picker footer                                           | Returns the selected patient so the caller can open `PatientAppointmentQuickDialog`. |
| Select date                      | Appointment scheduling, rescheduling, and follow-up date fields | Opens the system date picker.                                                        |
| Select time                      | Appointment scheduling, rescheduling, and follow-up time fields | Opens the system time picker.                                                        |
| Date-of-birth picker             | Registration form date-of-birth field                           | Opens the system date picker.                                                        |
| Save anyway                      | Registration dialog primary footer after duplicates are found   | Creates the patient despite the duplicate warning.                                   |
| Edit                             | Reschedule dialog footer                                        | Saves the revised appointment date and time.                                         |
| Start encounter / Edit encounter | Encounter dialog primary footer                                 | Creates a new encounter or saves changes to the active encounter.                    |
| Start new encounter              | Encounter dialog footer                                         | Opens the start-new confirmation dialog.                                             |
| Continue encounter               | Encounter dialog footer                                         | Returns the continue-workflow result for the active encounter.                       |
| Cancel old and start new         | Start-new confirmation destructive footer                       | Cancels the old encounter and forces creation of a new one.                          |

## Flow and clinical dialog actions

| Action button / control             | Locations                                                                      | Modal opened or function                                                                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Coverage verified for this visit    | Consultation-payment insurance panel                                           | Toggles the verification required before an insurance payment can be submitted.                                                                       |
| Save disposition                    | Disposition dialog footer                                                      | Saves Discharge, Send To Pharmacy, Refer Physiotherapy, or Admit. Admit opens `_OpdAdmissionHandoffDialog`; physiotherapy referral opens its handoff. |
| Open physiotherapy                  | Post–Refer Physiotherapy handoff footer                                        | Navigates to Physiotherapy.                                                                                                                           |
| Save referral                       | Referral dialog footer                                                         | Saves the referral.                                                                                                                                   |
| Save follow-up                      | Follow-up dialog footer                                                        | Saves the follow-up date and time.                                                                                                                    |
| Copy summary                        | Print-summary dialog footer                                                    | Copies the OPD summary to the clipboard.                                                                                                              |
| Print                               | Print-summary dialog footer                                                    | Starts the native/browser print workflow.                                                                                                             |
| Add                                 | Diagnosis catalog selection; procedure catalog footer                          | Adds the focused diagnosis or procedure to the staged selection.                                                                                      |
| Delete                              | Selected-diagnosis and selected-procedure managers                             | Removes the focused staged diagnosis or procedure.                                                                                                    |
| Add items                           | Lab-order and procedure-dialog toolbars                                        | Opens `ClinicalLabRequestCatalogDialog` or `ClinicalProcedureCatalogDialog`.                                                                          |
| Add study                           | Radiology-order toolbar                                                        | Opens `ClinicalRadiologyRequestCatalogDialog`.                                                                                                        |
| Add medicine                        | Prescription toolbar                                                           | Opens the prescription-line dialog.                                                                                                                   |
| Edit medicine                       | Selected-medicine row action                                                   | Opens the prescription-line dialog for that medicine.                                                                                                 |
| Remove medicine                     | Selected-medicine row action                                                   | Removes the medicine when removal is allowed.                                                                                                         |
| Remove item / Remove selected       | Lab and radiology row actions/toolbars; remove-confirmation destructive footer | Opens the remove-items confirmation and then removes one or all selected items.                                                                       |
| Review billing                      | Lab, radiology, and prescription toolbars                                      | Opens `_ClinicalRequestBillingDialog`; prescription requires “Pay at prescribe” and at least one line.                                                |
| Favorite test chips                 | Lab catalog favorites                                                          | Stages the selected named test.                                                                                                                       |
| Row checkbox / selection            | Lab and radiology catalog rows                                                 | Stages or unstages the selected item.                                                                                                                 |
| Confirm selected tests or panels    | Lab catalog footer                                                             | Returns the staged lab selection.                                                                                                                     |
| Confirm selected studies            | Radiology catalog footer                                                       | Returns the staged radiology selection.                                                                                                               |
| Bill on dispense / Pay at prescribe | Prescription billing-mode toggles                                              | Selects when prescription charges are collected.                                                                                                      |
| Done                                | Request-billing, prescription-line, and procedure-catalog footers              | Returns billing selections, adds/updates a prescription line, or closes the procedure picker, according to location.                                  |

## Shared dialog actions

| Action button / control | Locations                                                       | Modal opened or function                                                                                                                   |
| ----------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Cancel                  | Footer of dialogs that permit cancellation                      | Dismisses the current dialog without applying its pending action. Advanced-filter and column-settings dialogs do not have a footer Cancel. |
| Close                   | Title bar of all reachable dialogs                              | Dismisses the current dialog; commonly disabled while loading or saving.                                                                   |
| Maximize / Restore      | Title bar of `AppDialog` instances with default window controls | Expands the dialog or restores its previous size. Advanced-filter and column-settings dialogs disable this control.                        |

## Reachable modal chain

This section lists modal relationships without repeating their action labels:

- `_ReceptionPatientPickerDialog` → `PatientAppointmentQuickDialog`
- `RegisterNewPatientDialog`
- `ReceptionAppointmentActionsDialog` → `OpdRescheduleAppointmentDialog`, `OpdCancelAppointmentDialog`, or `OpdEncounterDialog` → start-new confirmation
- `ReceptionQueueActionsDialog` → prioritize text dialog, `_ChangeQueueStatusDialog`, `_AssignQueueDoctorDialog`, or consultation confirmation
- `FlowActionsDialog` (Active visits only; consultation billing actions omitted) → vitals, doctor assignment, clinical free text, diagnosis, lab order, radiology order, prescription, procedure, referral, follow-up, disposition, stage correction, or print-summary dialog
- Payment gate row → read-only outstanding-charge detail (no Billing navigation)
- Lab order → lab catalog, request-billing dialog, or remove-items confirmation
- Radiology order → radiology catalog, request-billing dialog, or remove-items confirmation
- Prescription → prescription-line or request-billing dialog
- Procedure → procedure catalog
- Disposition → inpatient-admission or physiotherapy handoff

`RoutingDecisionDialog` is not included: routing in `RecordVitalsDialog` is inline, and the separate route-decision action is not present in the flow action order reachable from `/reception`. Consultation payment and Billing workbench controls are intentionally absent from `/reception`; authorized Billing entry points remain available from other workspaces.

## Reception helpers not reachable from `/reception`

These reception-feature helpers have no call site from the page or its reachable dialogs, so they are excluded from the inventory:

| Helper                          | Would open or do         |
| ------------------------------- | ------------------------ |
| `openReceptionInsuranceCapture` | Claims enrollment dialog |

## Main implementation sources

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_queue_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/`
- `frontend/lib/shared/clinical_actions/dialogs/`
- `frontend/lib/shared/workflow_actions/`
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
