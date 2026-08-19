import 'dart:async';

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
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_disposition_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_disposition_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
  });

  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    patientDisplayName: 'Patient Example',
    providerDisplayName: 'Provider Example',
    stage: 'WAITING_DISPOSITION',
    status: 'WITH_DOCTOR',
  );

  testWidgets('uses AppDialog with Save disposition and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);

    await _pumpDialog(tester, flow: flow, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(dialog.maxWidth, 720);
    expect(find.byType(ClinicalDispositionActionDialog), findsOneWidget);
    expect(find.byType(OpdDispositionDialog), findsOneWidget);
    expect(find.text('DISPOSITION'), findsOneWidget);
    expect(find.text('Save disposition'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AppSelectField<String>), findsOneWidget);
    expect(find.byIcon(AppActionIcons.complete), findsWidgets);
    expect(find.byIcon(AppActionIcons.save), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

    // Footer order: primary then Close — was Cancel (secondary) then Save disposition (primary).
    final List<String> footerLabels = tester
        .widgetList<AppButton>(find.byType(AppButton))
        // The header's dismiss affordance is icon-only; footer actions carry
        // labels. Filtering on that keeps this about footer order.
        .where((AppButton button) => !button.iconOnly)
        .map((AppButton button) => button.label)
        .where(
          (String label) =>
              label == 'Close' || label == 'Save disposition',
        )
        .toList();
    expect(footerLabels, <String>['Save disposition', 'Close']);
  });

  testWidgets('Close pops false without mutating disposition', (
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
    verifyNever(() => repository.disposition(any(), any()));
    verifyNever(() => repository.doctorReview(any(), any()));
  });

  testWidgets('failure keeps the dialog open and preserves notes', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.disposition(any(), any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.enterText(find.byType(AppTextField), 'Keep this note');
    await tester.tap(find.widgetWithText(AppButton, 'Save disposition'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Save disposition'), findsOneWidget);
    expect(find.text('Keep this note'), findsOneWidget);
    verify(() => repository.disposition('ENC000001', any())).called(1);
  });

  testWidgets('successful save pops true after persisted disposition', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowDetail discharged = OpdFlowDetail(
      summary: OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'DISCHARGED',
        status: 'COMPLETED',
      ),
    );
    String? submittedDecision;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.disposition(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      final Map<String, Object?> payload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      submittedDecision = payload['decision'] as String?;
      return const Result<OpdFlowDetail>.success(discharged);
    });
    when(() => repository.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(discharged),
    );
    bool? result;
    String? callbackDecision;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
      onDispositionSubmitted: (String decision) {
        callbackDecision = decision;
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Save disposition'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(submittedDecision, 'DISCHARGE');
    expect(callbackDecision, 'DISCHARGE');
    verify(() => repository.disposition('ENC000001', any())).called(1);
  });

  testWidgets('includes pharmacy option when a pharmacy order exists', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      hasPharmacyOrder: true,
    );

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    expect(field.value, 'SEND_TO_PHARMACY');
    expect(
      field.options.map((AppSelectOption<String> option) => option.value),
      contains('SEND_TO_PHARMACY'),
    );
  });

  testWidgets('ADMIT disposition persists decision and returns true', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowDetail admitted = OpdFlowDetail(
      summary: OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'WAITING_DISPOSITION',
        displayCode: 'ADMISSION_PENDING',
      ),
      admissions: <OpdRelatedRecord>[
        OpdRelatedRecord(
          id: 'ADM000001',
          kind: 'admission',
          status: 'ADMITTED',
        ),
      ],
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(() => repository.disposition(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return const Result<OpdFlowDetail>.success(admitted);
    });
    when(() => repository.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(admitted),
    );
    bool? result;
    String? callbackDecision;

    await _pumpDialog(
      tester,
      flow: flow,
      repository: repository,
      onResult: (bool? value) => result = value,
      onDispositionSubmitted: (String decision) {
        callbackDecision = decision;
      },
    );

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ADMIT');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Save disposition'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(callbackDecision, 'ADMIT');
    expect(submittedPayload, containsPair('decision', 'ADMIT'));
    verify(() => repository.disposition('ENC000001', any())).called(1);
  });

  testWidgets('blocks dismiss while disposition save is in flight', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final Completer<Result<OpdFlowDetail>> completer =
        Completer<Result<OpdFlowDetail>>();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[flow]);
    when(
      () => repository.disposition(any(), any()),
    ).thenAnswer((_) => completer.future);

    await _pumpDialog(tester, flow: flow, repository: repository);

    await tester.tap(find.widgetWithText(AppButton, 'Save disposition'));
    await tester.pump();

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isFalse);
    final AppButton cancel = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Close'),
    );
    expect(cancel.enabled, isFalse);

    completer.complete(
      const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(
      tester.widget<AppDialog>(find.byType(AppDialog)).closeEnabled,
      isTrue,
    );
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
    expect(find.text('DISPOSITION'), findsOneWidget);
    expect(find.text('Save disposition'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdFlowSummary flow,
  required OpdRepository repository,
  ValueChanged<bool?>? onResult,
  ValueChanged<String>? onDispositionSubmitted,
  bool hasPharmacyOrder = false,
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
                  final bool? value = await showOpdDispositionDialog(
                    context: context,
                    flow: flow,
                    hasPharmacyOrder: hasPharmacyOrder,
                    onDispositionSubmitted: onDispositionSubmitted,
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
