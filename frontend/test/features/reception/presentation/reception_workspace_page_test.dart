import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
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
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/pages/reception_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockBillingRepository extends Mock implements BillingRepository {}

const OpdAppointment _appointment = OpdAppointment(
  id: 'appointment-1',
  publicId: 'APT000001',
  patientDisplayName: 'Ada Appointment',
  patientIdentifier: 'PAT-ADA',
  status: 'SCHEDULED',
);

const OpdAppointment _newAppointment = OpdAppointment(
  id: 'appointment-2',
  publicId: 'APT000002',
  patientDisplayName: 'Nia New',
  patientIdentifier: 'PAT-NIA',
  providerDisplayName: 'Dr New',
  reason: 'New appointment reason',
  status: 'NEW',
);

const OpdAppointment _confirmedAppointment = OpdAppointment(
  id: 'appointment-3',
  publicId: 'APT000003',
  patientDisplayName: 'Connie Confirmed',
  patientIdentifier: 'PAT-CON',
  providerDisplayName: 'Dr Confirmed',
  reason: 'Confirmed appointment reason',
  status: 'CONFIRMED',
);

const OpdAppointment _completedAppointment = OpdAppointment(
  id: 'appointment-4',
  publicId: 'APT000004',
  patientDisplayName: 'Cora Completed',
  patientIdentifier: 'PAT-COM',
  status: 'COMPLETED',
);

const OpdQueueEntry _queueEntry = OpdQueueEntry(
  id: 'queue-1',
  publicId: 'QUE000001',
  patientDisplayName: 'Quinn Queue',
  patientIdentifier: 'PAT-QUE',
  status: 'WAITING',
);

const OpdQueueEntry _progressedQueueEntry = OpdQueueEntry(
  id: 'queue-2',
  publicId: 'QUE000002',
  patientId: 'patient-progressed',
  patientDisplayName: 'Priya Progressed',
  patientIdentifier: 'PAT-PRIYA',
  status: 'IN_PROGRESS',
);

final DateTime _testNow = DateTime.now();
final DateTime _todayAtNoon = DateTime(
  _testNow.year,
  _testNow.month,
  _testNow.day,
  12,
);

final OpdFlowSummary _progressedQueueFlow = OpdFlowSummary(
  id: 'flow-progressed',
  publicId: 'ENC-PROGRESSED',
  patientId: 'patient-progressed',
  visitQueueId: 'queue-2',
  patientDisplayName: 'Priya Progressed',
  patientIdentifier: 'PAT-PRIYA',
  status: 'OPEN',
  startedAt: _todayAtNoon,
  stage: 'LAB_REQUESTED',
  displayCode: 'LAB_PENDING',
  nextStep: 'COLLECT_SAMPLE',
);

final OpdFlowSummary _activeFlow = OpdFlowSummary(
  id: 'flow-active',
  publicId: 'ENC-ACTIVE',
  patientDisplayName: 'Alex Active',
  patientIdentifier: 'PAT-ACT',
  status: 'OPEN',
  startedAt: _todayAtNoon,
  stage: 'WAITING_VITALS',
  nextStep: 'RECORD_VITALS',
);

final OpdFlowSummary _paymentFlow = OpdFlowSummary(
  id: 'flow-payment',
  publicId: 'ENC-PAYMENT',
  patientDisplayName: 'Penny Payment',
  patientIdentifier: 'PAT-PAY',
  status: 'OPEN',
  startedAt: _todayAtNoon,
  stage: 'WAITING_CONSULTATION_PAYMENT',
);

final BillingWorkItem _labInvoice = _billingInvoice(
  id: 'invoice-lab',
  displayId: 'INV-LAB',
  source: 'LABORATORY',
  description: 'Complete blood count',
  balance: 40000,
);

final BillingWorkItem _radiologyInvoice = _billingInvoice(
  id: 'invoice-radiology',
  displayId: 'INV-RAD',
  source: 'RADIOLOGY',
  description: 'Chest X-ray',
  billingStatus: 'PARTIAL',
  total: 60000,
  paid: 10000,
  balance: 50000,
);

final BillingWorkItem _pharmacyInvoice = _billingInvoice(
  id: 'invoice-pharmacy',
  displayId: 'INV-PHA',
  patientId: 'patient-pharmacy',
  patientDisplayId: 'PAT-PHA',
  patientName: 'Phoebe Pharmacy',
  encounterId: 'encounter-pharmacy',
  encounterDisplayId: 'ENC-PHA',
  source: 'PHARMACY',
  description: 'Prescribed medicines',
  balance: 25000,
);

