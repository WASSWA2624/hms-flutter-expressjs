import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_actions.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const Patient _patient = Patient(
  id: 'PAT-1001',
  publicId: 'PAT-1001',
  tenantId: 'TEN-1',
  facilityId: 'FAC-1',
  displayName: 'Amina Kato',
  firstName: 'Amina',
  lastName: 'Kato',
);

const PatientReferenceData _referenceData = PatientReferenceData(
  facilities: <PatientReferenceOption>[
    PatientReferenceOption(id: 'FAC-1', label: 'Main Campus'),
  ],
);

const OpdFlowDetail _flowDetail = OpdFlowDetail(
  summary: OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    patientId: 'PAT-1001',
    status: 'OPEN',
    stage: 'WAITING_VITALS',
  ),
  consultationPaymentRequired: true,
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
    'uses AppDialog with Cancel, Billing chrome, and AppActionIcons.payment',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubOpdWorkspaceLoad(repository);

      await _pumpDialog(tester, repository: repository);

      expect(find.byType(PatientBillingQuickDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('CONSULTATION BILLING'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.payment), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
    },
  );

  testWidgets('title never uses the patient display name', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubOpdWorkspaceLoad(repository);

    await _pumpDialog(tester, repository: repository);

    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('Kato'), findsNothing);
    expect(find.text('CONSULTATION BILLING'), findsOneWidget);
  });

  testWidgets('hides mark-paid when billing write is denied', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubOpdWorkspaceLoad(repository);

    await _pumpDialog(
      tester,
      repository: repository,
      canRecordPayment: false,
    );

    expect(find.text('Payment received'), findsNothing);
  });

  testWidgets('Cancel pops false without calling startOpdFlow', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubOpdWorkspaceLoad(repository);
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(
      () => repository.startOpdFlow(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  testWidgets('failure keeps dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubOpdWorkspaceLoad(repository);
    when(
      () => repository.startOpdFlow(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await _enterFee(tester, '15000');
    await tester.tap(find.widgetWithText(AppButton, 'Billing'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(PatientBillingQuickDialog), findsOneWidget);
  });

  testWidgets(
    'success submits walk-in consultation billing and pops true',
    (WidgetTester tester) async {
      final _MockOpdRepository repository = _MockOpdRepository();
      Map<String, Object?>? payload;
      _stubOpdWorkspaceLoad(repository);
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((Invocation invocation) async {
        payload = invocation.positionalArguments.single as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(_flowDetail);
      });
      bool? result;

      await _pumpDialog(
        tester,
        repository: repository,
        onResult: (bool? value) => result = value,
      );

      await _enterFee(tester, '25000');

      final Finder notesField = find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppTextField && widget.labelText == 'Notes',
        ),
        matching: find.byType(EditableText),
      );
      await tester.enterText(notesField, 'Walk-in billing');

      await tester.tap(find.widgetWithText(AppButton, 'Billing'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AppDialog), findsNothing);
      expect(payload?['arrival_mode'], 'WALK_IN');
      expect(payload?['patient_id'], 'PAT-1001');
      expect(payload?['facility_id'], 'FAC-1');
      expect(payload?['tenant_id'], 'TEN-1');
      expect(payload?['consultation_fee'], '25000');
      expect(payload?['create_consultation_invoice'], isTrue);
      expect(payload?['require_consultation_payment'], isTrue);
      expect(payload?['reuse_open_encounter'], isTrue);
      expect(payload?['notes'], 'Walk-in billing');
      expect(payload?.containsKey('pay_now'), isFalse);
    },
  );

  testWidgets('pay_now is included when payment received is checked', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    Map<String, Object?>? payload;
    _stubOpdWorkspaceLoad(repository);
    when(
      () => repository.startOpdFlow(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((Invocation invocation) async {
      payload = invocation.positionalArguments.single as Map<String, Object?>;
      return const Result<OpdFlowDetail>.success(_flowDetail);
    });

    await _pumpDialog(tester, repository: repository, canRecordPayment: true);

    await _enterFee(tester, '25000');
    await tester.ensureVisible(find.text('Payment received'));
    await tester.tap(find.text('Payment received'));
    await tester.pumpAndSettle();

    final Finder refField = find.descendant(
      of: find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppTextField &&
            widget.labelText == 'Transaction reference',
      ),
      matching: find.byType(EditableText),
    );
    await tester.enterText(refField, 'TX-99');
    await tester.tap(find.widgetWithText(AppButton, 'Billing'));
    await tester.pumpAndSettle();

    final Map<String, Object?> payNow =
        payload!['pay_now']! as Map<String, Object?>;
    expect(payNow, containsPair('method', 'CASH'));
    expect(payNow, containsPair('amount', '25000'));
    expect(payNow, containsPair('status', 'COMPLETED'));
    expect(payNow, containsPair('transaction_ref', 'TX-99'));
    expect(payNow['paid_at'], isA<String>());
  });

  testWidgets('remains usable on compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubOpdWorkspaceLoad(repository);

    await _pumpDialog(
      tester,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
      canRecordPayment: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(PatientBillingQuickDialog), findsOneWidget);
    expect(find.text('CONSULTATION BILLING'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Payment received'), findsOneWidget);
  });
}

Future<void> _enterFee(WidgetTester tester, String amount) async {
  final Finder amountInput = find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppCurrencyAmountField &&
          widget.amountLabelText == 'Consultation fee',
    ),
    matching: find.byType(EditableText),
  );
  await tester.enterText(amountInput, amount);
  await tester.pump();
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdRepository repository,
  ValueChanged<bool?>? onResult,
  bool canRecordPayment = false,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(repository),
        appAccessPolicyProvider.overrideWithValue(
          canRecordPayment
              ? _billingWritePolicy()
              : AppAccessPolicy.fromSession(null),
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
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return Center(
                child: AppButton.primary(
                  label: 'Open billing',
                  leadingIcon: AppActionIcons.payment,
                  onPressed: () async {
                    await ref.read(opdWorkspaceControllerProvider.future);
                    if (!context.mounted) {
                      return;
                    }
                    final bool? value = await showPatientBillingQuickDialog(
                      context: context,
                      patient: _patient,
                      referenceData: _referenceData,
                    );
                    onResult?.call(value);
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
  await tester.tap(find.widgetWithText(AppButton, 'Open billing'));
  await tester.pumpAndSettle();
}

AppAccessPolicy _billingWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

void _stubOpdWorkspaceLoad(_MockOpdRepository repository) {
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
