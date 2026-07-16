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
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const OpdAppointment _arrival = OpdAppointment(
  id: 'appointment-1',
  publicId: 'APT000001',
  patientDisplayName: 'Ann Arrival',
  patientIdentifier: 'PAT-ARR',
  status: 'SCHEDULED',
);

const OpdQueueEntry _queueEntry = OpdQueueEntry(
  id: 'queue-1',
  publicId: 'QUE000001',
  patientDisplayName: 'Quinn Queue',
  patientIdentifier: 'PAT-QUE',
  status: 'WAITING',
);

const OpdFlowSummary _triageFlow = OpdFlowSummary(
  id: 'encounter-triage',
  publicId: 'ENC-TRIAGE',
  patientDisplayName: 'Tina Triage',
  patientIdentifier: 'PAT-TRI',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_TRIAGE',
  triageLevel: 'LEVEL_3',
);

const OpdFlowSummary _activeFlow = OpdFlowSummary(
  id: 'encounter-active',
  publicId: 'ENC-ACTIVE',
  patientDisplayName: 'Alex Active',
  patientIdentifier: 'PAT-ACT',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_VITALS',
);

AppAccessPolicy _opdWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      permissions: <AppPermission>{
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'encounters-vitals',
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
        items: const <OpdAppointment>[_arrival],
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
        items: const <OpdFlowSummary>[_activeFlow],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[_triageFlow],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async => const Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: 1),
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

Future<GoRouter> _pumpOpdWorkspace(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  OpdWorkspaceQuery? initialQuery,
  String initialLocation = '/opd',
  Size viewport = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/opd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: OpdWorkspacePage(
              initialQuery:
                  initialQuery ?? OpdWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
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
        appAccessPolicyProvider.overrideWithValue(_opdWritePolicy()),
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
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockOpdRepository();
    _stubWorkspace(repository);
  });

  testWidgets('renders tab strip with section counts and worklist table', (
    WidgetTester tester,
  ) async {
    await _pumpOpdWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('All worklist'), findsOneWidget);
    expect(find.textContaining('Arrivals'), findsOneWidget);
    expect(find.textContaining('Queue'), findsWidgets);
    expect(find.textContaining('Triage'), findsWidgets);
    expect(find.textContaining('Active'), findsWidgets);
    expect(find.text('Ann Arrival'), findsOneWidget);
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.text('Tina Triage'), findsOneWidget);
    expect(find.text('Alex Active'), findsOneWidget);
    expect(find.byTooltip('Start OPD encounter'), findsOneWidget);
  });

  testWidgets('switching tabs filters by category and updates URL', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpOpdWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Arrivals').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'arrivals');
    expect(find.text('Ann Arrival'), findsOneWidget);
    expect(find.text('Quinn Queue'), findsNothing);
    expect(find.text('Tina Triage'), findsNothing);
    expect(find.text('Alex Active'), findsNothing);

    await tester.tap(find.textContaining('Queue').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'queue');
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.text('Ann Arrival'), findsNothing);

    await tester.tap(find.textContaining('Triage').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'triage');
    expect(find.text('Tina Triage'), findsOneWidget);
    expect(find.text('Alex Active'), findsNothing);

    await tester.tap(find.textContaining('Active').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'active');
    expect(find.text('Alex Active'), findsOneWidget);
    expect(find.text('Tina Triage'), findsNothing);

    await tester.tap(find.textContaining('All worklist').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters.containsKey('section'), isFalse);
    expect(find.text('Ann Arrival'), findsOneWidget);
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.text('Tina Triage'), findsOneWidget);
    expect(find.text('Alex Active'), findsOneWidget);
  });

  testWidgets('deep link section=triage selects Triage tab', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpOpdWorkspace(
      tester,
      repository: repository,
      initialLocation: '/opd?section=triage',
      initialQuery: OpdWorkspaceQuery.fromUri(Uri.parse('/opd?section=triage')),
    );

    expect(router.state.uri.queryParameters['section'], 'triage');
    expect(find.text('Tina Triage'), findsOneWidget);
    expect(find.text('Ann Arrival'), findsNothing);
    expect(find.text('Quinn Queue'), findsNothing);
    expect(find.text('Alex Active'), findsNothing);
  });

  testWidgets('search filters within the active tab subset', (
    WidgetTester tester,
  ) async {
    await _pumpOpdWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Arrivals').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();

    expect(find.text('Ann Arrival'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Ann');
    await tester.pumpAndSettle();

    expect(find.text('Ann Arrival'), findsOneWidget);
  });

  testWidgets('mobile layout renders list rows', (WidgetTester tester) async {
    await _pumpOpdWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Ann Arrival'), findsOneWidget);
    expect(find.byTooltip('Start OPD encounter'), findsOneWidget);
  });
}
