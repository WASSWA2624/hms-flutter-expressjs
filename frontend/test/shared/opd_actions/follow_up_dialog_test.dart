import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_follow_up_action_dialog.dart';
import 'package:hosspi_hms/shared/components/app_workflow_stepper.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_follow_up_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    patientId: 'patient-1',
    patientDisplayName: 'Patient Example',
    providerDisplayName: 'Provider Example',
    patientPhone: '+256700000001',
    stage: 'WITH_DOCTOR',
    status: 'OPEN',
  );

  const PatientDetail patientDetail = PatientDetail(
    patient: Patient(
      id: 'patient-1',
      primaryPhone: '+256700000001',
      primaryEmail: 'patient@example.com',
    ),
    workspace: PatientWorkspaceSnapshot(),
  );

  testWidgets('shows patient identity without journey stepper', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    _stubPatient(patientRepository, detail: patientDetail);

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      patientRepository: patientRepository,
    );

    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AppWorkflowStepper), findsNothing);
    expect(find.byType(AppPhoneField), findsOneWidget);
    expect(find.byType(AppEmailField), findsOneWidget);
    expect(find.text('patient@example.com'), findsOneWidget);
  });

  testWidgets('uses AppDialog with Save follow-up and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    _stubPatient(patientRepository, detail: patientDetail);

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      patientRepository: patientRepository,
    );

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.byType(ClinicalFollowUpActionDialog), findsOneWidget);
    expect(find.text('FOLLOW UP'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Save follow-up'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Close'), findsOneWidget);
    expect(find.byType(AppDateField), findsOneWidget);
    expect(find.byType(AppTimeField), findsOneWidget);
    expect(find.byIcon(AppActionIcons.followUp), findsWidgets);
    expect(find.byIcon(AppActionIcons.save), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
  });

  testWidgets('Close pops false without creating a follow-up', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    _stubPatient(patientRepository, detail: patientDetail);
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.createFollowUp(any()));
  });

  testWidgets('failure keeps the dialog open and preserves notes', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    _stubPatient(patientRepository, detail: patientDetail);
    when(() => repository.createFollowUp(any())).thenAnswer(
      (_) async => const Result<void>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await tester.enterText(find.byType(AppTextField).last, 'Keep this note');
    await tester.tap(find.widgetWithText(AppButton, 'Save follow-up'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Save follow-up'), findsOneWidget);
    expect(find.text('Keep this note'), findsOneWidget);
    verify(() => repository.createFollowUp(any())).called(1);
  });

  testWidgets('successful save pops true after persisted create', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    const OpdFlowDetail refreshed = OpdFlowDetail(
      summary: flow,
      followUps: <OpdRelatedRecord>[
        OpdRelatedRecord(
          id: 'follow-up-1',
          kind: 'follow_up',
          status: 'SCHEDULED',
          title: 'Follow-up',
        ),
      ],
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    _stubPatient(patientRepository, detail: patientDetail);
    when(() => repository.createFollowUp(any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments.single as Map<String, Object?>;
      return const Result<void>.success(null);
    });
    when(() => repository.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(refreshed),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Save follow-up'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(submittedPayload, containsPair('encounter_id', 'ENC000001'));
    expect(submittedPayload, containsPair('status', 'SCHEDULED'));
    expect(submittedPayload?['scheduled_at'], isA<String>());
    verify(() => repository.createFollowUp(any())).called(1);
    verify(() => repository.getOpdFlow('ENC000001')).called(1);
    verifyNever(() => patientRepository.updatePatient(any(), any()));

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    final Result<OpdWorkspaceState> workspace = container
        .read(opdWorkspaceControllerProvider)
        .requireValue;
    final OpdWorkspaceState state = workspace.when(
      success: (OpdWorkspaceState value) => value,
      failure: (AppFailure failure) => throw StateError(failure.toString()),
    );
    expect(state.selectedFlow?.followUps.single.id, 'follow-up-1');
  });

  testWidgets('persists changed contact before creating follow-up', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    const OpdFlowSummary missingContact = OpdFlowSummary(
      id: 'encounter-2',
      publicId: 'ENC000002',
      patientId: 'patient-2',
      patientDisplayName: 'New Contact',
      stage: 'WITH_DOCTOR',
      status: 'OPEN',
    );
    const PatientDetail emptyDetail = PatientDetail(
      patient: Patient(id: 'patient-2'),
      workspace: PatientWorkspaceSnapshot(),
    );
    Map<String, Object?>? patientPayload;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[missingContact]);
    _stubPatient(patientRepository, detail: emptyDetail);
    when(() => patientRepository.updatePatient(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      patientPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return Result<Patient>.success(
        Patient(
          id: 'patient-2',
          primaryPhone: patientPayload?['primary_phone'] as String?,
          primaryEmail: patientPayload?['primary_email'] as String?,
        ),
      );
    });
    when(() => repository.createFollowUp(any())).thenAnswer(
      (_) async => const Result<void>.success(null),
    );
    when(() => repository.getOpdFlow(any())).thenAnswer(
      (_) async => Result<OpdFlowDetail>.success(
        OpdFlowDetail(summary: missingContact),
      ),
    );

    await _pumpDialog(
      tester,
      flow: missingContact,
      repository: repository,
      patientRepository: patientRepository,
    );

    await tester.enterText(find.byType(AppEmailField), 'new@example.com');
    await tester.tap(find.widgetWithText(AppButton, 'Save follow-up'));
    await tester.pumpAndSettle();

    expect(patientPayload, isNotNull);
    expect(patientPayload?['primary_email'], 'new@example.com');
    expect(patientPayload?.containsKey('primary_phone'), isFalse);
    verify(() => repository.createFollowUp(any())).called(1);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    _stubPatient(patientRepository, detail: patientDetail);

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      patientRepository: patientRepository,
      dark: true,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('FOLLOW UP'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Save follow-up'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Close'), findsOneWidget);
    expect(find.byType(AppPhoneField), findsOneWidget);
    expect(find.byType(AppEmailField), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdFlowSummary flow,
  required OpdRepository repository,
  required PatientRepository patientRepository,
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
        patientRepositoryProvider.overrideWithValue(patientRepository),
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
                  final bool? value = await showFollowUpDialog(
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

void _stubPatient(
  _MockPatientRepository repository, {
  required PatientDetail detail,
}) {
  when(() => repository.loadPatientDetail(any())).thenAnswer(
    (_) async => Result<PatientDetail>.success(detail),
  );
}

void _stubWorkspaceLoad(
  _MockOpdRepository repository, {
  required List<OpdFlowSummary> flows,
}) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => const Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: <OpdAppointment>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (Invocation invocation) async => const Result<AppPage<OpdQueueEntry>>.success(
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
        items: flows,
        request: (invocation.positionalArguments.single as OpdFlowQuery)
            .pageRequest,
        totalItemCount: flows.length,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => const Result<AppPage<OpdFlowSummary>>.success(
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
