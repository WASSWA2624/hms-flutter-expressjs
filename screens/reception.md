# Action Button Inventory — `/reception`

Source of truth: Dart presentation widgets. English labels come from `app_localizations_en.dart`.

- Primary page: `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- Route: `AppRoutes.reception` → `/reception`
- Scope: controls reachable from `/reception`, including nested dialogs
- Convention: every action is listed once; the **Locations** column combines every place where it is used

Visibility may depend on the selected tab, workflow stage, record state, role, permission, tenant configuration, or enabled module.

## Page, search, and table actions

| Action button / control | Locations | Modal opened or function |
| --- | --- | --- |
| Appointments | Page tab strip | Shows the Appointments section and updates the URL. |
| Desk queue | Page tab strip | Shows the Desk queue section and updates the URL. |
| Active visits | Page tab strip | Shows the Active visits section and updates the URL. |
| Payment gate | Page tab strip | Shows the Payment gate section and updates the URL. |
| Schedule appointment | Appointments primary toolbar; patient appointment dialog footer | Opens `_ReceptionPatientPickerDialog`, then `PatientAppointmentQuickDialog`; in the final dialog, creates the appointment. |
| Register patient | Appointments secondary toolbar; Desk queue and Active visits primary toolbar; registration dialog footer | Opens `RegisterNewPatientDialog`; in its footer, runs duplicate detection and creates the patient. |
| Billing | Payment gate primary toolbar | Navigates to `/billing`. |
| Refresh | Secondary toolbar on every tab | Reloads the OPD workspace; shows a loading state while running. |
| Full registry | Appointments secondary toolbar | Navigates to `/patients`. |
| Full OPD | Desk queue, Active visits, and Payment gate secondary toolbars | Navigates to `/opd`. |
| Try again | Workspace load-error state | Retries loading the OPD workspace. |
| Filters | Search toolbar on every tab; lab and radiology catalog tables | Opens the relevant advanced-filter modal. |
| Clear filters | Search-field suffix when a query exists; advanced-filter modal footer | In the search field, clears only the query; in the filter modal, resets selected filters. |
| Apply filters | Advanced-filter modal footer | Applies the selected status, stage, or catalog filters. |
| Settings | Table toolbar on every tab; lab and radiology catalog tables | Opens the shared column-visibility modal. |
| Apply columns | Column-settings modal footer | Saves the selected visible columns. |
| Reset columns | Column-settings modal footer | Restores the default visible columns. |
| Sort column | Sortable table headers | Sorts the table by the selected column. |
| Row / card tap | Appointment, queue, Active visits, and Payment gate rows/cards | Opens `ReceptionAppointmentActionsDialog`; `ReceptionQueueActionsDialog` when no linked appointment is found; or `FlowActionsDialog` for active/payment flows. |

## Appointment, queue, and workflow actions

| Action button / control | Locations | Modal opened or function |
| --- | --- | --- |
| Start OPD encounter | Appointment next-action column/mobile action; appointment-actions grid | From a row, opens `ReceptionAppointmentActionsDialog`; from its grid, opens `OpdEncounterDialog`. |
| Queue | Appointment-actions grid; rare appointment next-action fallback | Adds the appointment to the queue. The row fallback is effectively unreachable for currently visible statuses. |
| Reschedule | Appointment-actions grid; appointment next-action for an in-progress status | Opens `OpdRescheduleAppointmentDialog`. |
| Cancel appointment | Appointment-actions grid; cancellation dialog destructive footer | Opens `OpdCancelAppointmentDialog`; in that dialog, confirms cancellation with an optional reason. |
| Prioritize | Queue-actions grid; prioritize dialog footer | Opens `AppTextActionDialog`; in that dialog, submits the optional priority reason. |
| Move | Queue-actions grid; move dialog footer | Opens `_MoveQueueDialog`; in that dialog, changes queue status/provider. |
| Start consultation | Queue next-action column/mobile action; queue-actions grid; confirmation footer | For a queue row with an ID, the workflow control is disabled because `START_CONSULTATION` has no registry definition. The blank-ID fallback opens the row hub. From the grid it opens `AppConfirmActionDialog`, whose footer starts the consultation. |
| Pay consultation / Edit consultation billing / Manage consultation billing | Active visits and Payment gate next-action; `FlowActionsDialog`; consultation-payment footer | The compact workflow action routes to `/billing?...&action=pay` when no dialog opener resolves. The flow hub opens `ConsultationPaymentDialog`; its footer creates or updates consultation billing. |
| Record vitals / Edit vitals | Active visits and Payment gate next-action; `FlowActionsDialog`; vitals dialog footer | Compact action routes to Nursing. The flow hub opens `RecordVitalsDialog`; its footer saves vitals and any inline routing selection. |
| Assign doctor / Change doctor | Active visits and Payment gate next-action; denied-action fallback; `FlowActionsDialog`; assignment dialog footer | Opens `AssignDoctorDialog`; its footer saves the selected provider. |
| Doctor review | Active visits and Payment gate next-action; `FlowActionsDialog`; clinical free-text dialog footer | Compact action routes to Clinical. The flow hub opens `ClinicalFreeTextActionDialog`; its footer submits the required clinical note. |
| Collect sample / diagnostic handoff | Active visits and Payment gate next-action; `FlowActionsDialog` dynamic handoff | Routes to Laboratory or the module appropriate for the current diagnostic stage. |
| Perform imaging | Active visits and Payment gate next-action; `FlowActionsDialog` dynamic handoff | Routes to Radiology. |
| Dispense medicine | Active visits and Payment gate next-action; `FlowActionsDialog` dynamic handoff | Routes to Pharmacy. |
| Disposition / Complete disposition | Active visits and Payment gate next-action; `FlowActionsDialog` | Compact action routes to Clinical disposition; the flow hub opens `OpdDispositionDialog`. |
| Unsupported action code | Active visits and Payment gate next-action | Displays a generated title-cased label but remains disabled. |
| Add diagnosis | `FlowActionsDialog`; diagnosis dialog footer | Opens `ClinicalDiagnosisActionDialog`; its footer submits selected diagnoses. |
| Request lab | `FlowActionsDialog`; lab-order dialog footer | Opens `ClinicalLabOrderActionDialog`; its footer submits the staged lab requests. |
| Request radiology | `FlowActionsDialog`; radiology-order dialog footer | Opens `ClinicalRadiologyOrderActionDialog`; its footer submits the staged studies. |
| Prescribe | `FlowActionsDialog`; prescription dialog footer | Opens `ClinicalPrescriptionActionDialog`; its footer submits the prescription. |
| Record procedure | `FlowActionsDialog`; procedure dialog footer | Opens `ClinicalProcedureActionDialog`; its footer records the selected procedure. |
| Refer | `FlowActionsDialog` | Opens `ReferralDialog`. |
| Follow up | `FlowActionsDialog` | Opens `FollowUpDialog`. |
| Correct stage | `FlowActionsDialog`; stage-correction dialog footer | Opens `CorrectStageDialog`; its footer saves the corrected stage and required reason. |
| Print summary | `FlowActionsDialog` | Opens `PrintOpdSummaryDialog`. |
| Open inpatient admission | `FlowActionsDialog`; post-Admit handoff footer | Navigates to IPD for the pending admission. |

## Patient, appointment, and encounter dialog actions

| Action button / control | Locations | Modal opened or function |
| --- | --- | --- |
| Select | Patient-picker footer | Returns the selected patient so the caller can open `PatientAppointmentQuickDialog`. |
| Select date | Appointment scheduling, rescheduling, and follow-up date fields | Opens the system date picker. |
| Select time | Appointment scheduling, rescheduling, and follow-up time fields | Opens the system time picker. |
| Date-of-birth picker | Registration form date-of-birth field | Opens the system date picker. |
| Save anyway | Registration dialog primary footer after duplicates are found | Creates the patient despite the duplicate warning. |
| Edit | Reschedule dialog footer | Saves the revised appointment date and time. |
| Start encounter / Edit encounter | Encounter dialog primary footer | Creates a new encounter or saves changes to the active encounter. |
| Start new encounter | Encounter dialog footer | Opens the start-new confirmation dialog. |
| Continue encounter | Encounter dialog footer | Returns the continue-workflow result for the active encounter. |
| Cancel old and start new | Start-new confirmation destructive footer | Cancels the old encounter and forces creation of a new one. |

## Flow and clinical dialog actions

| Action button / control | Locations | Modal opened or function |
| --- | --- | --- |
| Coverage verified for this visit | Consultation-payment insurance panel | Toggles the verification required before an insurance payment can be submitted. |
| Save disposition | Disposition dialog footer | Saves Discharge, Send To Pharmacy, Refer Physiotherapy, or Admit. Admit opens `_OpdAdmissionHandoffDialog`; physiotherapy referral opens its handoff. |
| Open physiotherapy | Post–Refer Physiotherapy handoff footer | Navigates to Physiotherapy. |
| Save referral | Referral dialog footer | Saves the referral. |
| Save follow-up | Follow-up dialog footer | Saves the follow-up date and time. |
| Copy summary | Print-summary dialog footer | Copies the OPD summary to the clipboard. |
| Print | Print-summary dialog footer | Starts the native/browser print workflow. |
| Add | Diagnosis catalog selection; procedure catalog footer | Adds the focused diagnosis or procedure to the staged selection. |
| Delete | Selected-diagnosis and selected-procedure managers | Removes the focused staged diagnosis or procedure. |
| Add items | Lab-order and procedure-dialog toolbars | Opens `ClinicalLabRequestCatalogDialog` or `ClinicalProcedureCatalogDialog`. |
| Add study | Radiology-order toolbar | Opens `ClinicalRadiologyRequestCatalogDialog`. |
| Add medicine | Prescription toolbar | Opens the prescription-line dialog. |
| Edit medicine | Selected-medicine row action | Opens the prescription-line dialog for that medicine. |
| Remove medicine | Selected-medicine row action | Removes the medicine when removal is allowed. |
| Remove item / Remove selected | Lab and radiology row actions/toolbars; remove-confirmation destructive footer | Opens the remove-items confirmation and then removes one or all selected items. |
| Review billing | Lab, radiology, and prescription toolbars | Opens `_ClinicalRequestBillingDialog`; prescription requires “Pay at prescribe” and at least one line. |
| Favorite test chips | Lab catalog favorites | Stages the selected named test. |
| Row checkbox / selection | Lab and radiology catalog rows | Stages or unstages the selected item. |
| Confirm selected tests or panels | Lab catalog footer | Returns the staged lab selection. |
| Confirm selected studies | Radiology catalog footer | Returns the staged radiology selection. |
| Bill on dispense / Pay at prescribe | Prescription billing-mode toggles | Selects when prescription charges are collected. |
| Done | Request-billing, prescription-line, and procedure-catalog footers | Returns billing selections, adds/updates a prescription line, or closes the procedure picker, according to location. |

## Shared dialog actions

| Action button / control | Locations | Modal opened or function |
| --- | --- | --- |
| Cancel | Footer of dialogs that permit cancellation | Dismisses the current dialog without applying its pending action. Advanced-filter and column-settings dialogs do not have a footer Cancel. |
| Close | Title bar of all reachable dialogs | Dismisses the current dialog; commonly disabled while loading or saving. |
| Maximize / Restore | Title bar of `AppDialog` instances with default window controls | Expands the dialog or restores its previous size. Advanced-filter and column-settings dialogs disable this control. |

## Reachable modal chain

This section lists modal relationships without repeating their action labels:

- `_ReceptionPatientPickerDialog` → `PatientAppointmentQuickDialog`
- `RegisterNewPatientDialog`
- `ReceptionAppointmentActionsDialog` → `OpdRescheduleAppointmentDialog`, `OpdCancelAppointmentDialog`, or `OpdEncounterDialog` → start-new confirmation
- `ReceptionQueueActionsDialog` → prioritize text dialog, `_MoveQueueDialog`, or consultation confirmation
- `FlowActionsDialog` → consultation payment, vitals, doctor assignment, clinical free text, diagnosis, lab order, radiology order, prescription, procedure, referral, follow-up, disposition, stage correction, or print-summary dialog
- Lab order → lab catalog, request-billing dialog, or remove-items confirmation
- Radiology order → radiology catalog, request-billing dialog, or remove-items confirmation
- Prescription → prescription-line or request-billing dialog
- Procedure → procedure catalog
- Disposition → inpatient-admission or physiotherapy handoff

`RoutingDecisionDialog` is not included: routing in `RecordVitalsDialog` is inline, and the separate route-decision action is not present in the flow action order reachable from `/reception`.

## Reception helpers not reachable from `/reception`

These reception-feature helpers have no call site from the page or its reachable dialogs, so they are excluded from the inventory:

| Helper | Would open or do |
| --- | --- |
| `openReceptionPatientEditor` | `showPatientDetailDialog` |
| `openReceptionInsuranceCapture` | Claims enrollment dialog |
| `ReceptionBillingGuidancePanel` | “Open billing workbench” would navigate to Billing |

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
