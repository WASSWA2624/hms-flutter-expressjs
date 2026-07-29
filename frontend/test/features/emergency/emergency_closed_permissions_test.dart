import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyCaseSummary _closedCase = EmergencyCaseSummary(
  id: 'EME-CLOSED-1',
  displayId: 'EME-CLOSED-1',
  patientId: 'PAT-1',
  patientDisplayId: 'PAT-1',
  patientDisplayName: 'Closed Casey',
  severity: 'HIGH',
  status: 'CLOSED',
  handoff: EmergencyHandoffOutcome(
    destination: 'OPD',
    route: 'opd',
    receivingDisplayId: 'ENC-1',
    encounterDisplayId: 'ENC-1',
    stage: 'WAITING_VITALS',
  ),
);

const EmergencyCaseSummary _openCase = EmergencyCaseSummary(
  id: 'EME-OPEN-1',
  displayId: 'EME-OPEN-1',
  patientDisplayName: 'Open Oliver',
  severity: 'CRITICAL',
  status: 'OPEN',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['NURSE'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBoard(
  _MockEmergencyRepository repository, {
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_closedCase],
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  EmergencyCaseDetail? detail,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Result<AppPage<EmergencyCaseSummary>>.success(
      AppPage<EmergencyCaseSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detail != null) {
      return Result<EmergencyCaseDetail>.success(detail);
    }
    final EmergencyCaseSummary summary =
        invocation.positionalArguments.first as EmergencyCaseSummary;
    return Result<EmergencyCaseDetail>.success(
      EmergencyCaseDetail(
        summary: summary,
        triageAssessments: const <EmergencyTriageAssessment>[
          EmergencyTriageAssessment(
            id: 'TRA-1',
            emergencyCaseId: 'EME-CLOSED-1',
            triageLevel: 'LEVEL_2',
          ),
        ],
        responses: const <EmergencyResponseRecord>[
          EmergencyResponseRecord(
            id: 'ERS-1',
            emergencyCaseId: 'EME-CLOSED-1',
            notes: 'Stabilized',
          ),
        ],
        dispatches: const <EmergencyAmbulanceDispatch>[
          EmergencyAmbulanceDispatch(
            id: 'DSP-1',
            status: 'AVAILABLE',
            ambulanceLabel: 'Unit 7',
          ),
        ],
      ),
    );
  });
}

