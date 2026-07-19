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

const OpdQueueEntry _queueEntry = OpdQueueEntry(
  id: 'queue-1',
  publicId: 'QUE000001',
  patientDisplayName: 'Quinn Queue',
  patientIdentifier: 'PAT-QUE',
  status: 'WAITING',
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
        items: const <OpdAppointment>[_appointment],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[_queueEntry],
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[_activeFlow, _paymentFlow],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 2,
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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1440, 900);
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
    expect(find.text('Full OPD'), findsNothing);
  });

  testWidgets('tab selection updates URL and toolbar variants', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Desk queue').first);
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'desk-queue');
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);
    expect(find.text('Full OPD'), findsOneWidget);
    expect(find.text('Full registry'), findsNothing);

    await tester.tap(find.textContaining('Payment gate').first);
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'payment-gate');
    expect(find.text('Penny Payment'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);
    expect(find.text('Billing'), findsNothing);
  });

  testWidgets('billing action appears only with billing authorization', (
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

    expect(find.text('Billing'), findsOneWidget);
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
    expect(find.text('Billing'), findsNothing);
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
