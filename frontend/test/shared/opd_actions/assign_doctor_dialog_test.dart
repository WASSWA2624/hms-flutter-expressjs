import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockApiClient extends Mock implements ApiClient {}

const OpdFlowSummary _assignDoctorFlow = OpdFlowSummary(
  id: 'encounter-1',
  publicId: 'ENC000001',
  patientDisplayName: 'Patient Example',
  stage: 'WAITING_DOCTOR_ASSIGNMENT',
  visitQueueId: 'QUE000001',
);

const OpdProviderOption _assignDoctorProvider = OpdProviderOption(
  id: 'DOC000001',
  displayName: 'Dr Assigned',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  testWidgets('uses AppDialog with Assign doctor and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(tester, flow: _assignDoctorFlow, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.byType(AssignDoctorDialog), findsOneWidget);
    expect(find.text('ASSIGN DOCTOR'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Assign doctor'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byIcon(AppActionIcons.assignDoctor), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('title is role-based and never the patient name', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(tester, flow: _assignDoctorFlow, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Assign doctor');
    expect(find.text('ASSIGN DOCTOR'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
  });

  testWidgets('shows Change doctor when a provider is already assigned', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowSummary reassign = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Patient Example',
      stage: 'WAITING_DOCTOR_REVIEW',
      providerUserId: 'DOC000001',
      providerDisplayName: 'Dr Assigned',
      consultationPaid: true,
      consultationPaidAmount: 25000,
    );
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[reassign]);

    await _pumpDialog(tester, flow: reassign, repository: repository);

    expect(find.text('CHANGE DOCTOR'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Change doctor'), findsOneWidget);
    expect(find.byType(AppPatientDetails), findsOneWidget);
    expect(find.byType(AppWorkflowStepper), findsNothing);
    expect(find.textContaining('Paid'), findsNothing);
    expect(find.textContaining('UGX'), findsNothing);
  });

  testWidgets('Cancel pops false without assigning a doctor', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    bool? result;

    await _pumpDialog(
      tester,
      flow: _assignDoctorFlow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(
      () => repository.assignDoctor(
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  testWidgets('failure keeps the dialog open and preserves selection', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(
      repository,
      providers: <OpdProviderOption>[_assignDoctorProvider],
    );
    when(
      () => repository.assignDoctor(
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: _assignDoctorFlow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await _selectProvider(tester, 'Dr Assigned');
    await tester.tap(find.widgetWithText(AppButton, 'Assign doctor'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('ASSIGN DOCTOR'), findsOneWidget);
    expect(find.text('Dr Assigned'), findsWidgets);
    verify(
      () => repository.assignDoctor(
        'ENC000001',
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });

  testWidgets('successful assign pops true after persisted mutation', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowDetail assigned = OpdFlowDetail(
      summary: OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'WAITING_DOCTOR_REVIEW',
        visitQueueId: 'QUE000001',
        providerUserId: 'DOC000001',
        providerDisplayName: 'Dr Assigned',
      ),
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(
      repository,
      providers: <OpdProviderOption>[_assignDoctorProvider],
    );
    when(
      () => repository.assignDoctor(
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((Invocation invocation) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return const Result<OpdFlowDetail>.success(assigned);
    });
    when(() => repository.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(assigned),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: _assignDoctorFlow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await _selectProvider(tester, 'Dr Assigned');
    await tester.tap(find.widgetWithText(AppButton, 'Assign doctor'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(submittedPayload, containsPair('provider_user_id', 'DOC000001'));
    verify(
      () => repository.assignDoctor(
        'ENC000001',
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
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
      flow: _assignDoctorFlow,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ASSIGN DOCTOR'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Assign doctor'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
  });
}

Future<void> _selectProvider(WidgetTester tester, String label) async {
  await tester.tap(find.byType(EditableText));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(MenuItemButton),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
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
                  final bool? value = await showAssignDoctorDialog(
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

void _stubWorkspaceLoad(
  _MockOpdRepository repository, {
  List<OpdFlowSummary>? flows,
  List<OpdProviderOption> providers = const <OpdProviderOption>[],
}) {
  final List<OpdFlowSummary> resolvedFlows =
      flows ?? const <OpdFlowSummary>[_assignDoctorFlow];
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async =>
        const Result<AppPage<OpdAppointment>>.success(
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
        items: resolvedFlows,
        request: (invocation.positionalArguments.single as OpdFlowQuery)
            .pageRequest,
        totalItemCount: resolvedFlows.length,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async =>
        const Result<AppPage<OpdFlowSummary>>.success(
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
    (_) async => Result<List<OpdProviderOption>>.success(providers),
  );
  when(() => repository.listProviders(search: any(named: 'search'))).thenAnswer(
    (_) async => Result<List<OpdProviderOption>>.success(providers),
  );
}
