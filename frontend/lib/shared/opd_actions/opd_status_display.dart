import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

String opdStatusDisplayLabel(AppLocalizations l10n, OpdFlowSummary flow) {
  final String code = (flow.displayCode ?? flow.stage ?? '')
      .trim()
      .toUpperCase();
  return _opdLabel(l10n, code) ??
      flow.displayStatus ??
      AppDisplay.apiLabel(code);
}

String opdStageDisplayLabel(AppLocalizations l10n, String? value) {
  final String code = (value ?? '').trim().toUpperCase();
  return _opdLabel(l10n, code) ?? AppDisplay.apiLabel(code);
}

String opdNextStepDisplayLabel(AppLocalizations l10n, String? value) {
  final String code = (value ?? '').trim().toUpperCase();
  return _nextStepLabel(l10n, code) ??
      _opdLabel(l10n, code) ??
      AppDisplay.apiLabel(code);
}

String opdSummaryCountLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'all_patients' => l10n.opdSummaryAllPatientsLabel,
    'all_opd_patients' => l10n.opdSummaryAllOpdPatientsLabel,
    'active_opd' => l10n.opdSummaryActiveOpdLabel,
    'vitals_needed' => l10n.opdSummaryVitalsNeededLabel,
    'doctor_needed' => l10n.opdSummaryDoctorNeededLabel,
    'with_doctor' => l10n.opdSummaryWithDoctorLabel,
    'lab_pending' => l10n.opdSummaryLabPendingLabel,
    'imaging_pending' => l10n.opdSummaryImagingPendingLabel,
    'pharmacy_pending' => l10n.opdSummaryPharmacyPendingLabel,
    'decision_needed' => l10n.opdSummaryDecisionNeededLabel,
    'admission_pending' => l10n.opdSummaryAdmissionPendingLabel,
    'discharged_today' => l10n.opdSummaryDischargedTodayLabel,
    _ => AppDisplay.apiLabel(key),
  };
}

String? _opdLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' => l10n.opdStatusPaymentDueLabel,
    'VITALS_NEEDED' || 'WAITING_VITALS' => l10n.opdStatusVitalsNeededLabel,
    'DOCTOR_NEEDED' ||
    'WAITING_DOCTOR_ASSIGNMENT' => l10n.opdStatusDoctorNeededLabel,
    'WITH_DOCTOR' => l10n.opdStatusWithDoctorLabel,
    'WAITING_DOCTOR_REVIEW' => l10n.opdStatusDoctorReviewLabel,
    'LAB_PENDING' || 'LAB_REQUESTED' => l10n.opdStatusLabPendingLabel,
    'SAMPLE_PENDING' => l10n.opdStatusSamplePendingLabel,
    'IN_LAB' => l10n.opdStatusInLabLabel,
    'RESULTS_READY' => l10n.opdStatusResultsReadyLabel,
    'IMAGING_PENDING' ||
    'RADIOLOGY_REQUESTED' => l10n.opdStatusImagingPendingLabel,
    'REPORT_PENDING' => l10n.opdStatusReportPendingLabel,
    'REPORT_READY' => l10n.opdStatusReportReadyLabel,
    'LAB_AND_RADIOLOGY_REQUESTED' =>
      l10n.opdStatusLabAndImagingPendingLabel,
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' => l10n.opdStatusPharmacyPendingLabel,
    'DISPENSING' => l10n.opdStatusDispensingLabel,
    'MEDICINES_DISPENSED' => l10n.opdStatusMedicinesDispensedLabel,
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' => l10n.opdStatusDecisionNeededLabel,
    'ADMISSION_PENDING' => l10n.opdStatusAdmissionPendingLabel,
    'ADMITTED' => l10n.opdStatusAdmittedLabel,
    'DISCHARGED' => l10n.opdStatusDischargedLabel,
    _ => null,
  };
}

String? _nextStepLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'PAY_CONSULTATION' => l10n.opdPayConsultationAction,
    'RECORD_VITALS' => l10n.opdRecordVitalsAction,
    'ASSIGN_DOCTOR' => l10n.opdAssignDoctorAction,
    'DOCTOR_REVIEW' => l10n.opdDoctorReviewAction,
    'COLLECT_SAMPLE' => l10n.opdNextCollectSampleLabel,
    'PROCESS_LAB' => l10n.opdNextProcessLabLabel,
    'REVIEW_RESULTS' => l10n.opdNextReviewResultsLabel,
    'LAB_WORKSPACE' => l10n.opdNextLabHandoffLabel,
    'PERFORM_IMAGING' => l10n.opdNextPerformImagingLabel,
    'COMPLETE_IMAGING_REPORT' => l10n.opdNextCompleteImagingReportLabel,
    'REVIEW_REPORT' => l10n.opdNextReviewReportLabel,
    'RADIOLOGY_WORKSPACE' => l10n.opdNextImagingHandoffLabel,
    'DIAGNOSTICS_PENDING' => l10n.opdNextDiagnosticsPendingLabel,
    'DISPENSE_MEDICINE' => l10n.opdNextDispenseMedicineLabel,
    'PHARMACY_WORKSPACE' => l10n.opdNextPharmacyHandoffLabel,
    'DISPOSITION' => l10n.opdNextDispositionLabel,
    'ADMISSION_HANDOFF' => l10n.opdNextAdmissionHandoffLabel,
    _ => null,
  };
}

