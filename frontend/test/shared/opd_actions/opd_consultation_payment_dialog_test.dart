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
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_consultation_payment_dialog.dart';
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

  const OpdFlowSummary unpaidFlow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    patientDisplayName: 'Patient Example',
    stage: 'WAITING_CONSULTATION_PAYMENT',
    consultationPaymentRequired: true,
    consultationPaid: false,
    consultationFee: 25000,
    consultationCurrency: 'UGX',
  );

  const OpdFlowSummary paidFlow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    patientDisplayName: 'Patient Example',
    stage: 'WAITING_VITALS',
    consultationPaymentRequired: true,
    consultationPaid: true,
    consultationPaymentStatus: 'PAID',
    consultationFee: 25000,
    consultationPaidAmount: 25000,
    consultationCurrency: 'UGX',
  );

  testWidgets(
    'uses AppDialog with Cancel, Pay consultation, and AppActionIcons.payment',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[unpaidFlow]);

      await _pumpDialog(tester, flow: unpaidFlow, repository: repository);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
      expect(find.text('MANAGE CONSULTATION BILLING'), findsOneWidget);
      expect(find.text('Pay consultation'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Patient Example'), findsOneWidget);
      expect(find.byType(AppFormShell), findsOneWidget);
      expect(find.byIcon(AppActionIcons.payment), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('title is role-based and never the patient name', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[unpaidFlow]);

    await _pumpDialog(tester, flow: unpaidFlow, repository: repository);

    expect(find.text('MANAGE CONSULTATION BILLING'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
    expect(find.text('Patient Example'), findsOneWidget);
  });

  testWidgets('already-paid flows use Edit consultation billing commit', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[paidFlow]);

    await _pumpDialog(tester, flow: paidFlow, repository: repository);

    expect(find.text('Edit consultation billing'), findsOneWidget);
    expect(find.text('Pay consultation'), findsNothing);
  });

  testWidgets('Close pops false without calling payConsultation', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[unpaidFlow]);
    bool? result;

    await _pumpDialog(
      tester,
      flow: unpaidFlow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.payConsultation(any(), any()));
  });

  testWidgets('failure keeps the dialog open and preserves entered amount', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[unpaidFlow]);
    when(() => repository.payConsultation(any(), any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      flow: unpaidFlow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final Finder amountInput = find.descendant(
      of: find.byType(AppCurrencyAmountField),
      matching: find.byType(EditableText),
    );
    await tester.enterText(amountInput, '30000');
    await tester.tap(find.widgetWithText(AppButton, 'Pay consultation'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(tester.widget<EditableText>(amountInput).controller?.text, '30,000');
    expect(find.text('Pay consultation'), findsOneWidget);
    verify(() => repository.payConsultation('ENC000001', any())).called(1);
  });

  testWidgets('successful payment pops true after persisted payConsultation', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdFlowDetail paidDetail = OpdFlowDetail(
      summary: paidFlow,
      consultationPaymentRequired: true,
      consultationPaid: true,
      consultationPaymentStatus: 'PAID',
      consultationPaidAmount: 25000,
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[unpaidFlow]);
    when(() => repository.payConsultation(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return const Result<OpdFlowDetail>.success(paidDetail);
    });
    bool? result;

    await _pumpDialog(
      tester,
      flow: unpaidFlow,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Pay consultation'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(submittedPayload, containsPair('method', 'CASH'));
    expect(submittedPayload, containsPair('status', 'COMPLETED'));
    expect(submittedPayload, containsPair('currency', 'UGX'));
    verify(() => repository.payConsultation('ENC000001', any())).called(1);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, flows: <OpdFlowSummary>[unpaidFlow]);

    await _pumpDialog(
      tester,
      flow: unpaidFlow,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('MANAGE CONSULTATION BILLING'), findsOneWidget);
    expect(find.text('Pay consultation'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdFlowSummary flow,
  required _MockOpdRepository repository,
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
                  final bool? value = await showConsultationPaymentDialog(
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
        items: flows,
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: flows.length,
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
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => repository.listProviders(search: any(named: 'search'))).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
}
