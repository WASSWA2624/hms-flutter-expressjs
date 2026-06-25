import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';

void main() {
  const String patientId = 'patient-uuid-1';

  // Route keys mirror the REST paths hit by loadPatientDetail.
  const String patientPath = '/api/v1/patients/$patientId';
  const String workspacePath = '/api/v1/patients/$patientId/workspace';
  const String timelinePath = '/api/v1/patients/$patientId/timeline';
  const String identifiersPath = '/api/v1/patient-identifiers';
  const String contactsPath = '/api/v1/patient-contacts';
  const String guardiansPath = '/api/v1/patient-guardians';
  const String allergiesPath = '/api/v1/patient-allergies';
  const String historiesPath = '/api/v1/patient-medical-histories';
  const String documentsPath = '/api/v1/patient-documents';
  const String consentsPath = '/api/v1/consents';

  Map<String, Object?> dataList(List<Object?> items) => <String, Object?>{
    'data': items,
    'pagination': <String, Object?>{'total': items.length},
  };

  Map<String, Object?> buildResponses() => <String, Object?>{
    patientPath: <String, Object?>{
      'data': <String, Object?>{
        'id': patientId,
        'human_friendly_id': 'PAT-1001',
        'first_name': 'Amina',
        'last_name': 'Kato',
        'gender': 'FEMALE',
        'is_active': true,
        'tenant_id': 'tenant-1',
        'facility_id': 'facility-1',
      },
    },
    workspacePath: <String, Object?>{
      'data': <String, Object?>{
        'snapshot': <String, Object?>{
          'appointments': <Object?>[
            <String, Object?>{
              'human_friendly_id': 'APT-1',
              'status': 'SCHEDULED',
              'scheduled_start': '2026-06-01T09:00:00.000Z',
            },
          ],
          'summary_counts': <String, Object?>{'appointments': 1},
        },
      },
    },
    timelinePath: dataList(<Object?>[
      <String, Object?>{
        'id': 'patient_registered:PAT-1001',
        'resource': 'patient_registered',
        'occurred_at': '2026-05-01T08:00:00.000Z',
        'summary': <String, Object?>{'display_name': 'Amina Kato'},
      },
      <String, Object?>{
        'id': 'appointment:APT-1',
        'resource': 'appointment',
        'occurred_at': '2026-06-01T09:00:00.000Z',
        'summary': <String, Object?>{'status': 'SCHEDULED'},
      },
    ]),
    identifiersPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'identifier-1',
        'human_friendly_id': 'PID-1',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'identifier_type': 'MRN',
        'identifier_value': 'MRN-10024',
        'is_primary': true,
      },
    ]),
    contactsPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'contact-phone',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'contact_type': 'PHONE',
        'value': '+256700000000',
        'is_primary': true,
      },
      <String, Object?>{
        'id': 'contact-email',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'contact_type': 'EMAIL',
        'value': 'amina@example.com',
        'is_primary': true,
      },
    ]),
    guardiansPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'guardian-1',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'name': 'John Kato',
        'relationship': 'PARENT',
      },
    ]),
    allergiesPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'allergy-1',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'allergen': 'Penicillin',
        'severity': 'SEVERE',
      },
    ]),
    historiesPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'history-1',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'condition': 'Hypertension',
      },
    ]),
    documentsPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'document-1',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'document_type': 'IDENTITY',
        'storage_key': 'patients/tenant-1/patient/doc.pdf',
        'file_name': 'id.pdf',
      },
    ]),
    consentsPath: dataList(<Object?>[
      <String, Object?>{
        'id': 'consent-1',
        'tenant_id': 'tenant-1',
        'patient_id': patientId,
        'consent_type': 'TREATMENT',
        'status': 'GRANTED',
      },
    ]),
  };

  test(
    'loadPatientDetail composes patient, workspace, and related lists',
    () async {
      final _FakeApiClient apiClient = _FakeApiClient(
        responses: buildResponses(),
      );
      final PatientRepositoryImpl repository = PatientRepositoryImpl(
        apiClient: apiClient,
      );

      final Result<PatientDetail> result = await repository.loadPatientDetail(
        patientId,
      );

      final PatientDetail? detail = result.when(
        success: (PatientDetail value) => value,
        failure: (_) => null,
      );

      expect(detail, isNotNull);
      expect(detail!.patient.id, patientId);
      expect(detail.patient.publicId, 'PAT-1001');
      // Demographics are hydrated from the related contact/identifier lists.
      expect(detail.patient.primaryPhone, '+256700000000');
      expect(detail.patient.primaryEmail, 'amina@example.com');
      expect(detail.patient.primaryIdentifierType, 'MRN');
      expect(detail.patient.primaryIdentifierValue, 'MRN-10024');

      expect(detail.identifiers, hasLength(1));
      expect(detail.contacts, hasLength(2));
      expect(detail.guardians, hasLength(1));
      expect(detail.allergies, hasLength(1));
      expect(detail.medicalHistories, hasLength(1));
      expect(detail.documents, hasLength(1));
      expect(detail.consents, hasLength(1));
      expect(detail.timeline, hasLength(2));
      expect(detail.workspace.appointments, hasLength(1));
      expect(detail.workspace.summaryCounts['appointments'], 1);

      // All dependent reads must have been issued (fan-out, not skipped).
      expect(
        apiClient.requestedPaths,
        containsAll(<String>[
          patientPath,
          workspacePath,
          timelinePath,
          identifiersPath,
          contactsPath,
          guardiansPath,
          allergiesPath,
          historiesPath,
          documentsPath,
          consentsPath,
        ]),
      );
    },
  );

  test('loadPatientDetail propagates a failing dependent request', () async {
    final _FakeApiClient apiClient = _FakeApiClient(
      responses: buildResponses(),
      failPaths: <String>{allergiesPath},
    );
    final PatientRepositoryImpl repository = PatientRepositoryImpl(
      apiClient: apiClient,
    );

    final Result<PatientDetail> result = await repository.loadPatientDetail(
      patientId,
    );

    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );

    expect(failure, isNotNull);
    expect(failure!.category, AppFailureCategory.notFound);
  });

  test(
    'loadPatientDetail short-circuits when the patient lookup fails',
    () async {
      final _FakeApiClient apiClient = _FakeApiClient(
        responses: buildResponses(),
        failPaths: <String>{patientPath},
      );
      final PatientRepositoryImpl repository = PatientRepositoryImpl(
        apiClient: apiClient,
      );

      final Result<PatientDetail> result = await repository.loadPatientDetail(
        patientId,
      );

      expect(result.when(success: (_) => false, failure: (_) => true), isTrue);
      // Dependent reads are not issued when the patient lookup fails.
      expect(apiClient.requestedPaths, <String>[patientPath]);
    },
  );
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient({required this.responses, this.failPaths = const <String>{}});

  final Map<String, Object?> responses;
  final Set<String> failPaths;
  final List<String> requestedPaths = <String>[];

  @override
  Uri get baseUri => Uri.parse('https://test.local');

  @override
  Future<ApiResult<T>> get<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final String key = endpoint.path;
    requestedPaths.add(key);
    if (failPaths.contains(key)) {
      return Result<T>.failure(const AppFailure.notFound());
    }
    return Result<T>.success(decoder(responses[key]));
  }

  @override
  Future<ApiResult<T>> post<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => throw UnimplementedError();

  @override
  Future<ApiResult<T>> put<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => throw UnimplementedError();

  @override
  Future<ApiResult<T>> patch<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => throw UnimplementedError();

  @override
  Future<ApiResult<T>> delete<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => throw UnimplementedError();

  @override
  Future<ApiResult<T>> request<T>({
    required String method,
    required Uri endpoint,
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => throw UnimplementedError();
}
