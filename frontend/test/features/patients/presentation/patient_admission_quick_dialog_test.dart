import 'package:flutter/material.dart';
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
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_admission_quick_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_harness.dart';

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

  Future<void> pumpDialog(
    WidgetTester tester, {
    required _MockPatientRepository patients,
    required _MockIpdRepository ipd,
    PatientReferenceData referenceData = const PatientReferenceData(
      facilities: <PatientReferenceOption>[
        PatientReferenceOption(id: 'facility-1', label: 'Main hospital'),
      ],
    ),
  }) async {
    when(() => patients.loadOverview()).thenAnswer(
      (_) async => const Result<PatientRegistryOverview>.success(
        PatientRegistryOverview(totalPatients: 1, activePatients: 1),
      ),
    );
    when(() => patients.loadReferenceData()).thenAnswer(
      (_) async => Result<PatientReferenceData>.success(referenceData),
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
      (_) async => const Result<PatientDetail>.success(
        PatientDetail(patient: patient, workspace: PatientWorkspaceSnapshot()),
      ),
    );

    setTestViewport(tester, const Size(1100, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(
              session: AuthSession(
                tokens: SessionTokens(accessToken: 'test-access-token'),
                subject: 'doctor@example.com',
                user: const AuthUserProfile(
                  id: 'user-1',
                  email: 'doctor@example.com',
                  roles: <String>['SUPER_ADMIN'],
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
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return AppButton.primary(
                  label: 'Open admission',
                  onPressed: () {
                    showPatientAdmissionQuickDialog(
                      context,
                      patient: patient,
                      referenceData: referenceData,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open admission'));
    await tester.pumpAndSettle();
  }

  testWidgets('reuses ClinicalAdmissionActionDialog with Close and bed icon', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    await pumpDialog(tester, patients: patients, ipd: ipd);

    expect(find.byType(PatientAdmissionQuickDialog), findsOneWidget);
    expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
    expect(find.text('Request admission'), findsWidgets);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byIcon(AppActionIcons.bed), findsWidgets);
    expect(find.byIcon(Icons.fullscreen_exit), findsWidgets);
    expect(find.textContaining('Amina'), findsNothing);
  });

  testWidgets('submit success closes dialog after controller mutation', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    when(() => ipd.requestAdmission(any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'admission-1',
            displayId: 'ADM-1001',
            stage: 'ADMISSION_REQUESTED',
            admissionStatus: 'REQUESTED',
          ),
        ),
      ),
    );

    await pumpDialog(tester, patients: patients, ipd: ipd);

    await tester.enterText(find.byType(TextFormField).first, 'Needs bed');
    await tester.tap(find.text('Request admission').last);
    await tester.pumpAndSettle();

    expect(find.byType(PatientAdmissionQuickDialog), findsNothing);
    final List<Object?> captured = verify(
      () => ipd.requestAdmission(captureAny()),
    ).captured;
    final Map<String, Object?> payload = captured.single as Map<String, Object?>;
    expect(payload['patient_id'], 'PAT-1001');
    expect(payload['reason'], 'Needs bed');
  });

  testWidgets('submit failure keeps dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patients = _MockPatientRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    when(() => ipd.requestAdmission(any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.failure(AppFailure.validation()),
    );

    await pumpDialog(tester, patients: patients, ipd: ipd);

    await tester.enterText(find.byType(TextFormField).first, 'Needs bed');
    await tester.tap(find.text('Request admission').last);
    await tester.pumpAndSettle();

    expect(find.byType(PatientAdmissionQuickDialog), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