BillingWorkItem _billingInvoice({
  required String id,
  required String displayId,
  required String source,
  required String description,
  String patientId = 'patient-payment',
  String patientDisplayId = 'PAT-PAY',
  String patientName = 'Penny Payment',
  String encounterId = 'encounter-payment',
  String encounterDisplayId = 'ENC-PAYMENT',
  String billingStatus = 'ISSUED',
  num total = 40000,
  num paid = 0,
  required num balance,
}) {
  return BillingWorkItem(
    id: id,
    displayId: displayId,
    kind: BillingWorkItemKind.invoice,
    patientId: patientId,
    patientDisplayId: patientDisplayId,
    patientDisplayName: patientName,
    encounterId: encounterId,
    encounterDisplayId: encounterDisplayId,
    sourceModule: source,
    status: 'SENT',
    billingStatus: billingStatus,
    currency: 'UGX',
    items: <BillingInvoiceItem>[
      BillingInvoiceItem(
        id: 'line-$id',
        description: description,
        sourceModule: source,
        totalPrice: total,
      ),
    ],
    financials: BillingFinancials(
      invoiceTotal: total,
      effectiveTotal: total,
      netPaidTotal: paid,
      balanceDue: balance,
    ),
  );
}

final OpdFlowSummary _currentUnlistedStageFlow = OpdFlowSummary(
  id: 'flow-consultation',
  patientDisplayName: 'Casey Consultation',
  patientIdentifier: 'PAT-CASEY',
  status: 'OPEN',
  startedAt: _todayAtNoon,
  stage: 'CONSULTATION_IN_PROGRESS',
  nextStep: 'DOCTOR_REVIEW',
);

final OpdFlowSummary _oldOpenFlow = OpdFlowSummary(
  id: 'flow-old',
  patientDisplayName: 'Owen Old',
  patientIdentifier: 'PAT-OLD',
  status: 'OPEN',
  startedAt: _todayAtNoon.subtract(const Duration(days: 1)),
  stage: 'WAITING_VITALS',
);

final OpdFlowSummary _closedTodayFlow = OpdFlowSummary(
  id: 'flow-closed',
  patientDisplayName: 'Cora Closed',
  patientIdentifier: 'PAT-CLOSED',
  status: 'CLOSED',
  startedAt: _todayAtNoon,
  stage: 'WAITING_DOCTOR_REVIEW',
);

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  bool billing = true,
  bool patientRegistry = true,
  bool schedulingQueue = true,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      permissions:
          permissions ??
          <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
            AppPermissions.lastOfficeRead,
            AppPermissions.billingRead,
          },
      moduleEntitlements: <AppModuleEntitlement>[
        if (patientRegistry)
          const AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        if (schedulingQueue)
          const AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        if (billing)
          const AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
      ],
    ),
  );
}

void _stubWorkspace(_MockOpdRepository repository) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[
          _appointment,
          _newAppointment,
          _confirmedAppointment,
          _completedAppointment,
        ],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 4,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[_queueEntry, _progressedQueueEntry],
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
        totalItemCount: 2,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[
          _activeFlow,
          _paymentFlow,
          _progressedQueueFlow,
          _currentUnlistedStageFlow,
          _oldOpenFlow,
          _closedTodayFlow,
        ],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 3,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
      ),
    ),
  );
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async => const Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: 2),
    ),
  );
  when(() => repository.getOpdFlow(any())).thenAnswer(
    (_) async =>
        Result<OpdFlowDetail>.success(OpdFlowDetail(summary: _paymentFlow)),
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

void _stubBilling(_MockBillingRepository repository) {
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final BillingWorkspaceQuery query =
        invocation.positionalArguments.single as BillingWorkspaceQuery;
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[
          _labInvoice,
          _radiologyInvoice,
          _pharmacyInvoice,
        ],
        request: query.pageRequest,
        totalItemCount: 3,
      ),
    );
  });
}

