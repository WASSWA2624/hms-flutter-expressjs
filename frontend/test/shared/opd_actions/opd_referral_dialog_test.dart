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
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_referral_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_referral_dialog.dart';
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
    providerDisplayName: 'Provider Example',
    stage: 'WITH_DOCTOR',
    status: 'OPEN',
  );

  testWidgets('uses AppDialog with Save referral and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);

    await _pumpDialog(tester, flow: flow, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.byType(ClinicalReferralActionDialog), findsOneWidget);
    expect(find.text('REFER'), findsOneWidget);
    expect(find.text('Save referral'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.byIcon(AppActionIcons.referral), findsWidgets);
    expect(find.byIcon(AppActionIcons.save), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
  });

  testWidgets('title never uses the patient display name', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);

    await _pumpDialog(tester, flow: flow, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Refer');
    expect(find.text('REFER'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
  });

  testWidgets('Cancel pops false without creating a referral', (
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

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.createReferral(any()));
  });

  testWidgets('failure keeps the dialog open and preserves entered fields', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.createReferral(any())).thenAnswer(
      (_) async => const Result<void>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final Finder fields = find.byType(AppTextField);
    await tester.enterText(fields.at(0), 'Regional Referral Hospital');
    await tester.enterText(fields.at(1), 'Specialist review needed');
    await tester.enterText(fields.at(2), 'Keep this note');
    await tester.tap(find.widgetWithText(AppButton, 'Save referral'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Save referral'), findsOneWidget);
    expect(find.text('Regional Referral Hospital'), findsOneWidget);
    expect(find.text('Specialist review needed'), findsOneWidget);
    expect(find.text('Keep this note'), findsOneWidget);
    verify(() => repository.createReferral(any())).called(1);
  });

  testWidgets('successful save posts referral payload and pops true', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowDetail detail = OpdFlowDetail(
      summary: flow,
      referrals: <OpdRelatedRecord>[
        OpdRelatedRecord(
          id: 'referral-1',
          kind: 'referral',
          status: 'REQUESTED',
          title: 'Regional Referral Hospital',
        ),
      ],
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.createReferral(any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments.first as Map<String, Object?>;
      return const Result<void>.success(null);
    });
    when(
      () => repository.getOpdFlow(any()),
    ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final Finder fields = find.byType(AppTextField);
    await tester.enterText(fields.at(0), 'Regional Referral Hospital');
    await tester.enterText(fields.at(1), 'Specialist review needed');
    await tester.enterText(fields.at(2), 'Optional note');
    await tester.tap(find.widgetWithText(AppButton, 'Save referral'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(submittedPayload, isNotNull);
    expect(submittedPayload!['encounter_id'], 'ENC000001');
    expect(
      submittedPayload!['external_facility_name'],
      'Regional Referral Hospital',
    );
    expect(submittedPayload!['reason'], 'Specialist review needed');
    expect(submittedPayload!['notes'], 'Optional note');
    verify(() => repository.createReferral(any())).called(1);
    verify(() => repository.getOpdFlow('ENC000001')).called(1);
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
    expect(find.text('REFER'), findsOneWidget);
    expect(find.text('Save referral'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
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
                  final bool? value = await showReferralDialog(
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
        items: flows,
        request: (invocation.positionalArguments.single as OpdFlowQuery)
            .pageRequest,
        totalItemCount: flows.length,
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
}