Future<void> _pumpClosedTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary>? items,
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  EmergencyCaseDetail? detail,
  String initialLocation = '/emergency?scope=closed',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(
    repository,
    items: items ?? <EmergencyCaseSummary>[_closedCase],
    listOverride: listOverride,
    detail: detail,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/emergency',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: EmergencyWorkspacePage(
              initialQuery: EmergencyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        emergencyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockEmergencyRepository repository;

  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(const EmergencyCaseSummary(id: 'fallback'));
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('EmergencyClosedAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        EmergencyClosedAtomPermissions.tab,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyClosedAtomPermissions.write,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyClosedAtomPermissions.delete,
        same(emergencyWorkspaceDeleteRequirement),
      );
      expect(
        EmergencyClosedAtomPermissions.handoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyClosedAtomPermissions.routeEntry,
        same(emergencyWorkspaceEntryRequirement),
      );
      expect(
        EmergencyClosedAtomPermissions.printSummary,
        same(EmergencyActiveCasesAtomPermissions.printSummary),
      );
      expect(
        EmergencyClosedAtomPermissions.quickArrival,
        same(EmergencyAllAtomPermissions.quickArrival),
      );
      expect(
        emergencyBoardShowsNextActionColumn(
          _policy(permissions: <AppPermission>{AppPermissions.emergencyWrite}),
          EmergencyBoardTab.closed,
        ),
        isFalse,
      );
      expect(emergencyShowsQuickArrival(EmergencyBoardTab.closed), isFalse);
    });

    test('∩ denial: missing emergency:write fails write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(EmergencyClosedAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(EmergencyClosedAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        EmergencyClosedAtomPermissions.quickArrival.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyClosedAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
      expect(canWriteEmergency(reader), isFalse);
      expect(canDeleteEmergency(reader), isFalse);
    });

    test('∩ denial: write-only staff fail delete ∩', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(EmergencyClosedAtomPermissions.write.isAllowed(writer), isTrue);
      expect(EmergencyClosedAtomPermissions.delete.isAllowed(writer), isFalse);
      expect(canDeleteEmergency(writer), isFalse);
    });

    test('∪ allowance: operations:read alone satisfies route entry', () {
      // Use OTHER so role packs do not inject emergency:read/write.
      final AppAccessPolicy operations = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
        roles: const <String>['OTHER'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        EmergencyClosedAtomPermissions.routeEntry.isAllowed(operations),
        isTrue,
      );
      expect(canEnterEmergencyWorkspace(operations), isTrue);
      // Tab read remains ∩ emergency:read — entry ∪ does not unlock Closed.
      expect(EmergencyClosedAtomPermissions.tab.isAllowed(operations), isFalse);
      expect(canViewEmergencyClosed(operations), isFalse);
    });

    test('∪ allowance: emergency:write alone satisfies route entry', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
        roles: const <String>['OTHER'],
      );
      expect(
        EmergencyClosedAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(EmergencyClosedAtomPermissions.tab.isAllowed(writeOnly), isFalse);
    });

    test('∪ handoff write: clinical:write alone satisfies handoff helper', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        EmergencyClosedAtomPermissions.handoff.isAllowed(clinical),
        isTrue,
      );
      expect(EmergencyClosedAtomPermissions.write.isAllowed(clinical), isFalse);
    });

    test('subscription strips Closed without scheduling-queue', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
          AppPermissions.emergencyDelete,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(EmergencyClosedAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewEmergencyClosed(noModule), isFalse);
      expect(emergencyAllowedBoardTabs(noModule), isEmpty);
    });

    test('nested cross-module matrix _(n/a)_: ambulance stays under read ∩', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(
        EmergencyClosedAtomPermissions.ambulancePanel.isAllowed(reader),
        isTrue,
      );
      expect(
        EmergencyClosedAtomPermissions.nestedRead.isAllowed(reader),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only Closed: list + print present; write atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      await _pumpClosedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Closed Casey'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text(EmergencyText.closed), findsWidgets);
      expect(find.text(EmergencyText.quickArrival), findsNothing);
      expect(find.textContaining('Record triage'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Closed Casey'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      expect(find.text(EmergencyText.completeTrip), findsNothing);
      expect(find.textContaining('Open in'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Closed still omits Quick arrival and mutation chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
          AppPermissions.emergencyDelete,
        },
      );
      expect(EmergencyClosedAtomPermissions.write.isAllowed(writer), isTrue);
      expect(EmergencyClosedAtomPermissions.delete.isAllowed(writer), isTrue);

      await _pumpClosedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Closed Casey'), findsOneWidget);
      expect(find.text(EmergencyText.quickArrival), findsNothing);

      await tester.tap(find.text('Closed Casey'));
      await tester.pumpAndSettle();

      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'entry ∪ without Closed read ∩ omits Closed (operations:read)',
    (WidgetTester tester) async {
      await _pumpClosedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['OTHER'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
        items: <EmergencyCaseSummary>[_closedCase, _openCase],
      );

      // Ambulance tab may remain via operations:read ∪; Closed must not.
      expect(find.text('Closed Casey'), findsNothing);
      expect(find.text(EmergencyText.closed), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('subscription strip: scheduling-queue missing omits Closed', (
    WidgetTester tester,
  ) async {
    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      ),
    );

    expect(find.byType(AppTabStrip), findsNothing);
    expect(find.text('Closed Casey'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized empty Closed queue state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      ),
      items: const <EmergencyCaseSummary>[],
    );

    expect(find.text('No emergency cases'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text(EmergencyText.quickArrival), findsNothing);
  });

  testWidgets('authorized load error + Try again remains observable', (
    WidgetTester tester,
  ) async {
    var allowSuccess = false;
    when(() => repository.listEmergencyBoard(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final EmergencyBoardQuery query =
          invocation.positionalArguments.single as EmergencyBoardQuery;
      if (!allowSuccess) {
        // Retryable for UI, but keep failing until Try again so bootstrap
        // retries (network) also fail.
        return const Result<AppPage<EmergencyCaseSummary>>.failure(
          AppFailure.network(),
        );
      }
      return Result<AppPage<EmergencyCaseSummary>>.success(
        AppPage<EmergencyCaseSummary>(
          items: const <EmergencyCaseSummary>[_closedCase],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      );
    });
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async => const Result<EmergencyReferenceData>.success(
        EmergencyReferenceData(),
      ),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/emergency?scope=closed',
      routes: <RouteBase>[
        GoRoute(
          path: '/emergency',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: EmergencyWorkspacePage(
                initialQuery: EmergencyWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(permissions: <AppPermission>{AppPermissions.emergencyRead}),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);

    allowSuccess = true;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Closed Casey'), findsOneWidget);
  });

  testWidgets('Closed desktop + mobile viewports keep print reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.emergencyRead},
    );

    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(1440, 900),
    );
    expect(find.text('Closed Casey'), findsOneWidget);
    await tester.tap(find.text('Closed Casey'));
    await tester.pumpAndSettle();
    expect(find.text(EmergencyText.printSummary), findsOneWidget);

    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
    );
    expect(find.textContaining('Closed'), findsWidgets);
    expect(find.byType(AppListTable<EmergencyCaseSummary>), findsOneWidget);
  });

  testWidgets('Closed light + dark themes keep authorized chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.emergencyRead},
    );

    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.light,
    );
    expect(find.text('Closed Casey'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);

    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Closed Casey'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Filters and Settings chrome mount for Closed readers', (
    WidgetTester tester,
  ) async {
    await _pumpClosedTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      ),
    );

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
