# Patient encounter flow — dialog prompts

One actionable agent prompt per inventory row in [`02-patient-encounter-flow.md`](02-patient-encounter-flow.md).
Normative contract: [`../prompt.md`](../prompt.md) (also [`../.cursor/api-contract.mdc`](../.cursor/api-contract.mdc), [`../frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc), [`../frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)).

Prompt files live in [`../prompts/`](../prompts/) (named `NN-<dialog-slug>.md`). `run_prompts.py` executes every `prompts/*.md` — keep this index here so it is not mistaken for an implementation brief.

Each prompt is generated to be actionable, professional, contextual, specific, and complete against `prompt.md` (shells, reuse, loading/actions, titles, backend sync, verification).

Regenerate with:

```bash
python tool/generate_encounter_dialog_prompts.py
```

| # | Prompt | Symbol | Purpose |
| --- | --- | --- | --- |
| 01 | [`../prompts/01-emergency-quick-arrival-dialog.md`](../prompts/01-emergency-quick-arrival-dialog.md) | `QuickArrivalDialog` | Quick Arrival |
| 02 | [`../prompts/02-emergency-dispatch-dialog.md`](../prompts/02-emergency-dispatch-dialog.md) | `DispatchDialog` | Dispatch |
| 03 | [`../prompts/03-emergency-handoff-dialog.md`](../prompts/03-emergency-handoff-dialog.md) | `HandoffDialog` | Handoff |
| 04 | [`../prompts/04-emergency-open-priority-dialog.md`](../prompts/04-emergency-open-priority-dialog.md) | `_openPriorityDialog` | Priority |
| 05 | [`../prompts/05-emergency-open-response-dialog.md`](../prompts/05-emergency-open-response-dialog.md) | `_openResponseDialog` | Response |
| 06 | [`../prompts/06-housekeeping-show-triage-dialog.md`](../prompts/06-housekeeping-show-triage-dialog.md) | `_showTriageDialog` | Triage |
| 07 | [`../prompts/07-icu-transfer-request-dialog.md`](../prompts/07-icu-transfer-request-dialog.md) | `_TransferRequestDialog` | Transfer Request |
| 08 | [`../prompts/08-icu-assign-bed-dialog.md`](../prompts/08-icu-assign-bed-dialog.md) | `_AssignBedDialog` | Assign Bed |
| 09 | [`../prompts/09-ipd-release-bed-dialog.md`](../prompts/09-ipd-release-bed-dialog.md) | `_openReleaseBedDialog` | Release Bed |
| 10 | [`../prompts/10-ipd-transfer-request-dialog.md`](../prompts/10-ipd-transfer-request-dialog.md) | `TransferRequestDialog` | Transfer Request |
| 11 | [`../prompts/11-ipd-transfer-update-dialog.md`](../prompts/11-ipd-transfer-update-dialog.md) | `TransferUpdateDialog` | Transfer Update |
| 12 | [`../prompts/12-ipd-start-admission-dialog.md`](../prompts/12-ipd-start-admission-dialog.md) | `IpdStartAdmissionDialog` | Ipd Start Admission |
| 13 | [`../prompts/13-opd-queue-actions-dialog.md`](../prompts/13-opd-queue-actions-dialog.md) | `QueueActionsDialog` | Queue Actions |
| 14 | [`../prompts/14-patients-patient-appointment-quick-dialog.md`](../prompts/14-patients-patient-appointment-quick-dialog.md) | `PatientAppointmentQuickDialog` | Patient Appointment Quick |
| 15 | [`../prompts/15-patients-patient-triage-quick-dialog.md`](../prompts/15-patients-patient-triage-quick-dialog.md) | `_PatientTriageQuickDialog` | Patient Triage Quick |
| 16 | [`../prompts/16-patients-patient-admission-quick-dialog.md`](../prompts/16-patients-patient-admission-quick-dialog.md) | `_PatientAdmissionQuickDialog` | Patient Admission Quick |
| 17 | [`../prompts/17-patients-patient-flow-quick-dialog.md`](../prompts/17-patients-patient-flow-quick-dialog.md) | `_PatientFlowQuickDialog` | Patient Flow Quick |
| 18 | [`../prompts/18-reception-patient-picker-dialog.md`](../prompts/18-reception-patient-picker-dialog.md) | `_ReceptionPatientPickerDialog` | Reception Patient Picker |
| 19 | [`../prompts/19-reception-queue-actions-dialog.md`](../prompts/19-reception-queue-actions-dialog.md) | `ReceptionQueueActionsDialog` | Reception Queue Actions |
| 20 | [`../prompts/20-rooms-beds-show-transfer-update-dialog.md`](../prompts/20-rooms-beds-show-transfer-update-dialog.md) | `_showTransferUpdateDialog` | Transfer Update |
| 21 | [`../prompts/21-app-triage-action-dialog.md`](../prompts/21-app-triage-action-dialog.md) | `AppTriageActionDialog` | Shared triage action dialog |
| 22 | [`../prompts/22-opd-encounter-dialog.md`](../prompts/22-opd-encounter-dialog.md) | `OpdEncounterDialog` | Opd Encounter |
| 23 | [`../prompts/23-close-encounter-dialog.md`](../prompts/23-close-encounter-dialog.md) | `_CloseEncounterDialog` | Close Encounter |
| 24 | [`../prompts/24-cancel-encounter-dialog.md`](../prompts/24-cancel-encounter-dialog.md) | `_CancelEncounterDialog` | Cancel Encounter |
| 25 | [`../prompts/25-show-opd-encounter-dialog.md`](../prompts/25-show-opd-encounter-dialog.md) | `showOpdEncounterDialog` | Open the OPD encounter workspace dialog |
| 26 | [`../prompts/26-opd-appointment-actions-dialog.md`](../prompts/26-opd-appointment-actions-dialog.md) | `OpdAppointmentActionsDialog` | Opd Appointment Actions |
| 27 | [`../prompts/27-opd-reschedule-appointment-dialog.md`](../prompts/27-opd-reschedule-appointment-dialog.md) | `OpdRescheduleAppointmentDialog` | Opd Reschedule Appointment |
| 28 | [`../prompts/28-opd-cancel-appointment-dialog.md`](../prompts/28-opd-cancel-appointment-dialog.md) | `OpdCancelAppointmentDialog` | Opd Cancel Appointment |
| 29 | [`../prompts/29-patient-pinned-opd-encounter-dialog.md`](../prompts/29-patient-pinned-opd-encounter-dialog.md) | `PatientPinnedOpdEncounterDialog` | Patient Pinned Opd Encounter |
| 30 | [`../prompts/30-flow-actions-dialog.md`](../prompts/30-flow-actions-dialog.md) | `FlowActionsDialog` | OPD queue/flow stage actions hub |
| 31 | [`../prompts/31-consultation-payment-dialog.md`](../prompts/31-consultation-payment-dialog.md) | `ConsultationPaymentDialog` | Consultation Payment |
| 32 | [`../prompts/32-correct-stage-dialog.md`](../prompts/32-correct-stage-dialog.md) | `CorrectStageDialog` | Correct Stage |
| 33 | [`../prompts/33-assign-doctor-dialog.md`](../prompts/33-assign-doctor-dialog.md) | `AssignDoctorDialog` | Assign Doctor |
| 34 | [`../prompts/34-routing-decision-dialog.md`](../prompts/34-routing-decision-dialog.md) | `RoutingDecisionDialog` | Routing Decision |
| 35 | [`../prompts/35-opd-disposition-dialog.md`](../prompts/35-opd-disposition-dialog.md) | `OpdDispositionDialog` | Opd Disposition |
| 36 | [`../prompts/36-opd-admission-handoff-dialog.md`](../prompts/36-opd-admission-handoff-dialog.md) | `_OpdAdmissionHandoffDialog` | Opd Admission Handoff |
| 37 | [`../prompts/37-referral-dialog.md`](../prompts/37-referral-dialog.md) | `ReferralDialog` | Referral |
| 38 | [`../prompts/38-follow-up-dialog.md`](../prompts/38-follow-up-dialog.md) | `FollowUpDialog` | Follow Up |
| 39 | [`../prompts/39-print-opd-summary-dialog.md`](../prompts/39-print-opd-summary-dialog.md) | `PrintOpdSummaryDialog` | Print Opd Summary |
| 40 | [`../prompts/40-record-vitals-dialog.md`](../prompts/40-record-vitals-dialog.md) | `RecordVitalsDialog` | Record Vitals |
| 41 | [`../prompts/41-register-new-patient-dialog.md`](../prompts/41-register-new-patient-dialog.md) | `RegisterNewPatientDialog` | Register a new patient |
