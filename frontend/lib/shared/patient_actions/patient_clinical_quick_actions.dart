import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/presentation/widgets/theater_schedule_case_form.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';

String patientApiId(Patient patient) {
  for (final String? value in <String?>[patient.publicId, patient.id]) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return patient.id;
}

Future<ClinicalReferenceData?> _loadClinicalReferenceData(WidgetRef ref) async {
  final Result<ClinicalReferenceData> result = await ref
      .read(clinicalRepositoryProvider)
      .loadReferenceData();
  return result.when(
    success: (ClinicalReferenceData value) => value,
    failure: (_) => null,
  );
}

Future<bool?> openPatientLabOrderDialog(
  BuildContext context,
  WidgetRef ref,
  Patient patient, {
  String? encounterId,
}) async {
  final ClinicalReferenceData? referenceData = await _loadClinicalReferenceData(
    ref,
  );
  if (referenceData == null || !context.mounted) {
    return null;
  }

  final LabOrderContextInput orderContext = LabOrderContextInput(
    patientId: patientApiId(patient),
    encounterId: encounterId ?? patient.currentVisit?.publicId,
  );

  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalLabOrderActionDialog(
      referenceData: referenceData,
      patientContext: ClinicalRequestPatientContext(
        patientName: patient.effectiveDisplayName,
        patientId: patientApiId(patient),
        encounterId: orderContext.encounterId,
      ),
      onSearchLabTests:
          ({
            required String termType,
            String? query,
            int? limit,
            String source = 'ALL',
          }) {
            return ref
                .read(clinicalRepositoryProvider)
                .searchClinicalTerms(
                  termType: termType,
                  query: query,
                  limit: limit ?? 80,
                  source: source,
                  facilityId:
                      patient.facilityId ??
                      ref.read(sessionStateProvider).session?.user?.facilityId,
                );
          },
      onRequest:
          ({
            required List<String> labTestIds,
            required List<String> labPanelIds,
            ClinicalRequestBillingSubmit? billing,
          }) async {
            final Result<void> result = await ref
                .read(labRepositoryProvider)
                .createOrder(
                  orderContext.toPayload(
                    labTestIds: labTestIds,
                    labPanelIds: labPanelIds,
                    billing: billing,
                  ),
                );
            return result.when(
              success: (_) => null,
              failure: (AppFailure failure) => failure,
            );
          },
      onUpdate:
          ({
            required String labOrderId,
            required List<String> labTestIds,
            required List<String> labPanelIds,
            ClinicalRequestBillingSubmit? billing,
          }) async {
            final Result<void> result = await ref
                .read(labRepositoryProvider)
                .updateOrder(
                  labOrderId,
                  orderContext.toPayload(
                    labTestIds: labTestIds,
                    labPanelIds: labPanelIds,
                    billing: billing,
                  ),
                );
            return result.when(
              success: (_) => null,
              failure: (AppFailure failure) => failure,
            );
          },
    ),
  );
}

