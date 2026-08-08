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

  const Patient existing = Patient(
    id: 'patient-1',
    publicId: 'PAT-1001',
    tenantId: 'tenant-1',
    facilityId: 'facility-1',
    firstName: 'Amina',
    lastName: 'Kato',
  );

  const Patient created = Patient(
    id: 'PAT-NEW-1',
    publicId: 'PAT-NEW-1',
    tenantId: 'tenant-1',
    facilityId: 'facility-1',
    firstName: 'Jane',
    lastName: 'Doe',
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
          items: <Patient>[existing],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
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

  test('createPatient patches registry list and overview on success only', (
  ) async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      patients: patients,
      ipd: ipd,
    );
    addTearDown(container.dispose);

    await container.read(patientRegistryControllerProvider.future);
    when(() => patients.createPatient(any())).thenAnswer(
      (_) async => const Result<Patient>.success(created),
    );
    when(() => patients.loadOverview()).thenAnswer(
      (_) async => const Result<PatientRegistryOverview>.success(
        PatientRegistryOverview(totalPatients: 2, activePatients: 2),
      ),
    );
    // Post-create reconciliation / flush may re-list; include the new row.
    when(() => patients.listPatients(any())).thenAnswer(
      (_) async => const Result<AppPage<Patient>>.success(
        AppPage<Patient>(
          items: <Patient>[created, existing],
          request: AppPageRequest(),
          totalItemCount: 2,
        ),
      ),
    );

    final PatientRegistryController controller = container.read(
      patientRegistryControllerProvider.notifier,
    );

    final Result<Patient> result = await controller.createPatient(
      <String, Object?>{
        'first_name': 'Jane',
        'last_name': 'Doe',
        'tenant_id': 'tenant-1',
        'facility_id': 'facility-1',
        'gender': 'FEMALE',
        'is_active': true,
      },
    );

    expect(result.isSuccess, isTrue);
    verify(() => patients.createPatient(any())).called(1);
    verify(() => patients.loadOverview()).called(greaterThan(1));

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
    expect(
      registry.page.items.map((Patient patient) => patient.id),
      contains('PAT-NEW-1'),
    );
    expect(registry.overview.totalPatients, 2);
    expect(registry.lastFailure, isNull);
  });

  test('createPatient failure patches nothing and keeps prior page', () async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      patients: patients,
      ipd: ipd,
    );
    addTearDown(container.dispose);

    when(() => patients.createPatient(any())).thenAnswer(
      (_) async => Result<Patient>.failure(AppFailure.validation()),
    );

    await container.read(patientRegistryControllerProvider.future);
    clearInteractions(patients);

    final PatientRegistryController controller = container.read(
      patientRegistryControllerProvider.notifier,
    );
    final Result<Patient> result = await controller.createPatient(
      <String, Object?>{'first_name': 'Jane'},
    );

    expect(result.isFailure, isTrue);
    verify(() => patients.createPatient(any())).called(1);
    verifyNever(() => patients.loadOverview());

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
    expect(registry.page.items, <Patient>[existing]);
    expect(registry.overview.totalPatients, 1);
    expect(registry.lastFailure, isNotNull);
  });
}
