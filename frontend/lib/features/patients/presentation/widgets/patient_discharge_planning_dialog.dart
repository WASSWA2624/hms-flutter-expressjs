import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';

/// Patient registry quick action — opens system-validated discharge planning.
Future<bool?> openPatientDischargePlanningDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PatientDetail detail,
  required String actionLabel,
  void Function(AppFailure failure)? onFailure,
}) {
  final String? admissionId = _resolveAdmissionId(detail);
  if (admissionId == null || admissionId.isEmpty) {
    return Future<bool?>.value();
  }

  return showDischargePlanningDialog(
    context: context,
    ref: ref,
    admissionId: admissionId,
    title: Text(actionLabel),
    onFailure: onFailure,
  );
}

String? _resolveAdmissionId(PatientDetail detail) {
  final PatientSummaryRecord? admission = activePatientAdmissionRecord(
    detail.workspace.admissions,
  );
  if (admission != null && admission.id.trim().isNotEmpty) {
    return admission.id.trim();
  }

  final PatientVisitContext? visit = detail.patient.currentVisit;
  if (isActiveAdmissionPatientVisit(visit)) {
    return visit!.publicId?.trim();
  }
  return null;
}
