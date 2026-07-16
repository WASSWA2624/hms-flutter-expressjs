# Patient encounter flow — dialog prompts

One actionable agent prompt per inventory row in [`02-patient-encounter-flow.md`](02-patient-encounter-flow.md).
Normative contract: [`../prompt.md`](../prompt.md) (also [`../.cursor/api-contract.mdc`](../.cursor/api-contract.mdc), [`../frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc)).

Prompt files live in [`../prompts/`](../prompts/) (named `NN-<dialog-slug>.md`). `run_prompts.py` executes every `prompts/*.md` — keep this index here so it is not mistaken for an implementation brief.

Regenerate with:

```bash
python tool/generate_encounter_dialog_prompts.py
```

| # | Prompt | Symbol | Purpose |
| --- | --- | --- | --- |
| 01 | [`../prompts/01-emergency-quick-arrival-dialog.md`](../prompts/01-emergency-quick-arrival-dialog.md) | `QuickArrivalDialog` | Patient/encounter flow: Quick Arrival (emergency). |
| 02 | [`../prompts/02-emergency-dispatch-dialog.md`](../prompts/02-emergency-dispatch-dialog.md) | `DispatchDialog` | Patient/encounter flow: Dispatch (emergency). |
| 03 | [`../prompts/03-emergency-handoff-dialog.md`](../prompts/03-emergency-handoff-dialog.md) | `HandoffDialog` | Patient/encounter flow: Handoff (emergency). |
| 04 | [`../prompts/04-emergency-open-priority-dialog.md`](../prompts/04-emergency-open-priority-dialog.md) | `_openPriorityDialog` | Patient/encounter flow: Priority (emergency). |
| 05 | [`../prompts/05-emergency-open-response-dialog.md`](../prompts/05-emergency-open-response-dialog.md) | `_openResponseDialog` | Patient/encounter flow: Response (emergency). |
| 06 | [`../prompts/06-housekeeping-show-triage-dialog.md`](../prompts/06-housekeeping-show-triage-dialog.md) | `_showTriageDialog` | Patient/encounter flow: Triage (housekeeping). |
| 07 | [`../prompts/07-icu-transfer-request-dialog.md`](../prompts/07-icu-transfer-request-dialog.md) | `_TransferRequestDialog` | Patient/encounter flow: Transfer Request (icu). |
| 08 | [`../prompts/08-icu-assign-bed-dialog.md`](../prompts/08-icu-assign-bed-dialog.md) | `_AssignBedDialog` | Patient/encounter flow: Assign Bed (icu). |
| 09 | [`../prompts/09-ipd-release-bed-dialog.md`](../prompts/09-ipd-release-bed-dialog.md) | `_openReleaseBedDialog` | Patient/encounter flow: Release Bed (ipd). |
| 10 | [`../prompts/10-ipd-transfer-request-dialog.md`](../prompts/10-ipd-transfer-request-dialog.md) | `TransferRequestDialog` | Patient/encounter flow: Transfer Request (ipd). |
| 11 | [`../prompts/11-ipd-transfer-update-dialog.md`](../prompts/11-ipd-transfer-update-dialog.md) | `TransferUpdateDialog` | Patient/encounter flow: Transfer Update (ipd). |
| 12 | [`../prompts/12-ipd-start-admission-dialog.md`](../prompts/12-ipd-start-admission-dialog.md) | `IpdStartAdmissionDialog` | Patient/encounter flow: Ipd Start Admission (ipd). |
| 13 | [`../prompts/13-opd-queue-actions-dialog.md`](../prompts/13-opd-queue-actions-dialog.md) | `QueueActionsDialog` | Patient/encounter flow: Queue Actions (opd). |
| 14 | [`../prompts/14-patients-patient-appointment-quick-dialog.md`](../prompts/14-patients-patient-appointment-quick-dialog.md) | `PatientAppointmentQuickDialog` | Patient/encounter flow: Patient Appointment Quick (patients). |
| 15 | [`../prompts/15-patients-patient-triage-quick-dialog.md`](../prompts/15-patients-patient-triage-quick-dialog.md) | `_PatientTriageQuickDialog` | Patient/encounter flow: Patient Triage Quick (patients). |
| 16 | [`../prompts/16-patients-patient-admission-quick-dialog.md`](../prompts/16-patients-patient-admission-quick-dialog.md) | `_PatientAdmissionQuickDialog` | Patient/encounter flow: Patient Admission Quick (patients). |
| 17 | [`../prompts/17-patients-patient-flow-quick-dialog.md`](../prompts/17-patients-patient-flow-quick-dialog.md) | `_PatientFlowQuickDialog` | Patient/encounter flow: Patient Flow Quick (patients). |
| 18 | [`../prompts/18-reception-patient-picker-dialog.md`](../prompts/18-reception-patient-picker-dialog.md) | `_ReceptionPatientPickerDialog` | Patient/encounter flow: Reception Patient Picker (reception). |
| 19 | [`../prompts/19-reception-queue-actions-dialog.md`](../prompts/19-reception-queue-actions-dialog.md) | `ReceptionQueueActionsDialog` | Patient/encounter flow: Reception Queue Actions (reception). |
| 20 | [`../prompts/20-rooms-beds-show-transfer-update-dialog.md`](../prompts/20-rooms-beds-show-transfer-update-dialog.md) | `_showTransferUpdateDialog` | Patient/encounter flow: Transfer Update (rooms_beds). |
| 21 | [`../prompts/21-app-triage-action-dialog.md`](../prompts/21-app-triage-action-dialog.md) | `AppTriageActionDialog` | Shared triage action dialog. |
| 22 | [`../prompts/22-opd-encounter-dialog.md`](../prompts/22-opd-encounter-dialog.md) | `OpdEncounterDialog` | Patient/encounter flow: Opd Encounter (shared/components). |
| 23 | [`../prompts/23-close-encounter-dialog.md`](../prompts/23-close-encounter-dialog.md) | `_CloseEncounterDialog` | Patient/encounter flow: Close Encounter (shared/components). |
| 24 | [`../prompts/24-cancel-encounter-dialog.md`](../prompts/24-cancel-encounter-dialog.md) | `_CancelEncounterDialog` | Patient/encounter flow: Cancel Encounter (shared/components). |
| 25 | [`../prompts/25-show-opd-encounter-dialog.md`](../prompts/25-show-opd-encounter-dialog.md) | `showOpdEncounterDialog` | Open the OPD encounter workspace dialog. |
| 26 | [`../prompts/26-opd-appointment-actions-dialog.md`](../prompts/26-opd-appointment-actions-dialog.md) | `OpdAppointmentActionsDialog` | Patient/encounter flow: Opd Appointment Actions (shared/opd_actions). |
| 27 | [`../prompts/27-opd-reschedule-appointment-dialog.md`](../prompts/27-opd-reschedule-appointment-dialog.md) | `OpdRescheduleAppointmentDialog` | Patient/encounter flow: Opd Reschedule Appointment (shared/opd_actions). |
| 28 | [`../prompts/28-opd-cancel-appointment-dialog.md`](../prompts/28-opd-cancel-appointment-dialog.md) | `OpdCancelAppointmentDialog` | Patient/encounter flow: Opd Cancel Appointment (shared/opd_actions). |
| 29 | [`../prompts/29-patient-pinned-opd-encounter-dialog.md`](../prompts/29-patient-pinned-opd-encounter-dialog.md) | `PatientPinnedOpdEncounterDialog` | Patient/encounter flow: Patient Pinned Opd Encounter (shared/opd_actions). |
| 30 | [`../prompts/30-flow-actions-dialog.md`](../prompts/30-flow-actions-dialog.md) | `FlowActionsDialog` | OPD queue/flow stage actions hub. |
| 31 | [`../prompts/31-consultation-payment-dialog.md`](../prompts/31-consultation-payment-dialog.md) | `ConsultationPaymentDialog` | Patient/encounter flow: Consultation Payment (shared/opd_actions). |
| 32 | [`../prompts/32-correct-stage-dialog.md`](../prompts/32-correct-stage-dialog.md) | `CorrectStageDialog` | Patient/encounter flow: Correct Stage (shared/opd_actions). |
| 33 | [`../prompts/33-assign-doctor-dialog.md`](../prompts/33-assign-doctor-dialog.md) | `AssignDoctorDialog` | Patient/encounter flow: Assign Doctor (shared/opd_actions). |
| 34 | [`../prompts/34-routing-decision-dialog.md`](../prompts/34-routing-decision-dialog.md) | `RoutingDecisionDialog` | Patient/encounter flow: Routing Decision (shared/opd_actions). |
| 35 | [`../prompts/35-opd-disposition-dialog.md`](../prompts/35-opd-disposition-dialog.md) | `OpdDispositionDialog` | Patient/encounter flow: Opd Disposition (shared/opd_actions). |
| 36 | [`../prompts/36-opd-admission-handoff-dialog.md`](../prompts/36-opd-admission-handoff-dialog.md) | `_OpdAdmissionHandoffDialog` | Patient/encounter flow: Opd Admission Handoff (shared/opd_actions). |
| 37 | [`../prompts/37-referral-dialog.md`](../prompts/37-referral-dialog.md) | `ReferralDialog` | Patient/encounter flow: Referral (shared/opd_actions). |
| 38 | [`../prompts/38-follow-up-dialog.md`](../prompts/38-follow-up-dialog.md) | `FollowUpDialog` | Patient/encounter flow: Follow Up (shared/opd_actions). |
| 39 | [`../prompts/39-print-opd-summary-dialog.md`](../prompts/39-print-opd-summary-dialog.md) | `PrintOpdSummaryDialog` | Patient/encounter flow: Print Opd Summary (shared/opd_actions). |
| 40 | [`../prompts/40-record-vitals-dialog.md`](../prompts/40-record-vitals-dialog.md) | `RecordVitalsDialog` | Patient/encounter flow: Record Vitals (shared/opd_actions). |
| 41 | [`../prompts/41-register-new-patient-dialog.md`](../prompts/41-register-new-patient-dialog.md) | `RegisterNewPatientDialog` | Register a new patient. |