Future<GoRouter> _pumpWorkspace(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  _MockBillingRepository? billingRepository,
  AppAccessPolicy? policy,
  String initialLocation = '/reception',
  Size viewSize = const Size(1440, 900),
  ThemeData? theme,
}) async {
  final _MockBillingRepository resolvedBillingRepository =
      billingRepository ?? _MockBillingRepository();
  if (billingRepository == null) {
    _stubBilling(resolvedBillingRepository);
  }
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/reception',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: ReceptionWorkspacePage(
            initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri),
          ),
        ),
      ),
      GoRoute(
        path: '/patients',
        builder: (_, _) => const Scaffold(body: Text('Patient registry')),
      ),
      GoRoute(
        path: '/opd',
        builder: (_, _) => const Scaffold(body: Text('OPD workspace')),
      ),
      GoRoute(
        path: '/billing',
        builder: (_, _) => const Scaffold(body: Text('Billing workspace')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        opdRepositoryProvider.overrideWithValue(repository),
        billingRepositoryProvider.overrideWithValue(resolvedBillingRepository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _policy()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late _MockOpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockOpdRepository();
    _stubWorkspace(repository);
  });

  testWidgets('Try again reloads failed Reception data once with progress', (
    WidgetTester tester,
  ) async {
    final Completer<Result<AppPage<OpdAppointment>>> appointmentRetry =
        Completer<Result<AppPage<OpdAppointment>>>();
    var appointmentCalls = 0;
    when(() => repository.listAppointments(any())).thenAnswer((
      Invocation invocation,
    ) {
      appointmentCalls += 1;
      if (appointmentCalls == 1) {
        return Future<Result<AppPage<OpdAppointment>>>.value(
          Result<AppPage<OpdAppointment>>.failure(AppFailure.conflict()),
        );
      }
      return appointmentRetry.future;
    });
    var queueCalls = 0;
    when(() => repository.listVisitQueues(any())).thenAnswer((
      Invocation invocation,
    ) async {
      queueCalls += 1;
      if (queueCalls == 1) {
        return Result<AppPage<OpdQueueEntry>>.failure(AppFailure.conflict());
      }
      return Result<AppPage<OpdQueueEntry>>.success(
        AppPage<OpdQueueEntry>(
          items: const <OpdQueueEntry>[],
          request: (invocation.positionalArguments.single as OpdQueueQuery)
              .pageRequest,
        ),
      );
    });
    var flowCalls = 0;
    when(() => repository.listOpdFlows(any())).thenAnswer((
      Invocation invocation,
    ) async {
      flowCalls += 1;
      if (flowCalls == 1) {
        return Result<AppPage<OpdFlowSummary>>.failure(AppFailure.conflict());
      }
      return Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
        ),
      );
    });
    var triageCalls = 0;
    when(() => repository.listTriageQueue(any())).thenAnswer((
      Invocation invocation,
    ) async {
      triageCalls += 1;
      if (triageCalls == 1) {
        return Result<AppPage<OpdFlowSummary>>.failure(AppFailure.conflict());
      }
      return Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request:
              (invocation.positionalArguments.single as OpdTriageQueueQuery)
                  .pageRequest,
        ),
      );
    });
    final _MockBillingRepository billingRepository = _MockBillingRepository();
    var billingCalls = 0;
    when(() => billingRepository.listWorkItems(any())).thenAnswer((
      Invocation invocation,
    ) async {
      billingCalls += 1;
      return Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: const <BillingWorkItem>[],
          request:
              (invocation.positionalArguments.single as BillingWorkspaceQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      );
    });

    await _pumpWorkspace(
      tester,
      repository: repository,
      billingRepository: billingRepository,
    );
    expect(find.text('Update conflict'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(appointmentCalls, 2);
    expect(queueCalls, 2);
    expect(flowCalls, 2);
    expect(triageCalls, 2);
    expect(billingCalls, 2);
    expect(find.text('Update conflict'), findsOneWidget);
    expect(tester.widget<AppButton>(find.byType(AppButton)).isLoading, isTrue);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(appointmentCalls, 2);
    expect(billingCalls, 2);

    appointmentRetry.complete(
      Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: const <OpdAppointment>[_appointment],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada Appointment'), findsOneWidget);
    expect(find.text('Update conflict'), findsNothing);
  });

  testWidgets('appointment deep link renders backend worklist and toolbar', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpWorkspace(
      tester,
      repository: repository,
      initialLocation: '/reception?section=appointments',
    );

    expect(router.state.uri.queryParameters['section'], 'appointments');
    expect(find.text('Ada Appointment'), findsOneWidget);
    expect(find.text('Schedule appointment'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Patient registry'), findsOneWidget);
    expect(find.text('Full registry'), findsNothing);
    expect(find.byTooltip('Patient registry'), findsOneWidget);
    expect(find.bySemanticsLabel('Patient registry'), findsWidgets);
    expect(find.text('Outpatient (OPD)'), findsOneWidget);
    expect(find.text('Full OPD'), findsNothing);
    expect(
      tester
          .widget<AppTabToolbarAction>(
            find.widgetWithText(AppTabToolbarAction, 'Patient registry'),
          )
          .icon,
      AppRouteIcons.patients,
    );
    expect(
      tester
          .widget<AppTabToolbarAction>(
            find.widgetWithText(AppTabToolbarAction, 'Outpatient (OPD)'),
          )
          .icon,
      AppRouteIcons.opd,
    );
    expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppTabToolbarPrimary),
        matching: find.text('Register patient'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ada Appointment'));
    await tester.pumpAndSettle();
    expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('opdWorkflowContextPanel')),
      findsOneWidget,
    );
  });

  for (final (String name, Size size, ThemeData theme)
      in <(String, Size, ThemeData)>[
        ('desktop light', const Size(1440, 900), AppTheme.light),
        ('mobile dark', const Size(390, 844), AppTheme.dark),
      ]) {
    testWidgets('navigation shortcuts remain consistent on $name', (
      WidgetTester tester,
    ) async {
      await _pumpWorkspace(
        tester,
        repository: repository,
        viewSize: size,
        theme: theme,
      );

      final AppTabToolbarAction patientRegistry = tester
          .widget<AppTabToolbarAction>(
            find.widgetWithText(AppTabToolbarAction, 'Patient registry'),
          );
      final AppTabToolbarAction outpatient = tester.widget<AppTabToolbarAction>(
        find.widgetWithText(AppTabToolbarAction, 'Outpatient (OPD)'),
      );
      expect(patientRegistry.icon, AppRouteIcons.patients);
      expect(outpatient.icon, AppRouteIcons.opd);
      expect(find.text('Full OPD'), findsNothing);
    });
  }

  testWidgets('patient registry shortcut navigates directly without mutation', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(
      find.widgetWithText(AppTabToolbarAction, 'Patient registry'),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/patients');
    expect(find.text('Patient registry'), findsOneWidget);
    verifyNever(() => repository.createAppointment(any()));
  });

  testWidgets('outpatient shortcut navigates directly without mutation', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(
      find.widgetWithText(AppTabToolbarAction, 'Outpatient (OPD)'),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/opd');
    expect(find.text('OPD workspace'), findsOneWidget);
    verifyNever(() => repository.createAppointment(any()));
  });

  testWidgets(
    'tab selection updates URL and keeps the complete toolbar active',
    (WidgetTester tester) async {
      final GoRouter router = await _pumpWorkspace(
        tester,
        repository: repository,
      );

      for (final (String tab, String section) in <(String, String)>[
        ('Desk queue', 'desk-queue'),
        ('Active visits', 'active'),
        ('Payment gate', 'payment-gate'),
        ('Appointments', 'appointments'),
      ]) {
        await tester.tap(find.textContaining(tab).first);
        await tester.pumpAndSettle();

        expect(router.state.uri.queryParameters['section'], section);
        expect(find.text('Register patient'), findsOneWidget);
        expect(find.text('Schedule appointment'), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);
        expect(find.text('Patient registry'), findsOneWidget);
        expect(find.text('Outpatient (OPD)'), findsOneWidget);
        expect(find.text('Full OPD'), findsNothing);
        expect(find.text('Billing'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expect(router.state.uri.path, '/reception');
        expect(
          tester
              .widget<AppTabToolbarPrimary>(find.byType(AppTabToolbarPrimary))
              .onPressed,
          isNotNull,
        );
        for (final String label in <String>[
          'Schedule appointment',
          'Refresh',
          'Patient registry',
          'Outpatient (OPD)',
        ]) {
          final AppTabToolbarAction action = tester.widget<AppTabToolbarAction>(
            find.widgetWithText(AppTabToolbarAction, label),
          );
          expect(action.enabled, isTrue, reason: '$label on $tab');
          expect(action.onPressed, isNotNull, reason: '$label on $tab');
        }
        expect(
          tester
              .widgetList<AppTabToolbarAction>(find.byType(AppTabToolbarAction))
              .last
              .label,
          'Refresh',
          reason: 'Refresh must be the rightmost secondary action on $tab',
        );
      }
    },
  );

  testWidgets('billing authorization does not replace the reception primary', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      policy: _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
          AppPermissions.billingRead,
        },
      ),
      initialLocation: '/reception?section=payment-gate',
    );

    expect(find.text('Billing'), findsNothing);
    expect(find.text('Register patient'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppTabToolbarPrimary),
        matching: find.text('Register patient'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('patient registry shortcut is absent without route access', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      policy: _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
      initialLocation: '/reception?section=payment-gate',
    );

    expect(find.text('Payment gate'), findsWidgets);
    expect(find.text('Patient registry'), findsNothing);
    expect(find.text('Full registry'), findsNothing);
    expect(find.byIcon(Icons.badge_outlined), findsNothing);
  });

  testWidgets(
    'patient registry shortcut is absent when its module is inactive',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
          },
          patientRegistry: false,
        ),
        initialLocation: '/reception?section=payment-gate',
      );

      expect(find.text('Payment gate'), findsWidgets);
      expect(find.text('Patient registry'), findsNothing);
      expect(find.byIcon(Icons.badge_outlined), findsNothing);
    },
  );

  testWidgets('outpatient shortcut is absent when its module is inactive', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      policy: _policy(schedulingQueue: false),
      initialLocation: '/reception?section=payment-gate',
    );

    expect(find.text('Payment gate'), findsWidgets);
    expect(find.text('Outpatient (OPD)'), findsNothing);
    expect(find.byIcon(AppRouteIcons.opd), findsNothing);
  });

  for (final (String name, Size size) in <(String, Size)>[
    ('desktop', const Size(1440, 900)),
    ('mobile', const Size(390, 844)),
  ]) {
    testWidgets(
      'active visit billing action is absent for authorized user on $name',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpWorkspace(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
          initialLocation: '/reception?section=active',
          viewSize: size,
        );

        await tester.tap(find.text('Penny Payment').first);
        await tester.pumpAndSettle();

        expect(find.byType(FlowActionsDialog), findsOneWidget);
        expect(find.text('Pay consultation'), findsNothing);
        expect(find.text('Manage consultation billing'), findsNothing);
        expect(find.text('Update consultation billing'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expect(router.state.uri.path, '/reception');
        expect(router.state.uri.queryParameters['section'], 'active');
      },
    );
  }

  testWidgets('unauthorized tabs and actions are absent', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      policy: _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
      ),
    );

    expect(find.textContaining('Active visits'), findsNothing);
    expect(find.text('Alex Active'), findsNothing);
    expect(find.text('Ada Appointment'), findsNothing);
    expect(find.textContaining('Appointments'), findsNothing);
    expect(find.textContaining('Desk queue'), findsNothing);
    expect(find.textContaining('Payment gate'), findsNothing);
    expect(find.text('Register patient'), findsNothing);
    expect(find.text('Schedule appointment'), findsNothing);
    expect(find.text('Patient registry'), findsNothing);
    expect(find.text('Full registry'), findsNothing);
    expect(find.text('Outpatient (OPD)'), findsNothing);
    expect(find.text('Full OPD'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Billing'), findsNothing);
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets(
    'appointments expose non-terminal statuses to search and filters',
    (WidgetTester tester) async {
      await _pumpWorkspace(tester, repository: repository);

      expect(find.text('Ada Appointment'), findsOneWidget);
      expect(find.text('Nia New'), findsOneWidget);
      expect(find.text('Connie Confirmed'), findsOneWidget);
      expect(find.text('Cora Completed'), findsNothing);

      final Finder searchField = find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'Confirmed appointment reason');
      await tester.pump();
      expect(find.text('Connie Confirmed'), findsOneWidget);
      expect(find.text('Ada Appointment'), findsNothing);
      expect(find.text('Nia New'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pump();
      expect(find.text('Ada Appointment'), findsOneWidget);
      expect(find.text('Nia New'), findsOneWidget);
      expect(find.text('Connie Confirmed'), findsOneWidget);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('New'), findsWidgets);
      expect(find.text('Confirmed'), findsWidgets);
      expect(find.text('Scheduled'), findsWidgets);

      final Finder statusFilter = find.widgetWithText(
        CheckboxListTile,
        'Confirmed',
      );
      expect(statusFilter, findsOneWidget);
      await tester.tap(statusFilter);
      await tester.pump();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(find.text('Connie Confirmed'), findsOneWidget);
      expect(find.text('Ada Appointment'), findsNothing);
      expect(find.text('Nia New'), findsNothing);

      await tester.tap(find.text('Desk queue'));
      await tester.pumpAndSettle();
      expect(find.text('Priya Progressed'), findsOneWidget);
      expect(find.text('Quinn Queue'), findsOneWidget);

      await tester.tap(find.text('Appointments'));
      await tester.pumpAndSettle();
      expect(find.text('Connie Confirmed'), findsOneWidget);
      expect(find.text('Ada Appointment'), findsNothing);

      await tester.tap(find.byTooltip('Filters (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Ada Appointment'), findsOneWidget);
      expect(find.text('Nia New'), findsOneWidget);
    },
  );

  testWidgets('appointment settings contain only appointment columns', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(tester, repository: repository);

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppListTable &&
            widget.columnVisibilityStorageKey == 'reception_appointments',
      ),
      findsOneWidget,
    );
    expect(find.text('Patient name'), findsWidgets);
    expect(find.text('Scheduled'), findsWidgets);
    expect(find.text('Current step'), findsWidgets);
    expect(find.text('Next action'), findsWidgets);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('TABLE SETTINGS'), findsOneWidget);
    expect(find.text('Appointment ID'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
    expect(find.text('Queued at'), findsNothing);
    expect(find.text('Payment status'), findsNothing);
  });

  testWidgets(
    'desk queue joins active flow and renders read-only workflow guidance',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        repository: repository,
        initialLocation: '/reception?section=desk-queue',
      );

      expect(find.text('Priya Progressed'), findsOneWidget);
      expect(find.text('Current step'), findsOneWidget);
      expect(find.text('Next action'), findsOneWidget);
      expect(find.text('Lab pending'), findsOneWidget);
      expect(find.text('Collect sample'), findsOneWidget);
      expect(find.text('In Progress'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Collect sample'), findsNothing);
      expect(find.text('Start consultation'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Start consultation'),
        findsNothing,
      );

      await tester.tap(find.text('Priya Progressed'));
      await tester.pumpAndSettle();
      expect(find.byType(FlowActionsDialog), findsOneWidget);
      expect(find.text('Collect sample'), findsWidgets);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quinn Queue'));
      await tester.pumpAndSettle();
      expect(find.text('QUEUE ACTIONS'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      final Finder searchField = find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'Collect sample');
      await tester.pump();
      expect(find.text('Priya Progressed'), findsOneWidget);
      expect(find.text('Quinn Queue'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pump();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Lab pending'), findsWidgets);
      final Finder currentStepFilter = find.widgetWithText(
        CheckboxListTile,
        'Lab pending',
      );
      expect(currentStepFilter, findsOneWidget);
      await tester.tap(currentStepFilter);
      await tester.pump();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('Priya Progressed'), findsOneWidget);
      expect(find.text('Quinn Queue'), findsNothing);
    },
  );

  testWidgets('desk queue mobile cards show the same read-only guidance', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      initialLocation: '/reception?section=desk-queue',
      viewSize: const Size(390, 844),
    );

    expect(find.text('Priya Progressed'), findsOneWidget);
    expect(find.text('Lab pending'), findsOneWidget);
    expect(find.text('Collect sample'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Collect sample'), findsNothing);
  });

  testWidgets(
    'active visits shows all and only today open flows as read-only guidance',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        repository: repository,
        initialLocation: '/reception?section=active',
      );

      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.text('Penny Payment'), findsOneWidget);
      expect(find.text('Priya Progressed'), findsOneWidget);
      expect(find.text('Casey Consultation'), findsOneWidget);
      expect(find.text('Owen Old'), findsNothing);
      expect(find.text('Cora Closed'), findsNothing);
      expect(find.text('Record vitals'), findsOneWidget);
      expect(find.text('Doctor review'), findsOneWidget);
      expect(find.byType(WorkflowActionButton), findsNothing);
      expect(find.widgetWithText(AppButton, 'Record vitals'), findsNothing);

      final AppTabStrip tabs = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(
        tabs.tabs
            .singleWhere((AppTabItem tab) => tab.id == 'activeVisits')
            .count,
        4,
      );

      final Finder searchField = find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'Doctor review');
      await tester.pump();
      expect(find.text('Casey Consultation'), findsOneWidget);
      expect(find.text('Alex Active'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pump();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      final Finder currentStepFilter = find.widgetWithText(
        CheckboxListTile,
        'Consultation In Progress',
      );
      await tester.tap(currentStepFilter);
      await tester.pump();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('Casey Consultation'), findsOneWidget);
      expect(find.text('Alex Active'), findsNothing);
    },
  );

  testWidgets('active visits mobile cards keep workflow guidance read-only', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      initialLocation: '/reception?section=active',
      viewSize: const Size(390, 844),
    );

    expect(find.text('Casey Consultation'), findsOneWidget);
    expect(find.text('Doctor review'), findsOneWidget);
    expect(find.byType(WorkflowActionButton), findsNothing);
    expect(find.widgetWithText(AppButton, 'Doctor review'), findsNothing);
  });

  testWidgets(
    'payment gate aggregates all outstanding OPD services and stays read-only',
    (WidgetTester tester) async {
      final GoRouter router = await _pumpWorkspace(
        tester,
        repository: repository,
        initialLocation: '/reception?section=payment-gate',
      );

      expect(find.text('Penny Payment'), findsOneWidget);
      expect(find.text('Phoebe Pharmacy'), findsOneWidget);
      expect(find.text('Current step'), findsOneWidget);
      expect(find.text('Next action'), findsOneWidget);
      expect(find.text('Billing guidance'), findsNWidgets(2));
      expect(find.textContaining('Laboratory'), findsWidgets);
      expect(find.textContaining('Radiology'), findsWidgets);
      expect(find.textContaining('Pharmacy'), findsWidgets);
      expect(find.textContaining('90,000'), findsOneWidget);
      final AppTabStrip tabs = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(
        tabs.tabs
            .singleWhere((AppTabItem tab) => tab.id == 'paymentGate')
            .count,
        2,
      );
      expect(find.byType(WorkflowActionButton), findsNothing);

      final Finder searchField = find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'Chest X-ray');
      await tester.pump();
      expect(find.text('Penny Payment'), findsOneWidget);
      expect(find.text('Phoebe Pharmacy'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pump();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      final Finder sourceFilter = find.widgetWithText(
        CheckboxListTile,
        'Pharmacy',
      );
      await tester.tap(sourceFilter);
      await tester.pump();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('Phoebe Pharmacy'), findsOneWidget);
      expect(find.text('Penny Payment'), findsNothing);

      await tester.tap(find.text('Phoebe Pharmacy'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('receptionPaymentGateReadOnlyDetail'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('opdWorkflowContextPanel')),
        findsOneWidget,
      );
      expect(find.textContaining('Prescribed medicines'), findsOneWidget);
      expect(find.text('Receive payment'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(router.state.uri.path, '/reception');
      expect(router.state.uri.queryParameters['section'], 'payment-gate');
    },
  );

  testWidgets('payment gate mobile cards show services and amount only', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      repository: repository,
      initialLocation: '/reception?section=payment-gate',
      viewSize: const Size(390, 844),
    );

    expect(find.text('Penny Payment'), findsOneWidget);
    expect(find.textContaining('Laboratory'), findsOneWidget);
    expect(find.textContaining('Radiology'), findsOneWidget);
    expect(find.textContaining('90,000'), findsOneWidget);
    expect(find.byType(WorkflowActionButton), findsNothing);
  });

  testWidgets('payment gate has focused empty and retry states', (
    WidgetTester tester,
  ) async {
    final _MockBillingRepository emptyBilling = _MockBillingRepository();
    when(() => emptyBilling.listWorkItems(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final BillingWorkspaceQuery query =
          invocation.positionalArguments.single as BillingWorkspaceQuery;
      return Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: const <BillingWorkItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      );
    });
    await _pumpWorkspace(
      tester,
      repository: repository,
      billingRepository: emptyBilling,
      initialLocation: '/reception?section=payment-gate',
    );
    expect(find.text('No outstanding OPD charges'), findsOneWidget);
    expect(
      find.text('Patients with pending OPD charges will appear here.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final _MockBillingRepository failingBilling = _MockBillingRepository();
    when(() => failingBilling.listWorkItems(any())).thenAnswer(
      (_) async =>
          const Result<AppPage<BillingWorkItem>>.failure(AppFailure.network()),
    );
    await _pumpWorkspace(
      tester,
      repository: repository,
      billingRepository: failingBilling,
      initialLocation: '/reception?section=payment-gate',
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('payment gate removes settled patients after refresh', (
    WidgetTester tester,
  ) async {
    final _MockBillingRepository changingBilling = _MockBillingRepository();
    var calls = 0;
    when(() => changingBilling.listWorkItems(any())).thenAnswer((
      Invocation invocation,
    ) async {
      calls += 1;
      final BillingWorkspaceQuery query =
          invocation.positionalArguments.single as BillingWorkspaceQuery;
      return Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: calls == 1
              ? <BillingWorkItem>[_labInvoice]
              : const <BillingWorkItem>[],
          request: query.pageRequest,
          totalItemCount: calls == 1 ? 1 : 0,
        ),
      );
    });
    await _pumpWorkspace(
      tester,
      repository: repository,
      billingRepository: changingBilling,
      initialLocation: '/reception?section=payment-gate',
    );
    expect(find.text('Penny Payment'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Penny Payment'), findsNothing);
    expect(find.text('No outstanding OPD charges'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('refresh synchronizes every section without loading the page', (
    WidgetTester tester,
  ) async {
    final _MockBillingRepository billingRepository = _MockBillingRepository();
    _stubBilling(billingRepository);
    await _pumpWorkspace(
      tester,
      repository: repository,
      billingRepository: billingRepository,
    );

    final appointmentCompleter = Completer<Result<AppPage<OpdAppointment>>>();
    final queueCompleter = Completer<Result<AppPage<OpdQueueEntry>>>();
    final flowCompleter = Completer<Result<AppPage<OpdFlowSummary>>>();
    final billingCompleter = Completer<Result<AppPage<BillingWorkItem>>>();
    when(
      () => repository.listAppointments(any()),
    ).thenAnswer((_) => appointmentCompleter.future);
    when(
      () => repository.listVisitQueues(any()),
    ).thenAnswer((_) => queueCompleter.future);
    when(
      () => repository.listOpdFlows(any()),
    ).thenAnswer((_) => flowCompleter.future);
    when(
      () => billingRepository.listWorkItems(any()),
    ).thenAnswer((_) => billingCompleter.future);

    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(find.text('Ada Appointment'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppListTable && widget.isLoading,
      ),
      findsNothing,
    );
    expect(
      tester.widget<AppSearchBar>(find.byType(AppSearchBar)).isLoading,
      isFalse,
    );
    final AppTabToolbarPrimary register = tester.widget<AppTabToolbarPrimary>(
      find.byType(AppTabToolbarPrimary),
    );
    expect(register.enabled, isTrue);
    expect(register.isLoading, isFalse);
    final AppTabToolbarAction schedule = tester.widget<AppTabToolbarAction>(
      find.widgetWithText(AppTabToolbarAction, 'Schedule appointment'),
    );
    expect(schedule.enabled, isTrue);
    expect(schedule.isLoading, isFalse);
    final AppTabToolbarAction refresh = tester.widget<AppTabToolbarAction>(
      find.widgetWithText(AppTabToolbarAction, 'Refresh'),
    );
    expect(refresh.enabled, isFalse);
    expect(refresh.isLoading, isTrue);
    expect(
      find.descendant(
        of: find.widgetWithText(AppTabToolbarAction, 'Refresh'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    const OpdAppointment refreshedAppointment = OpdAppointment(
      id: 'appointment-refreshed',
      patientDisplayName: 'Fresh Appointment',
      status: 'SCHEDULED',
    );
    const OpdQueueEntry refreshedQueue = OpdQueueEntry(
      id: 'queue-refreshed',
      patientDisplayName: 'Fresh Queue',
      status: 'WAITING',
    );
    final OpdFlowSummary refreshedFlow = OpdFlowSummary(
      id: 'flow-refreshed',
      patientDisplayName: 'Fresh Active',
      status: 'OPEN',
      startedAt: _todayAtNoon,
      stage: 'WAITING_VITALS',
    );
    final BillingWorkItem refreshedInvoice = _billingInvoice(
      id: 'invoice-refreshed',
      displayId: 'INV-REFRESHED',
      patientId: 'patient-refreshed',
      patientDisplayId: 'PAT-REFRESHED',
      patientName: 'Fresh Payment',
      encounterId: 'encounter-refreshed',
      encounterDisplayId: 'ENC-REFRESHED',
      source: 'LABORATORY',
      description: 'Refreshed service',
      balance: 10000,
    );
    appointmentCompleter.complete(
      const Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: <OpdAppointment>[refreshedAppointment],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    queueCompleter.complete(
      const Result<AppPage<OpdQueueEntry>>.success(
        AppPage<OpdQueueEntry>(
          items: <OpdQueueEntry>[refreshedQueue],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    flowCompleter.complete(
      Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: <OpdFlowSummary>[refreshedFlow],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    billingCompleter.complete(
      Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: <BillingWorkItem>[refreshedInvoice],
          request: const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppTabStrip tabs = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    for (final AppTabItem tab in tabs.tabs) {
      expect(tab.count, 1, reason: tab.id);
    }
    expect(find.text('Fresh Appointment'), findsOneWidget);
    await tester.tap(find.textContaining('Desk queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Fresh Queue'), findsOneWidget);
    await tester.tap(find.textContaining('Active visits').first);
    await tester.pumpAndSettle();
    expect(find.text('Fresh Active'), findsOneWidget);
    await tester.tap(find.textContaining('Payment gate').first);
    await tester.pumpAndSettle();
    expect(find.text('Fresh Payment'), findsOneWidget);
  });

  testWidgets('refresh is single-flight and exposes progress tooltip', (
    WidgetTester tester,
  ) async {
    final Completer<Result<AppPage<OpdAppointment>>> completer =
        Completer<Result<AppPage<OpdAppointment>>>();
    var appointmentCalls = 0;
    when(() => repository.listAppointments(any())).thenAnswer((
      Invocation invocation,
    ) {
      appointmentCalls += 1;
      if (appointmentCalls == 1) {
        return Future<Result<AppPage<OpdAppointment>>>.value(
          Result<AppPage<OpdAppointment>>.success(
            AppPage<OpdAppointment>(
              items: const <OpdAppointment>[_appointment],
              request:
                  (invocation.positionalArguments.single as OpdAppointmentQuery)
                      .pageRequest,
            ),
          ),
        );
      }
      return completer.future;
    });
    await _pumpWorkspace(tester, repository: repository);

    final Finder refreshAction = find.widgetWithText(
      AppTabToolbarAction,
      'Refresh',
    );
    final Size idleSize = tester.getSize(refreshAction);
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(find.byTooltip('Refresh in progress'), findsOneWidget);
    expect(find.bySemanticsLabel('Refresh in progress'), findsOneWidget);
    expect(tester.widget<AppTabToolbarAction>(refreshAction).isLoading, isTrue);
    expect(tester.getSize(refreshAction), idleSize);
    expect(
      find.descendant(
        of: refreshAction,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(appointmentCalls, 2);

    completer.complete(
      const Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: <OpdAppointment>[_appointment],
          request: AppPageRequest(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(
      tester.widget<AppTabToolbarAction>(refreshAction).isLoading,
      isFalse,
    );
    expect(
      find.descendant(of: refreshAction, matching: find.byIcon(Icons.refresh)),
      findsOneWidget,
    );
    expect(appointmentCalls, 2);
  });

  testWidgets('refresh restores its icon and retains data after failure', (
    WidgetTester tester,
  ) async {
    var appointmentCalls = 0;
    when(() => repository.listAppointments(any())).thenAnswer((
      Invocation invocation,
    ) async {
      appointmentCalls += 1;
      if (appointmentCalls > 1) {
        return const Result<AppPage<OpdAppointment>>.failure(
          AppFailure.network(),
        );
      }
      return Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: const <OpdAppointment>[
            _appointment,
            _newAppointment,
            _confirmedAppointment,
            _completedAppointment,
          ],
          request:
              (invocation.positionalArguments.single as OpdAppointmentQuery)
                  .pageRequest,
          totalItemCount: 4,
        ),
      );
    });
    await _pumpWorkspace(tester, repository: repository);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    final Finder refreshAction = find.widgetWithText(
      AppTabToolbarAction,
      'Refresh',
    );
    expect(find.text('Ada Appointment'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(
      tester.widget<AppTabToolbarAction>(refreshAction).isLoading,
      isFalse,
    );
    expect(
      find.descendant(of: refreshAction, matching: find.byIcon(Icons.refresh)),
      findsOneWidget,
    );
    expect(appointmentCalls, 2);
  });

  testWidgets('background mutation does not reload the whole worklist', (
    WidgetTester tester,
  ) async {
    final Completer<Result<OpdAppointment>> completer =
        Completer<Result<OpdAppointment>>();
    when(
      () => repository.createAppointment(any()),
    ).thenAnswer((_) => completer.future);
    await _pumpWorkspace(tester, repository: repository);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ReceptionWorkspacePage)),
    );
    unawaited(
      container
          .read(opdWorkspaceControllerProvider.notifier)
          .createAppointment(<String, Object?>{}),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppListTable && widget.isLoading,
      ),
      findsNothing,
    );
    final AppTabToolbarPrimary registerAction = tester
        .widgetList<AppTabToolbarPrimary>(find.byType(AppTabToolbarPrimary))
        .singleWhere(
          (AppTabToolbarPrimary action) => action.label == 'Register patient',
        );
    expect(registerAction.isLoading, isFalse);

    completer.complete(const Result<OpdAppointment>.success(_newAppointment));
    await tester.pumpAndSettle();
  });
}
