import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';

/// Resolves the stage next-action key shared by Flow Actions and the OPD board.
///
/// Keys match Flow Actions quick-action ids: `billing`, `vitals`,
/// `assign_doctor`, `doctor_review`, `handoff`, `disposition`,
/// `admission_handoff`, `correct_stage`.
String resolveOpdFlowNextActionKey(
  OpdFlowSummary flow, {
  OpdFlowDetail? detail,
}) {
  final String stage = (flow.stage ?? '').trim().toUpperCase();
  final String displayCode = (flow.displayCode ?? '').trim().toUpperCase();
  final bool consultationPaid =
      detail?.consultationPaid ?? flow.consultationPaid;
  final bool consultationPaymentRequired =
      detail?.consultationPaymentRequired ??
      flow.consultationPaymentRequired ||
          stage == 'WAITING_CONSULTATION_PAYMENT';
  final bool canPayNow =
      !consultationPaid &&
      (stage == 'WAITING_CONSULTATION_PAYMENT' || consultationPaymentRequired);
  final bool hasAssignedProvider =
      _isNonEmpty(flow.providerUserId) ||
      _isNonEmpty(flow.providerDisplayName) ||
      _isNonEmpty(flow.assignedStaffDisplayName);
  final bool hasPendingAdmission = opdFlowHasPendingAdmission(flow, detail);

  return switch (displayCode) {
    'PAYMENT_DUE' => canPayNow ? 'billing' : 'correct_stage',
    'VITALS_NEEDED' => 'vitals',
    'DOCTOR_NEEDED' => 'assign_doctor',
    'WITH_DOCTOR' => 'doctor_review',
    'LAB_PENDING' ||
    'SAMPLE_PENDING' ||
    'IN_LAB' ||
    'IMAGING_PENDING' ||
    'REPORT_PENDING' ||
    'PHARMACY_PENDING' => 'handoff',
    'RESULTS_READY' ||
    'REPORT_READY' ||
    'MEDICINES_DISPENSED' ||
    'DECISION_NEEDED' => 'disposition',
    'ADMISSION_PENDING' => 'admission_handoff',
    _ => switch (stage) {
      'WAITING_CONSULTATION_PAYMENT' =>
        canPayNow ? 'billing' : 'correct_stage',
      'WAITING_VITALS' => 'vitals',
      'WAITING_DOCTOR_ASSIGNMENT' =>
        hasAssignedProvider ? 'doctor_review' : 'assign_doctor',
      'WAITING_DOCTOR_REVIEW' => 'doctor_review',
      'WAITING_DISPOSITION' =>
        hasPendingAdmission ? 'admission_handoff' : 'disposition',
      'LAB_REQUESTED' ||
      'RADIOLOGY_REQUESTED' ||
      'LAB_AND_RADIOLOGY_REQUESTED' ||
      'PHARMACY_REQUESTED' => 'handoff',
      _ => 'correct_stage',
    },
  };
}

/// Whether the OPD encounter has a live inpatient admission attached.
bool opdFlowHasPendingAdmission(OpdFlowSummary? flow, OpdFlowDetail? detail) {
  final String displayCode = (flow?.displayCode ?? '').trim().toUpperCase();
  if (displayCode == 'ADMISSION_PENDING') {
    return true;
  }
  if ((flow?.stage ?? '').trim().toUpperCase() == 'ADMITTED') {
    return true;
  }
  final List<OpdRelatedRecord> admissions =
      detail?.admissions ?? const <OpdRelatedRecord>[];
  return admissions.any((OpdRelatedRecord record) {
    final String status = (record.status ?? '').trim().toUpperCase();
    return status != 'DISCHARGED' && status != 'CANCELLED';
  });
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}
