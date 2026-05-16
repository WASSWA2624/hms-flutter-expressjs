import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/patients/data/dtos/patient_dtos.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<Patient>>> listPatients(PatientListQuery query) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<Patient>>(
      ApiEndpoints.collection(HmsApiResource.patients),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'patient_id': query.patientId,
        'contact': query.contact,
        'facility_id': query.facilityId,
        'gender': query.gender,
        'is_active': query.isActive,
        'consent_state': query.consentState,
        'appointment_status': query.appointmentStatus,
        'visit_date': _dateOnly(query.visitDate),
        'visit_from': _dateOnly(query.visitFrom),
        'visit_to': _dateOnly(query.visitTo),
        'created_from': _dateOnly(query.createdFrom),
        'created_to': _dateOnly(query.createdTo),
        'date_of_birth_from': _dateOnly(query.dateOfBirthFrom),
        'date_of_birth_to': _dateOnly(query.dateOfBirthTo),
        'has_active_admission': query.hasActiveAdmission,
        'has_outstanding_balance': query.hasOutstandingBalance,
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          PatientPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<PatientRegistryOverview>> loadOverview() {
    return _apiClient.get<PatientRegistryOverview>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.patients.path,
        'workspace',
        'overview',
      ]),
      decoder: (Object? data) =>
          PatientRegistryOverviewDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PatientReferenceData>> loadReferenceData() {
    return _apiClient.get<PatientReferenceData>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.patients.path,
        'workspace',
        'reference-data',
      ]),
      decoder: (Object? data) =>
          PatientReferenceDataDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<PatientDuplicateCandidate>>> listDuplicateCandidates(
    PatientDuplicateQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<PatientDuplicateCandidate>>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.patients.path, 'duplicates']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'patient_id': query.patientId,
        'first_name': query.firstName,
        'last_name': query.lastName,
        'date_of_birth': _dateOnly(query.dateOfBirth),
        'phone': query.phone,
        'identifier_value': query.identifierValue,
      }),
      decoder: (Object? data) =>
          PatientDuplicatePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<PatientDetail>> loadPatientDetail(String patientId) async {
    final Patient? patient = await _resultValue(
      _apiClient.get<Patient>(
        ApiEndpoints.byId(HmsApiResource.patients, patientId),
        decoder: (Object? data) => PatientDto(decodeDataMap(data)).toEntity(),
      ),
    );
    if (patient == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final PatientWorkspaceSnapshot? workspace = await _resultValue(
      _apiClient.get<PatientWorkspaceSnapshot>(
        ApiEndpoints.apiV1(<String>[
          HmsApiResource.patients.path,
          patient.id,
          'workspace',
        ]),
        decoder: (Object? data) =>
            PatientWorkspaceDto(decodeDataMap(data)).toSnapshot(),
      ),
    );
    if (workspace == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientTimelineItem>? timeline = await _resultValue(
      _apiClient.get<List<PatientTimelineItem>>(
        ApiEndpoints.apiV1(<String>[
          HmsApiResource.patients.path,
          patient.id,
          'timeline',
        ]),
        queryParameters: const <String, Object?>{'page': 1, 'limit': 12},
        decoder: (Object? data) => decodeDataList(data)
            .map(PatientTimelineItemDto.new)
            .map((PatientTimelineItemDto dto) => dto.toEntity())
            .toList(growable: false),
      ),
    );
    if (timeline == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientIdentifier>? identifiers = await _resultValue(
      _fetchRelatedList<PatientIdentifier>(
        HmsApiResource.patientIdentifiers,
        patient.id,
        decodeIdentifierList,
      ),
    );
    if (identifiers == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientContact>? contacts = await _resultValue(
      _fetchRelatedList<PatientContact>(
        HmsApiResource.patientContacts,
        patient.id,
        decodeContactList,
      ),
    );
    if (contacts == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientGuardian>? guardians = await _resultValue(
      _fetchRelatedList<PatientGuardian>(
        HmsApiResource.patientGuardians,
        patient.id,
        decodeGuardianList,
      ),
    );
    if (guardians == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientAllergy>? allergies = await _resultValue(
      _fetchRelatedList<PatientAllergy>(
        HmsApiResource.patientAllergies,
        patient.id,
        decodeAllergyList,
      ),
    );
    if (allergies == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientMedicalHistory>? medicalHistories = await _resultValue(
      _fetchRelatedList<PatientMedicalHistory>(
        HmsApiResource.patientMedicalHistories,
        patient.id,
        decodeMedicalHistoryList,
      ),
    );
    if (medicalHistories == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientDocument>? documents = await _resultValue(
      _fetchRelatedList<PatientDocument>(
        HmsApiResource.patientDocuments,
        patient.id,
        decodeDocumentList,
      ),
    );
    if (documents == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    final List<PatientConsent>? consents = await _resultValue(
      _fetchRelatedList<PatientConsent>(
        HmsApiResource.consents,
        patient.id,
        decodeConsentList,
      ),
    );
    if (consents == null) {
      return Result<PatientDetail>.failure(_lastFailure!);
    }

    return Result<PatientDetail>.success(
      PatientDetail(
        patient: _hydratePatient(patient, identifiers, contacts),
        workspace: workspace,
        identifiers: identifiers,
        contacts: contacts,
        guardians: guardians,
        allergies: allergies,
        medicalHistories: medicalHistories,
        documents: documents,
        consents: consents,
        timeline: timeline,
      ),
    );
  }

  @override
  Future<Result<PatientMergePreview>> previewPatientMerge({
    required String primaryPatientId,
    required String secondaryPatientId,
  }) {
    return _apiClient.post<PatientMergePreview>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.patients.path,
        'merge',
        'preview',
      ]),
      data: <String, Object?>{
        'primary_patient_id': primaryPatientId,
        'secondary_patient_id': secondaryPatientId,
      },
      decoder: (Object? data) =>
          PatientMergePreviewDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<PatientMutationResult>> mergePatients({
    required String primaryPatientId,
    required String secondaryPatientId,
  }) {
    return _apiClient.post<PatientMutationResult>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.patients.path, 'merge']),
      data: <String, Object?>{
        'primary_patient_id': primaryPatientId,
        'secondary_patient_id': secondaryPatientId,
      },
      decoder: (_) => PatientMutationResult(patientId: primaryPatientId),
    );
  }

  @override
  Future<Result<PatientMutationResult>> dismissDuplicateCandidate({
    required String reviewId,
    required String primaryPatientId,
    required String secondaryPatientId,
    String? reason,
  }) {
    return _apiClient.post<PatientMutationResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.patients.path,
        'duplicates',
        reviewId,
        'dismiss',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'primary_patient_id': primaryPatientId,
        'secondary_patient_id': secondaryPatientId,
        'dismissed_reason': reason,
      }),
      decoder: (_) => PatientMutationResult(patientId: primaryPatientId),
    );
  }

  @override
  Future<Result<Patient>> createPatient(Map<String, Object?> payload) {
    return _apiClient.post<Patient>(
      ApiEndpoints.collection(HmsApiResource.patients),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => PatientDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<Patient>> updatePatient(
    String patientId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<Patient>(
      ApiEndpoints.byId(HmsApiResource.patients, patientId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => PatientDto(decodeDataMap(data)).toEntity(),
    );
  }

  @override
  Future<Result<PatientMutationResult>> deletePatient(String patientId) {
    return _apiClient.delete<PatientMutationResult>(
      ApiEndpoints.byId(HmsApiResource.patients, patientId),
      decoder: (_) => PatientMutationResult(patientId: patientId),
    );
  }

  @override
  Future<Result<void>> createRelatedRecord(
    PatientRelatedResource resource,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(_resourceEndpoint(resource)),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<List<PatientDocument>>> uploadPatientDocuments({
    required String patientId,
    required String documentType,
    required List<PatientDocumentUploadFile> files,
  }) {
    final FormData formData = FormData();
    formData.fields.add(
      MapEntry<String, String>('document_type', documentType),
    );
    for (final PatientDocumentUploadFile file in files) {
      formData.files.add(
        MapEntry<String, MultipartFile>(
          'files',
          MultipartFile.fromBytes(
            file.bytes,
            filename: file.name,
            contentType: file.contentType == null
                ? null
                : DioMediaType.parse(file.contentType!),
          ),
        ),
      );
    }

    return _apiClient.post<List<PatientDocument>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.patients.path,
        patientId,
        'documents',
        'upload',
      ]),
      data: formData,
      decoder: decodeDocumentUploadList,
    );
  }

  @override
  Future<Result<void>> updateRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(_resourceEndpoint(resource), recordId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> deleteRelatedRecord(
    PatientRelatedResource resource,
    String recordId,
  ) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(_resourceEndpoint(resource), recordId),
      decoder: (_) {},
    );
  }

  Future<Result<List<T>>> _fetchRelatedList<T>(
    HmsApiResource resource,
    String patientId,
    List<T> Function(Object? data) decoder,
  ) {
    return _apiClient.get<List<T>>(
      ApiEndpoints.collection(resource),
      queryParameters: <String, Object?>{
        'patient_id': patientId,
        'page': 1,
        'limit': 100,
        'sort_by': 'updated_at',
        'order': 'desc',
      },
      decoder: decoder,
    );
  }

  Patient _hydratePatient(
    Patient patient,
    List<PatientIdentifier> identifiers,
    List<PatientContact> contacts,
  ) {
    final PatientIdentifier? primaryIdentifier = identifiers
        .where((PatientIdentifier identifier) => identifier.isPrimary)
        .firstOrNull;
    final PatientIdentifier? fallbackIdentifier = identifiers.firstOrNull;
    final PatientContact? primaryPhone = contacts
        .where(
          (PatientContact contact) =>
              contact.type.toUpperCase() == 'PHONE' && contact.isPrimary,
        )
        .firstOrNull;
    final PatientContact? fallbackPhone = contacts
        .where(
          (PatientContact contact) => contact.type.toUpperCase() == 'PHONE',
        )
        .firstOrNull;
    final PatientContact? primaryEmail = contacts
        .where(
          (PatientContact contact) =>
              contact.type.toUpperCase() == 'EMAIL' && contact.isPrimary,
        )
        .firstOrNull;
    final PatientContact? fallbackEmail = contacts
        .where(
          (PatientContact contact) => contact.type.toUpperCase() == 'EMAIL',
        )
        .firstOrNull;

    return patient.copyWith(
      primaryPhone: primaryPhone?.value ?? fallbackPhone?.value,
      primaryEmail: primaryEmail?.value ?? fallbackEmail?.value,
      primaryIdentifierType:
          primaryIdentifier?.type ?? fallbackIdentifier?.type,
      primaryIdentifierValue:
          primaryIdentifier?.value ?? fallbackIdentifier?.value,
    );
  }

  HmsApiResource _resourceEndpoint(PatientRelatedResource resource) {
    return switch (resource) {
      PatientRelatedResource.identifier => HmsApiResource.patientIdentifiers,
      PatientRelatedResource.contact => HmsApiResource.patientContacts,
      PatientRelatedResource.guardian => HmsApiResource.patientGuardians,
      PatientRelatedResource.allergy => HmsApiResource.patientAllergies,
      PatientRelatedResource.medicalHistory =>
        HmsApiResource.patientMedicalHistories,
      PatientRelatedResource.document => HmsApiResource.patientDocuments,
      PatientRelatedResource.consent => HmsApiResource.consents,
    };
  }

  AppFailure? _lastFailure;

  Future<T?> _resultValue<T>(Future<Result<T>> future) async {
    final Result<T> result = await future;
    return result.when(
      success: (T value) {
        _lastFailure = null;
        return value;
      },
      failure: (AppFailure failure) {
        _lastFailure = failure;
        return null;
      },
    );
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    return false;
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) {
      return null;
    }

    return value.toIso8601String().split('T').first;
  }
}
