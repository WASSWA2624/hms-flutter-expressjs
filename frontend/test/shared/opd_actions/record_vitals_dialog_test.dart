import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_record_vitals_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/record_vitals_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockApiClient extends Mock implements ApiClient {}

const OpdFlowSummary _flow = OpdFlowSummary(
  id: 'encounter-1',
  publicId: 'ENC000001',
  patientDisplayName: 'Patient Example',
  stage: 'WAITING_VITALS',
  chiefComplaint: 'Headache',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  test('buildAppVitalPayloads normalizes blood pressure to mmHg', () {
    final List<Map<String, Object?>> payloads = buildAppVitalPayloads(
      temperature: '',
      systolic: '16',
      diastolic: '10.7',
      heartRate: '',
      respiratoryRate: '',
      oxygenSaturation: '',
      weight: '',
      height: '',
      bloodPressureUnit: AppVitalsUnits.bloodPressureKpa,
      temperatureUnit: AppVitalsUnits.temperatureCelsius,
      weightUnit: AppVitalsUnits.weightKilograms,
      heightUnit: AppVitalsUnits.heightCentimeters,
      recordedAt: DateTime.utc(2026, 7, 17, 9),
      normalizeBloodPressureToMmHg: true,
    );

    expect(payloads, hasLength(1));
    expect(payloads.single['vital_type'], 'BLOOD_PRESSURE');
    expect(payloads.single['unit'], AppVitalsUnits.bloodPressureMmHg);
    expect(payloads.single['value'], isA<String>());
    expect(payloads.single['systolic_value'], isNotNull);
    expect(payloads.single['diastolic_value'], isNotNull);
  });

  testWidgets('composes AppRecordVitalsDialog with role-based title chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(tester, flow: _flow, repository: repository);

    expect(find.byType(AppRecordVitalsDialog), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('RECORD VITALS'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Record vitals'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
    expect(find.byIcon(AppActionIcons.save), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Cancel pops false without recording vitals', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    bool? result;

    await _pumpDialog(
      tester,
      flow: _flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.recordVitals(any(), any()));
    verifyNever(() => repository.routeTriage(any(), any()));
  });

  testWidgets('records vitals through the workspace controller on success', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    Map<String, Object?>? submittedPayload;
    when(() => repository.recordVitals(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return const Result<OpdFlowDetail>.success(
        OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-1',
            publicId: 'ENC000001',
            stage: 'WAITING_DOCTOR_ASSIGNMENT',
          ),
        ),
      );
    });

    bool? result;
    await _pumpDialog(
      tester,
      flow: _flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await _enterHeartRate(tester, '72');
    await tester.tap(find.widgetWithText(AppButton, 'Record vitals'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(submittedPayload, isNotNull);
    expect(submittedPayload!['vitals'], isA<List<dynamic>>());
    final List<dynamic> vitals = submittedPayload!['vitals']! as List<dynamic>;
    expect(vitals, isNotEmpty);
    expect(
      vitals.any(
        (dynamic item) =>
            item is Map && item['vital_type'] == 'HEART_RATE',
      ),
      isTrue,
    );
  });

  testWidgets('keeps dialog open and patches nothing when record fails', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    when(() => repository.recordVitals(any(), any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );

    bool? result;
    await _pumpDialog(
      tester,
      flow: _flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await _enterHeartRate(tester, '72');
    await tester.tap(find.widgetWithText(AppButton, 'Record vitals'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(RecordVitalsDialog), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsWidgets);
    verifyNever(() => repository.routeTriage(any(), any()));
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(
      tester,
      flow: _flow,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('RECORD VITALS'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Record vitals'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
  });
}

Future<void> _enterHeartRate(WidgetTester tester, String value) async {
  final Finder field = find.bySemanticsLabel('Heart rate beats per minute');
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdFlowSummary flow,
  required OpdRepository repository,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(repository),
        patientRepositoryProvider.overrideWithValue(_MockPatientRepository()),
        clinicalRepositoryProvider.overrideWithValue(_MockClinicalRepository()),
        insuranceCatalogRepositoryProvider.overrideWithValue(
          InsuranceCatalogRepository(apiClient: _MockApiClient()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  final bool? value = await showRecordVitalsDialog(
                    context: context,
                    flow: flow,
                  );
                  onResult?.call(value);
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  await container.read(opdWorkspaceControllerProvider.future);

  await tester.tap(find.widgetWithText(AppButton, 'Open'));
  await tester.pumpAndSettle();
}

void _stubWorkspaceLoad(_MockOpdRepository repository) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: <OpdAppointment>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: <OpdQueueEntry>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[_flow],
        request: (invocation.positionalArguments.single as OpdFlowQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async =>
        const Result<OpdFlowAggregateCounts>.success(OpdFlowAggregateCounts()),
  );
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderSchedule>>.success(<OpdProviderSchedule>[]),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => repository.listProviders(search: any(named: 'search'))).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
}