Future<bool?> openPatientRadiologyOrderDialog(
  BuildContext context,
  WidgetRef ref,
  Patient patient, {
  String? encounterId,
}) async {
  final ClinicalReferenceData? referenceData = await _loadClinicalReferenceData(
    ref,
  );
  if (referenceData == null || !context.mounted) {
    return null;
  }

  final String resolvedPatientId = patientApiId(patient);
  final String? resolvedEncounterId =
      encounterId ?? patient.currentVisit?.publicId;

  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalRadiologyOrderActionDialog(
      referenceData: referenceData,
      patientContext: ClinicalRequestPatientContext(
        patientName: patient.effectiveDisplayName,
        patientId: patientApiId(patient),
        encounterId: resolvedEncounterId,
      ),
      onSearchRadiologyTests:
          ({
            required String termType,
            String? query,
            int? limit,
            String source = 'ALL',
          }) {
            return ref
                .read(clinicalRepositoryProvider)
                .searchClinicalTerms(
                  termType: termType,
                  query: query,
                  limit: limit ?? 80,
                  source: source,
                  facilityId:
                      patient.facilityId ??
                      ref.read(sessionStateProvider).session?.user?.facilityId,
                );
          },
      onSubmit:
          ({
            required List<ClinicalActionRadiologyRequest> requests,
            ClinicalRequestBillingSubmit? billing,
          }) async {
            final Result<dynamic> result = await ref
                .read(radiologyRepositoryProvider)
                .createOrder(<String, Object?>{
                  'patient_id': resolvedPatientId,
                  'encounter_id': resolvedEncounterId,
                  'ordered_at': DateTime.now().toUtc().toIso8601String(),
                  'requested_tests': <Map<String, Object?>>[
                    for (final ClinicalActionRadiologyRequest request
                        in requests)
                      <String, Object?>{
                        'radiology_test_id': request.radiologyTestId,
                        'clinical_note': request.clinicalNote,
                        'request_details':
                            mergeClinicalRequestBillingIntoRequestDetails(
                              <String, Object?>{
                                'modality': request.modality,
                                'body_region': request.bodyRegion,
                                'laterality': request.laterality,
                                'priority': request.priority,
                              },
                              billing,
                              lineAmount: clinicalRequestBillingLineAmount(
                                billing,
                                request.radiologyTestId,
                              ),
                            ),
                      },
                  ],
                });
            return result.when(
              success: (_) => null,
              failure: (AppFailure failure) => failure,
            );
          },
    ),
  );
}

Future<bool?> openPatientTheaterScheduleDialog(
  BuildContext context,
  WidgetRef ref,
  Patient patient, {
  String? encounterId,
}) async {
  final Map<String, Object?>? payload = await showTheaterScheduleCaseDialog(
    context: context,
    title: context.l10n.theaterScheduleCaseDialogTitle,
    icon: const Icon(Icons.medical_services_outlined),
    initialPatientId: patientApiId(patient),
    initialEncounterId: encounterId ?? patient.currentVisit?.publicId,
  );
  if (payload == null || !context.mounted) {
    return null;
  }

  final Result<dynamic> result = await ref
      .read(theaterRepositoryProvider)
      .scheduleCase(payload);
  if (!context.mounted) {
    return null;
  }
  return result.when(
    success: (_) => true,
    failure: (AppFailure failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.detailMessage ?? failure.messageKey)),
      );
      return null;
    },
  );
}

Future<bool?> openPatientPhysiotherapyRequestDialog(
  BuildContext context,
  WidgetRef ref,
  PatientDetail detail,
) async {
  final String? admissionId = _activeAdmissionId(detail);
  if (admissionId == null) {
    return null;
  }

  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalFreeTextActionDialog(
      title: context.l10n.patientsQuickPhysiotherapyAction,
      label: context.l10n.physiotherapyReasonFieldLabel,
      submitLabel: context.l10n.ipdRequestTherapyAction,
      icon: const Icon(Icons.self_improvement_outlined),
      onSubmit: (String indication) async {
        final Result<IpdAdmissionDetail> result = await ref
            .read(ipdRepositoryProvider)
            .requestTherapy(admissionId, <String, Object?>{
              'clinical_indication': indication.trim(),
            });
        return result.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
      },
    ),
  );
}

String? _activeAdmissionId(PatientDetail detail) {
  for (final PatientSummaryRecord admission in detail.workspace.admissions) {
    if (admission.id.trim().isNotEmpty &&
        _isActiveAdmissionStatus(admission.status)) {
      return admission.id.trim();
    }
  }

  final PatientVisitContext? visit = detail.patient.currentVisit;
  if (visit?.kind == 'admission' &&
      (visit?.publicId ?? '').trim().isNotEmpty &&
      _isActiveAdmissionStatus(visit?.status)) {
    return visit!.publicId!.trim();
  }
  return null;
}

bool _isActiveAdmissionStatus(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'ACTIVE' ||
    'ADMITTED' ||
    'ADMITTED_PENDING_BED' ||
    'ADMITTED_IN_BED' ||
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'DISCHARGE_PLANNED' => true,
    _ => false,
  };
}
