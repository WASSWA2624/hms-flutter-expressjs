import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/preferences/app_preferences_store.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/patients/presentation/controllers/patient_registry_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

final class _TestSecureSessionStorage implements SecureSessionStorage {
  @override
  Future<SessionTokens?> readTokens() async =>
      SessionTokens(accessToken: 'test-access-token');

  @override
  Future<void> writeTokens(SessionTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

final class _TestAppPreferencesStore implements AppPreferencesStore {
  final Map<String, Object> _data = <String, Object>{};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
    registerFallbackValue(<String, Object?>{});
  });

  const Patient patient = Patient(
    id: 'patient-1',
    publicId: 'PAT-1001',
    tenantId: 'tenant-1',
    facilityId: 'facility-1',
    firstName: 'Amina',
    lastName: 'Kato',
  );

  const PatientDetail detail = PatientDetail(
    patient: patient,
    workspace: PatientWorkspaceSnapshot(),
  );

  ProviderContainer buildContainer({
    required _MockPatientRepository patients,
    required _MockIpdRepository ipd,
  }) {
    when(() => patients.loadOverview()).thenAnswer(
      (_) async => const Result<PatientRegistryOverview>.success(
        PatientRegistryOverview(totalPatients: 1, activePatients: 1),
      ),
    );
    when(() => patients.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<PatientReferenceData>.success(PatientReferenceData()),
    );
    when(() => patients.listPatients(any())).thenAnswer(
      (_) async => const Result<AppPage<Patient>>.success(
        AppPage<Patient>(
          items: <Patient>[patient],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    when(() => patients.loadPatientDetail(patient.id)).thenAnswer(
      (_) async => const Result<PatientDetail>.success(detail),
    );

    return ProviderContainer(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(
            session: AuthSession(
              tokens: SessionTokens(accessToken: 'test-access-token'),
              subject: 'doctor@example.com',
              user: const AuthUserProfile(
                id: 'user-1',
                email: 'doctor@example.com',
                roles: <String>['PLATFORM_ADMIN'],
              ),
            ),
          ),
        ),
        secureSessionStorageProvider.overrideWithValue(
          _TestSecureSessionStorage(),
        ),
        appPreferencesStoreProvider.overrideWithValue(
          _TestAppPreferencesStore(),
        ),
        patientRepositoryProvider.overrideWithValue(patients),
        ipdRepositoryProvider.overrideWithValue(ipd),
      ],
    );
  }

  test('requestAdmission posts payload and reconciles patient detail', () async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      patients: patients,
      ipd: ipd,
    );
    addTearDown(container.dispose);

    when(() => ipd.requestAdmission(any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'admission-1',
            displayId: 'ADM-1001',
            stage: 'ADMISSION_REQUESTED',
            admissionStatus: 'REQUESTED',
            wardDisplayName: 'Medical ward',
          ),
        ),
      ),
    );

    await container.read(patientRegistryControllerProvider.future);
    final PatientRegistryController controller = container.read(
      patientRegistryControllerProvider.notifier,
    );
    await controller.selectPatient(patient.id);

    final AppFailure? failure = await controller.requestAdmission(
      patientId: patient.id,
      apiPatientId: patient.publicId,
      tenantId: patient.tenantId,
      facilityId: patient.facilityId,
      reason: 'Needs monitoring',
      notes: 'From registry',
    );
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => ipd.requestAdmission(captureAny()),
    ).captured;
    final Map<String, Object?> payload = captured.single as Map<String, Object?>;
    expect(payload['patient_id'], 'PAT-1001');
    expect(payload['tenant_id'], 'tenant-1');
    expect(payload['facility_id'], 'facility-1');
    expect(payload['reason'], 'Needs monitoring');
    expect(payload['notes'], 'From registry');

    final Result<PatientRegistryState>? state = container
        .read(patientRegistryControllerProvider)
        .asData
        ?.value;
    final PatientRegistryState? registry = state?.when(
      success: (PatientRegistryState value) => value,
      failure: (_) => null,
    );
    expect(registry, isNotNull);
    expect(registry!.isSaving, isFalse);
    expect(registry.selectedDetail, isNotNull);
    verify(() => patients.loadPatientDetail(patient.id)).called(greaterThan(1));
  });

  test('requestAdmission failure does not patch admission cues', () async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      patients: patients,
      ipd: ipd,
    );
    addTearDown(container.dispose);

    when(() => ipd.requestAdmission(any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.failure(AppFailure.validation()),
    );

    await container.read(patientRegistryControllerProvider.future);
    final PatientRegistryController controller = container.read(
      patientRegistryControllerProvider.notifier,
    );
    await controller.selectPatient(patient.id);
    clearInteractions(patients);

    final AppFailure? failure = await controller.requestAdmission(
      patientId: patient.id,
      apiPatientId: patient.publicId,
      reason: 'Needs monitoring',
    );
    expect(failure, isNotNull);
    verifyNever(() => patients.loadPatientDetail(any()));

    final Result<PatientRegistryState>? state = container
        .read(patientRegistryControllerProvider)
        .asData
        ?.value;
    final PatientRegistryState? registry = state?.when(
      success: (PatientRegistryState value) => value,
      failure: (_) => null,
    );
    expect(registry, isNotNull);
    expect(registry!.isSaving, isFalse);
    expect(registry.selectedDetail?.workspace.admissions, isEmpty);
    expect(registry.selectedDetail?.patient.currentVisit, isNull);
  });
}
