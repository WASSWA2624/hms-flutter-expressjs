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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

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
    patientDisplayName: 'Patient Example',
    stage: 'WAITING_DOCTOR_REVIEW',
    status: 'WITH_DOCTOR',
  );

  testWidgets('uses AppDialog with Correct stage and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);

    await _pumpDialog(tester, flow: flow, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(find.byType(CorrectStageDialog), findsOneWidget);
    expect(find.text('CORRECT STAGE'), findsOneWidget);
    expect(find.text('Correct stage'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
    expect(find.byType(AppSelectField<String>), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byIcon(AppActionIcons.move), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Close pops false without mutating the stage', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.correctStage(any(), any()));
  });

  testWidgets('failure keeps the dialog open and preserves reason', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.correctStage(any(), any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.enterText(find.byType(AppTextField), 'Keep this reason');
    await tester.tap(find.widgetWithText(AppButton, 'Correct stage'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Correct stage'), findsOneWidget);
    expect(find.text('Keep this reason'), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsOneWidget);
    verify(() => repository.correctStage('ENC000001', any())).called(1);
  });

  testWidgets('successful save pops true after persisted stage correction', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowDetail corrected = OpdFlowDetail(
      summary: OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'WAITING_VITALS',
        status: 'OPEN',
      ),
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.correctStage(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return const Result<OpdFlowDetail>.success(corrected);
    });
    when(() => repository.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(corrected),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.enterText(
      find.byType(AppTextField),
      'Moved back for vitals',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Correct stage'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(
      submittedPayload,
      containsPair('stage_to', 'WAITING_VITALS'),
    );
    expect(
      submittedPayload,
      containsPair('reason', 'Moved back for vitals'),
    );
    verify(() => repository.correctStage('ENC000001', any())).called(1);
  });

  testWidgets('omits targets that would undo recorded milestones', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowSummary paidAssigned = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Patient Example',
      stage: 'WAITING_DOCTOR_REVIEW',
      status: 'WITH_DOCTOR',
      providerUserId: 'doc-1',
      consultationPaid: true,
      consultationPaymentRequired: true,
      consultationPaymentStatus: 'COMPLETED',
    );
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[paidAssigned]);

    await _pumpDialog(tester, flow: paidAssigned, repository: repository);

    final AppSelectField<String> select = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    final Set<String> values = select.options
        .map((AppSelectOption<String> option) => option.value)
        .toSet();

    expect(values.contains('WAITING_CONSULTATION_PAYMENT'), isFalse);
    expect(values.contains('WAITING_VITALS'), isFalse);
    expect(values.contains('WAITING_DOCTOR_ASSIGNMENT'), isFalse);
    expect(values.contains('WAITING_DOCTOR_REVIEW'), isFalse);
    expect(values.contains('LAB_REQUESTED'), isTrue);
  });

  testWidgets('disables dismiss while saving', (WidgetTester tester) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.correctStage(any(), any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return const Result<OpdFlowDetail>.success(
        OpdFlowDetail(summary: flow),
      );
    });

    await _pumpDialog(tester, flow: flow, repository: repository);

    await tester.enterText(find.byType(AppTextField), 'In flight');
    await tester.tap(find.widgetWithText(AppButton, 'Correct stage'));
    await tester.pump();

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isFalse);
    final AppButton cancel = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Close'),
    );
    expect(cancel.enabled, isFalse);
    final AppButton submit = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Correct stage'),
    );
    expect(submit.isLoading, isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('CORRECT STAGE'), findsOneWidget);
    expect(find.text('Correct stage'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
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
                  final bool? value = await showCorrectStageDialog(
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
  required List<OpdFlowSummary> flows,
}) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: <OpdAppointment>[],
        request: AppPageRequest(pageSize: 12),
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: <OpdQueueEntry>[],
        request: AppPageRequest(pageSize: 12),
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
    (_) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
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
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => repository.listProviders(search: any(named: 'search'))).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => repository.getOpdFlow(any())).thenAnswer(
    (Invocation invocation) async {
      final String id = invocation.positionalArguments.first as String;
      final OpdFlowSummary match = flows.firstWhere(
        (OpdFlowSummary item) =>
            item.id == id || item.publicId == id || item.apiId == id,
        orElse: () => flows.first,
      );
      return Result<OpdFlowDetail>.success(OpdFlowDetail(summary: match));
    },
  );
}
