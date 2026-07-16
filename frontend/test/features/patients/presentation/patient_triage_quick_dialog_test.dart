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
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockApiClient extends Mock implements ApiClient {}

const Patient _patient = Patient(
  id: 'patient-1',
  publicId: 'PAT-1001',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Amina',
  lastName: 'Kato',
  dateOfBirth: null,
  gender: 'FEMALE',
);

const OpdFlowDetail _flowDetail = OpdFlowDetail(
  summary: OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    tenantId: 'tenant-1',
    facilityId: 'facility-1',
    patientId: 'patient-1',
    encounterType: 'OPD',
    status: 'OPEN',
    stage: 'WAITING_VITALS',
    triageLevel: 'LEVEL_2',
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  testWidgets(
    'showPatientTriageQuickDialog uses AppTriageActionDialog chrome',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubProviders(repository);
      _stubWorkspaceBootstrap(repository);

      await _pumpOpenDialog(tester, repository: repository);

      expect(find.byType(AppTriageActionDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('TRIAGE INTAKE'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save triage'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.save), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byIcon(Icons.monitor_heart_outlined), findsWidgets);
      expect(find.text('AMINA KATO'), findsNothing);
      expect(find.text('Amina Kato'), findsNothing);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
    },
  );

  testWidgets('Cancel pops without starting an OPD encounter', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubProviders(repository);
    _stubWorkspaceBootstrap(repository);

    await _pumpOpenDialog(tester, repository: repository);

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    verifyNever(
      () => repository.startOpdFlow(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
    verifyNever(() => repository.recordVitals(any(), any()));
    verifyNever(
      () => repository.assignDoctor(
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  testWidgets(
    'encounter failure keeps the dialog open and preserves chief complaint',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubProviders(repository);
      _stubWorkspaceBootstrap(repository);
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
      );

      await _pumpOpenDialog(tester, repository: repository);
      await _fillRequiredTriageFields(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Save triage'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Save triage'), findsOneWidget);
      expect(find.text('Chest pain'), findsOneWidget);
      verify(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
      verifyNever(() => repository.recordVitals(any(), any()));
    },
  );

  testWidgets(
    'vitals failure after encounter start keeps dialog open and skips assign',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubProviders(repository);
      _stubWorkspaceBootstrap(repository);
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.success(_flowDetail),
      );
      when(() => repository.recordVitals(any(), any())).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
      );

      await _pumpOpenDialog(tester, repository: repository);
      await _fillRequiredTriageFields(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Save triage'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Chest pain'), findsOneWidget);
      verify(() => repository.recordVitals('ENC000001', any())).called(1);
      verifyNever(
        () => repository.assignDoctor(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    },
  );

  testWidgets(
    'successful triage closes after encounter + vitals without provider',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubProviders(repository);
      _stubWorkspaceBootstrap(repository);
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.success(_flowDetail),
      );
      when(() => repository.recordVitals(any(), any())).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.success(_flowDetail),
      );

      await _pumpOpenDialog(tester, repository: repository);
      await _fillRequiredTriageFields(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Save triage'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      verify(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
      verify(() => repository.recordVitals('ENC000001', any())).called(1);
      verifyNever(
        () => repository.assignDoctor(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    },
  );

  testWidgets('loads providers through the encounter dialog controller', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    when(() => repository.listProviders()).thenAnswer(
      (_) async => const Result<List<OpdProviderOption>>.success(
        <OpdProviderOption>[
          OpdProviderOption(id: 'DOC-1', displayName: 'Dr Amina'),
        ],
      ),
    );
    _stubWorkspaceBootstrap(repository);

    await _pumpOpenDialog(tester, repository: repository);

    verify(() => repository.listProviders()).called(1);
    expect(find.textContaining('Dr Amina'), findsNothing);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubProviders(repository);
    _stubWorkspaceBootstrap(repository);

    await _pumpOpenDialog(
      tester,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('TRIAGE INTAKE'), findsOneWidget);
    expect(find.text('Save triage'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

Future<void> _pumpOpenDialog(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final _MockPatientRepository patientRepository = _MockPatientRepository();
  final InsuranceCatalogRepository insuranceCatalogRepository =
      InsuranceCatalogRepository(apiClient: _MockApiClient());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(repository),
        patientRepositoryProvider.overrideWithValue(patientRepository),
        insuranceCatalogRepositoryProvider.overrideWithValue(
          insuranceCatalogRepository,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: AppButton.primary(
                  label: 'Open triage',
                  leadingIcon: Icons.monitor_heart_outlined,
                  onPressed: () {
                    showPatientTriageQuickDialog(
                      context: context,
                      patient: _patient,
                      referenceData: const PatientReferenceData(),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AppButton, 'Open triage'));
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredTriageFields(WidgetTester tester) async {
  final Finder chiefComplaint = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField && widget.labelText == 'Chief complaint',
  );
  final Finder heartRate = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField && widget.labelText == 'Heart rate',
  );

  await tester.ensureVisible(chiefComplaint);
  await tester.enterText(chiefComplaint, 'Chest pain');
  await tester.ensureVisible(heartRate);
  await tester.enterText(heartRate, '88');
  await tester.pump();
}

void _stubProviders(_MockOpdRepository repository) {
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
}

void _stubWorkspaceBootstrap(_MockOpdRepository repository) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[],
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
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
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
}
