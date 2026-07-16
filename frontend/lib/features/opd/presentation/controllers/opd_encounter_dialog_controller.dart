import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final opdEncounterDialogControllerProvider =
    Provider<OpdEncounterDialogController>((Ref ref) {
      return OpdEncounterDialogController(
        ref: ref,
        opdRepository: ref.watch(opdRepositoryProvider),
        patientRepository: ref.watch(patientRepositoryProvider),
        insuranceCatalogRepository: ref.watch(
          insuranceCatalogRepositoryProvider,
        ),
      );
    });

/// Owns data access for the shared OPD encounter dialog.
///
/// Keeping repository calls here leaves the dialog responsible only for form
/// state and delegates persistence/synchronization to presentation controllers.
final class OpdEncounterDialogController {
  const OpdEncounterDialogController({
    required Ref ref,
    required OpdRepository opdRepository,
    required PatientRepository patientRepository,
    required InsuranceCatalogRepository insuranceCatalogRepository,
  }) : _ref = ref,
       _opdRepository = opdRepository,
       _patientRepository = patientRepository,
       _insuranceCatalogRepository = insuranceCatalogRepository;

  final Ref _ref;
  final OpdRepository _opdRepository;
  final PatientRepository _patientRepository;
  final InsuranceCatalogRepository _insuranceCatalogRepository;

  Future<Result<AppPage<Patient>>> listPatients(PatientListQuery query) {
    return _patientRepository.listPatients(query);
  }

  Future<Result<PatientReferenceData>> loadPatientReferenceData() {
    return _patientRepository.loadReferenceData();
  }

  Future<Result<AppPage<PatientDuplicateCandidate>>> listDuplicateCandidates(
    PatientDuplicateQuery query,
  ) {
    return _patientRepository.listDuplicateCandidates(query);
  }

  Future<Result<Patient>> createPatient(Map<String, Object?> payload) {
    if (_ref.exists(patientRegistryControllerProvider)) {
      return _ref
          .read(patientRegistryControllerProvider.notifier)
          .createPatient(payload);
    }
    return _patientRepository.createPatient(payload);
  }

  Future<Result<AppPage<OpdAppointment>>> listAppointments(
    OpdAppointmentQuery query,
  ) {
    return _opdRepository.listAppointments(query);
  }

  Future<Result<AppPage<OpdFlowSummary>>> listOpdFlows(OpdFlowQuery query) {
    return _opdRepository.listOpdFlows(query);
  }

  Future<Result<List<OpdProviderOption>>> listProviders() {
    return _opdRepository.listProviders();
  }

  Future<Result<List<OpdProviderSchedule>>> listProviderSchedules() {
    return _opdRepository.listProviderSchedules();
  }

  Future<Result<OpdBillingDefaults>> getBillingDefaults({
    String? facilityId,
    String? tenantId,
  }) {
    return _opdRepository.getBillingDefaults(
      facilityId: facilityId,
      tenantId: tenantId,
    );
  }

  Future<ClinicalRequestPayerContext?> resolvePayerContextForPatient(
    String patientId,
  ) {
    return _insuranceCatalogRepository.resolvePayerContextForPatient(patientId);
  }

  Future<Result<OpdFlowDetail>> submitPatientEncounter(
    Patient patient,
    Map<String, Object?> payload,
  ) async {
    final bool forceNewEncounter = payload['force_new_encounter'] == true;
    final Object? existingEncounterId = payload['existing_encounter_id'];
    final Result<OpdFlowDetail> result;
    if (!forceNewEncounter &&
        existingEncounterId is String &&
        existingEncounterId.trim().isNotEmpty) {
      result = await _opdRepository.updateActiveEncounter(
        existingEncounterId.trim(),
        _withoutEmpty(
          <String, Object?>{
            'tenant_id': patient.tenantId,
            'facility_id': patient.facilityId,
            ...payload,
          }..remove('existing_encounter_id'),
        ),
      );
    } else {
      result = await _opdRepository.startOpdFlow(
        _withoutEmpty(<String, Object?>{
          'tenant_id': patient.tenantId,
          'facility_id': patient.facilityId,
          ...payload,
        }),
      );
    }
    return _patchWorkspaceOnSuccess(result);
  }

  Future<Result<OpdFlowDetail>> cancelEncounter(
    String flowId,
    Map<String, Object?> payload,
  ) async {
    return _patchWorkspaceOnSuccess(
      await _opdRepository.cancelEncounter(flowId, payload),
    );
  }

  Future<Result<OpdFlowDetail>> closeEncounter(
    String flowId,
    Map<String, Object?> payload,
  ) async {
    return _patchWorkspaceOnSuccess(
      await _opdRepository.closeEncounter(flowId, payload),
    );
  }

  Result<OpdFlowDetail> _patchWorkspaceOnSuccess(Result<OpdFlowDetail> result) {
    result.when(
      success: (OpdFlowDetail detail) {
        if (_ref.exists(opdWorkspaceControllerProvider)) {
          _ref
              .read(opdWorkspaceControllerProvider.notifier)
              .applyFlowDetailPatchIfLoaded(detail);
        }
      },
      failure: (_) {},
    );
    return result;
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_valueIsEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _valueIsEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.isEmpty;
    }
    if (value is Map<Object?, Object?>) {
      return value.isEmpty;
    }
    return false;
  }
}
