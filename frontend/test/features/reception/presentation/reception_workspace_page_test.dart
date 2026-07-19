import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/pages/reception_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

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

const OpdFlowSummary _progressedQueueFlow = OpdFlowSummary(
  id: 'flow-progressed',
  publicId: 'ENC-PROGRESSED',
  patientId: 'patient-progressed',
  visitQueueId: 'queue-2',
  patientDisplayName: 'Priya Progressed',
  patientIdentifier: 'PAT-PRIYA',
  status: 'OPEN',
  stage: 'LAB_REQUESTED',
  displayCode: 'LAB_PENDING',
  nextStep: 'COLLECT_SAMPLE',
);

const OpdFlowSummary _activeFlow = OpdFlowSummary(
  id: 'flow-active',
  publicId: 'ENC-ACTIVE',
  patientDisplayName: 'Alex Active',
  patientIdentifier: 'PAT-ACT',
  status: 'OPEN',
  stage: 'WAITING_VITALS',
);

const OpdFlowSummary _paymentFlow = OpdFlowSummary(
  id: 'flow-payment',
  publicId: 'ENC-PAYMENT',
  patientDisplayName: 'Penny Payment',
  patientIdentifier: 'PAT-PAY',
  status: 'OPEN',
  stage: 'WAITING_CONSULTATION_PAYMENT',
);

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  bool billing = false,
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
          },
      moduleEntitlements: <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'patient-registry',
          licenseStatus: 'ACTIVE',
        ),
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
        items: const <OpdFlowSummary>[
          _activeFlow,
          _paymentFlow,
          _progressedQueueFlow,
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

Future<GoRouter> _pumpWorkspace(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  AppAccessPolicy? policy,
  String initialLocation = '/reception',
  Size viewSize = const Size(1440, 900),
}) async {
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
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _policy()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
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
  });

  setUp(() {
    repository = _MockOpdRepository();
    _stubWorkspace(repository);
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
    expect(find.text('Full registry'), findsOneWidget);
    expect(find.text('Full OPD'), findsOneWidget);
    expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppTabToolbarPrimary),
        matching: find.text('Register patient'),
      ),
      findsOneWidget,
    );
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
        expect(find.text('Full registry'), findsOneWidget);
        expect(find.text('Full OPD'), findsOneWidget);
        expect(
          tester
              .widget<AppTabToolbarPrimary>(find.byType(AppTabToolbarPrimary))
              .onPressed,
          isNotNull,
        );
        for (final String label in <String>[
          'Schedule appointment',
          'Refresh',
          'Full registry',
          'Full OPD',
        ]) {
          final AppTabToolbarAction action = tester.widget<AppTabToolbarAction>(
            find.widgetWithText(AppTabToolbarAction, label),
          );
          expect(action.enabled, isTrue, reason: '$label on $tab');
          expect(action.onPressed, isNotNull, reason: '$label on $tab');
        }
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
        billing: true,
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

  testWidgets('unauthorized tabs and actions are absent', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpWorkspace(
      tester,
      repository: repository,
      policy: _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
      ),
    );

    expect(router.state.uri.queryParameters['section'], 'active');
    expect(find.textContaining('Active visits'), findsOneWidget);
    expect(find.text('Alex Active'), findsOneWidget);
    expect(find.text('Ada Appointment'), findsNothing);
    expect(find.textContaining('Appointments'), findsNothing);
    expect(find.textContaining('Desk queue'), findsNothing);
    expect(find.textContaining('Payment gate'), findsNothing);
    expect(find.text('Register patient'), findsNothing);
    expect(find.text('Schedule appointment'), findsNothing);
    expect(find.text('Full registry'), findsNothing);
    expect(find.text('Full OPD'), findsNothing);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Billing'), findsNothing);
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
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Scheduled'), findsWidgets);

      final Finder statusFilter = find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppSelectField<String> && widget.labelText == 'Status',
      );
      expect(statusFilter, findsOneWidget);
      await tester.tap(statusFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmed').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(find.text('Connie Confirmed'), findsOneWidget);
      expect(find.text('Ada Appointment'), findsNothing);
      expect(find.text('Nia New'), findsNothing);
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
    expect(find.text('Status'), findsWidgets);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('TABLE SETTINGS'), findsOneWidget);
    expect(find.text('Appointment ID'), findsOneWidget);
    expect(find.text('Assigned staff'), findsOneWidget);
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
      final Finder currentStepFilter = find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppSelectField<String> &&
            widget.labelText == 'Current step',
      );
      expect(currentStepFilter, findsOneWidget);
      await tester.tap(currentStepFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab pending').last);
      await tester.pumpAndSettle();
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

    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(find.byTooltip('Refresh in progress'), findsOneWidget);

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
    expect(appointmentCalls, 2);
  });
}
