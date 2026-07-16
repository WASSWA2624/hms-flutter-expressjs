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
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/features/theater/presentation/pages/theater_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

Finder _toolbarAction(String label) => find.descendant(
  of: find.byType(AppTabToolbarAction),
  matching: find.text(label),
);

AppListTable<TheaterCase> _table(WidgetTester tester) {
  return tester.widget<AppListTable<TheaterCase>>(
    find.byType(AppListTable<TheaterCase>),
  );
}

AppAccessPolicy _theaterReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['NURSE']),
      permissions: <AppPermission>{AppPermissions.clinicalRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'theatre-anesthesia',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

const TheaterCase _scheduledCase = TheaterCase(
  id: 'TC-SCHED',
  displayId: 'TC-SCHED',
  patientDisplayName: 'Sam Scheduled',
  status: 'SCHEDULED',
  workflowStage: 'PRE_OP',
);

const TheaterCase _inTheaterCase = TheaterCase(
  id: 'TC-OR',
  displayId: 'TC-OR',
  patientDisplayName: 'Ira InTheater',
  status: 'IN_PROGRESS',
  workflowStage: 'INTRA_OP',
);

const TheaterCase _recoveryCase = TheaterCase(
  id: 'TC-REC',
  displayId: 'TC-REC',
  patientDisplayName: 'Riley Recovery',
  status: 'IN_PROGRESS',
  workflowStage: 'POST_OP',
);

AppAccessPolicy _theaterWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['DOCTOR']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'theatre-anesthesia',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubCases(
  _MockTheaterRepository repository, {
  List<TheaterCase> cases = const <TheaterCase>[
    _scheduledCase,
    _inTheaterCase,
    _recoveryCase,
  ],
}) {
  when(() => repository.listCases(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final TheaterCaseQuery query =
        invocation.positionalArguments.single as TheaterCaseQuery;
    List<TheaterCase> items = cases;
    final String? status = query.status?.trim().toUpperCase();
    final String? stage = query.stage?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = items
          .where((TheaterCase item) => item.normalizedStatus == status)
          .toList(growable: false);
    }
    if (stage != null && stage.isNotEmpty) {
      items = items
          .where((TheaterCase item) => item.normalizedStage == stage)
          .toList(growable: false);
    }
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((TheaterCase item) {
            final String name = (item.patientDisplayName ?? '').toLowerCase();
            final String id = item.effectiveDisplayId.toLowerCase();
            return name.contains(search) || id.contains(search);
          })
          .toList(growable: false);
    }
    return Result<AppPage<TheaterCase>>.success(
      AppPage<TheaterCase>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.getCase(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final TheaterCase match = cases.firstWhere(
      (TheaterCase item) => item.id == id || item.effectiveDisplayId == id,
      orElse: () => cases.first,
    );
    return Result<TheaterCase>.success(match);
  });
}

Future<GoRouter> _pumpTheaterWorkspace(
  WidgetTester tester, {
  required _MockTheaterRepository repository,
  TheaterBoardQuery? initialQuery,
  String initialLocation = '/theater',
  Size viewport = const Size(1440, 900),
  AppAccessPolicy? accessPolicy,
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
        path: '/theater',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: TheaterWorkspacePage(
              initialQuery:
                  initialQuery ?? TheaterBoardQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        theaterRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _theaterWritePolicy(),
        ),
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
  late _MockTheaterRepository repository;

  setUpAll(() {
    registerFallbackValue(const TheaterCaseQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockTheaterRepository();
    _stubCases(repository);
  });

  testWidgets('renders tab strip with section counts and case table', (
    WidgetTester tester,
  ) async {
    await _pumpTheaterWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspace), findsNothing);
    expect(find.byType(AppListTable<TheaterCase>), findsOneWidget);
    expect(find.textContaining('Scheduled'), findsWidgets);
    expect(find.textContaining('In theater'), findsWidgets);
    expect(find.textContaining('Recovery'), findsWidgets);
    expect(find.textContaining('All cases'), findsWidgets);
    expect(find.text('Sam Scheduled'), findsOneWidget);
    expect(find.text('Ira InTheater'), findsOneWidget);
    expect(find.text('Riley Recovery'), findsOneWidget);
    expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    expect(_toolbarPrimary('Schedule case'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('switching tabs applies status/stage filters and updates URL', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpTheaterWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubCases(repository);

    await tester.tap(find.textContaining('Scheduled').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'scheduled');
    List<TheaterCaseQuery> queries = verify(
      () => repository.listCases(captureAny()),
    ).captured.cast<TheaterCaseQuery>();
    expect(
      queries.any((TheaterCaseQuery q) => q.status == 'SCHEDULED'),
      isTrue,
    );
    expect(find.text('Sam Scheduled'), findsOneWidget);
    expect(find.text('Ira InTheater'), findsNothing);

    clearInteractions(repository);
    _stubCases(repository);

    await tester.tap(find.textContaining('In theater').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'in-theater');
    queries = verify(
      () => repository.listCases(captureAny()),
    ).captured.cast<TheaterCaseQuery>();
    expect(
      queries.any((TheaterCaseQuery q) => q.status == 'IN_PROGRESS'),
      isTrue,
    );

    clearInteractions(repository);
    _stubCases(repository);

    await tester.tap(find.textContaining('Recovery').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'recovery');
    queries = verify(
      () => repository.listCases(captureAny()),
    ).captured.cast<TheaterCaseQuery>();
    expect(queries.any((TheaterCaseQuery q) => q.stage == 'POST_OP'), isTrue);
    expect(find.text('Riley Recovery'), findsOneWidget);

    clearInteractions(repository);
    _stubCases(repository);

    await tester.tap(find.textContaining('All cases').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters.containsKey('section'), isFalse);
    queries = verify(
      () => repository.listCases(captureAny()),
    ).captured.cast<TheaterCaseQuery>();
    expect(
      queries.any((TheaterCaseQuery q) => q.status == null && q.stage == null),
      isTrue,
    );
    expect(_toolbarPrimary('Schedule case'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);
  });

  testWidgets('deep link section=in-theater selects In theater tab', (
    WidgetTester tester,
  ) async {
    await _pumpTheaterWorkspace(
      tester,
      repository: repository,
      initialLocation: '/theater?section=in-theater',
      initialQuery: TheaterBoardQuery.fromUri(
        Uri.parse('/theater?section=in-theater'),
      ),
    );

    final List<TheaterCaseQuery> queries = verify(
      () => repository.listCases(captureAny()),
    ).captured.cast<TheaterCaseQuery>();
    expect(
      queries.any((TheaterCaseQuery q) => q.status == 'IN_PROGRESS'),
      isTrue,
    );
    expect(find.text('Ira InTheater'), findsOneWidget);
    expect(find.text('Sam Scheduled'), findsNothing);
    expect(_toolbarPrimary('Schedule case'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);
  });

  testWidgets('deep link focusCaseId still opens case detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpTheaterWorkspace(
      tester,
      repository: repository,
      initialLocation: '/theater?id=TC-SCHED&panel=checklist',
      initialQuery: TheaterBoardQuery.fromUri(
        Uri.parse('/theater?id=TC-SCHED&panel=checklist'),
      ),
    );

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    verify(() => repository.getCase(any())).called(greaterThanOrEqualTo(1));
  });

  testWidgets('read-only users see refresh-only tab toolbar', (
    WidgetTester tester,
  ) async {
    await _pumpTheaterWorkspace(
      tester,
      repository: repository,
      accessPolicy: _theaterReadOnlyPolicy(),
    );

    expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    expect(_toolbarPrimary('Schedule case'), findsNothing);
    expect(_toolbarPrimary('Refresh'), findsOneWidget);
    expect(find.byType(AppTabToolbarAction), findsNothing);
  });

  testWidgets('AppTabStrip renders on narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    await _pumpTheaterWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Scheduled'), findsWidgets);
    expect(find.textContaining('Recovery'), findsWidgets);
  });
}
