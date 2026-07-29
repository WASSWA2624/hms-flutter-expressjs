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
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
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
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyCaseSummary _activeCase = EmergencyCaseSummary(
  id: 'EME-ACTIVE-1',
  displayId: 'EME-ACTIVE-1',
  patientId: 'PAT-ACTIVE-1',
  patientDisplayId: 'PAT-ACTIVE-1',
  patientDisplayName: 'Active Tab Patient',
  severity: 'HIGH',
  status: 'OPEN',
);

const EmergencyCaseDetail _activeDetail = EmergencyCaseDetail(
  summary: _activeCase,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['NURSE'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockEmergencyRepository repository, {
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_activeCase],
  EmergencyCaseDetail detail = _activeDetail,
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  Result<EmergencyReferenceData>? referenceOverride,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
    if (listOverride != null) {
      return Future<Result<AppPage<EmergencyCaseSummary>>>.value(listOverride);
    }
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Future<Result<AppPage<EmergencyCaseSummary>>>.value(
      Result<AppPage<EmergencyCaseSummary>>.success(
        AppPage<EmergencyCaseSummary>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        referenceOverride ??
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
  when(() => repository.createQuickArrival(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
  when(
    () => repository.recordTriage(
      detail: any(named: 'detail'),
      triageLevel: any(named: 'triageLevel'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer((_) async => Result<EmergencyCaseDetail>.success(detail));
}

Future<void> _pumpActiveTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_activeCase],
  EmergencyCaseDetail detail = _activeDetail,
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  String initialLocation = '/emergency?scope=active',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
    detail: detail,
    listOverride: listOverride,
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
  // Deep-link detail opens in a post-frame + async selectCase path.
  if (initialLocation.contains('id=')) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }
}

void main() {
  late _MockEmergencyRepository repository;

  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(const EmergencyCaseSummary(id: 'fallback'));
    registerFallbackValue(
      const EmergencyQuickArrivalInput(
        firstName: '',
        lastName: '',
        severity: 'HIGH',
      ),
    );
    registerFallbackValue(_activeDetail);
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  test('atom map reuses emergency *Requirement helpers (no second vocabulary)', () {
    expect(
      identical(
        EmergencyActiveCasesAtomPermissions.tab,
        emergencyWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        EmergencyActiveCasesAtomPermissions.quickArrival,
        emergencyWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        EmergencyActiveCasesAtomPermissions.delete,
        emergencyWorkspaceDeleteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        EmergencyActiveCasesAtomPermissions.handoff,
        emergencyHandoffWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        EmergencyActiveCasesAtomPermissions.routeEntry,
        RouteAccessCatalog.emergencyEntry,
      ),
      isTrue,
    );
    expect(
      identical(
        EmergencyAllAtomPermissions.quickArrival,
        EmergencyActiveCasesAtomPermissions.quickArrival,
      ),
      isTrue,
    );
  });

  test('route entry ∪ allows operations:read with scheduling-queue', () {
    final AppAccessPolicy opsEntry = _policy(
      permissions: <AppPermission>{AppPermissions.operationsRead},
      modules: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    );
    expect(
      EmergencyActiveCasesAtomPermissions.routeEntry.isAllowed(opsEntry),
      isTrue,
    );
    expect(
      EmergencyActiveCasesAtomPermissions.tab.isAllowed(opsEntry),
      isFalse,
    );
    expect(canEnterEmergencyWorkspace(opsEntry), isTrue);
    expect(canReadEmergency(opsEntry), isFalse);
  });

  test('subscription strips write when scheduling-queue is absent', () {
    final AppAccessPolicy capped = _policy(
      permissions: <AppPermission>{
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
        AppPermissions.emergencyDelete,
      },
      modules: const <AppModuleEntitlement>[],
    );
    expect(canReadEmergency(capped), isFalse);
    expect(canWriteEmergency(capped), isFalse);
    expect(canDeleteEmergency(capped), isFalse);
    expect(emergencyAllowedBoardTabs(capped), isEmpty);
  });

  testWidgets(
    'read-only ∩ denial: Active list visible; Quick arrival / next-action / writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(EmergencyActiveCasesAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        EmergencyActiveCasesAtomPermissions.quickArrival.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.triage.isAllowed(reader),
        isFalse,
      );
      expect(
        emergencyBoardShowsNextActionColumn(reader, EmergencyBoardTab.active),
        isFalse,
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Active Tab Patient'), findsOneWidget);
      expect(find.text(EmergencyText.activeCases), findsWidgets);
      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Triage'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'read-only ∩ denial: detail panel omits write actions',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(reader),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmergencyDetailPanel(
                state: EmergencyWorkspaceState(
                  query: const EmergencyBoardQuery(),
                  board: AppPage<EmergencyCaseSummary>(
                    items: const <EmergencyCaseSummary>[_activeCase],
                    request: const AppPageRequest(pageSize: 20),
                    totalItemCount: 1,
                  ),
                  selectedDetail: _activeDetail,
                ),
                writeRequirement: emergencyWriteRequirement,
                isDialog: true,
                omitNextActionKind: EmergencyNextActionKind.triage,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Tab Patient'), findsOneWidget);
      expect(find.text('Priority'), findsNothing);
      expect(find.text('Triage'), findsNothing);
      expect(find.text('Response'), findsNothing);
      expect(find.text('Dispatch'), findsNothing);
      expect(find.text('Handoff'), findsNothing);
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Quick arrival, Triage next-action, and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(
        EmergencyActiveCasesAtomPermissions.quickArrival.isAllowed(writer),
        isTrue,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.triage.isAllowed(writer),
        isTrue,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        emergencyBoardShowsNextActionColumn(writer, EmergencyBoardTab.active),
        isTrue,
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Active Tab Patient'), findsOneWidget);
      expect(find.text('Quick arrival'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );
      expect(find.text('Triage'), findsWidgets);
    },
  );

  testWidgets(
    'full write ∩: detail panel mounts complementary writes',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(writer),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmergencyDetailPanel(
                state: EmergencyWorkspaceState(
                  query: const EmergencyBoardQuery(),
                  board: AppPage<EmergencyCaseSummary>(
                    items: const <EmergencyCaseSummary>[_activeCase],
                    request: const AppPageRequest(pageSize: 20),
                    totalItemCount: 1,
                  ),
                  selectedDetail: _activeDetail,
                ),
                writeRequirement: emergencyWriteRequirement,
                isDialog: true,
                omitNextActionKind: EmergencyNextActionKind.triage,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Tab Patient'), findsOneWidget);
      expect(find.text('Priority'), findsWidgets);
      expect(find.text('Response'), findsWidgets);
      expect(find.text('Dispatch'), findsWidgets);
      expect(find.text('Handoff'), findsWidgets);
      expect(find.text(EmergencyText.scheduleTheater), findsOneWidget);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Triage'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'handoff ∪ allowance: clinical:write shows next-action column without emergency:write',
    (WidgetTester tester) async {
      final AppAccessPolicy clinicalHandoff = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.clinicalWrite,
        },
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
        EmergencyActiveCasesAtomPermissions.handoff.isAllowed(clinicalHandoff),
        isTrue,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.quickArrival.isAllowed(
          clinicalHandoff,
        ),
        isFalse,
      );
      expect(
        EmergencyActiveCasesAtomPermissions.triage.isAllowed(clinicalHandoff),
        isFalse,
      );
      expect(
        emergencyBoardShowsNextActionColumn(
          clinicalHandoff,
          EmergencyBoardTab.active,
        ),
        isTrue,
      );

      const EmergencyCaseSummary readyForHandoff = EmergencyCaseSummary(
        id: 'EME-HANDOFF-1',
        displayId: 'EME-HANDOFF-1',
        patientDisplayName: 'Handoff Ready Patient',
        severity: 'MEDIUM',
        status: 'OPEN',
        latestTriage: EmergencyTriageAssessment(
          id: 't1',
          triageLevel: 'LEVEL_2',
        ),
        latestResponse: EmergencyResponseRecord(id: 'r1'),
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: clinicalHandoff,
        items: const <EmergencyCaseSummary>[readyForHandoff],
        detail: const EmergencyCaseDetail(summary: readyForHandoff),
      );

      expect(find.text('Handoff Ready Patient'), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );
      expect(find.text('Record handoff'), findsOneWidget);
      expect(find.text('Triage'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty state remains observable for readers',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        items: const <EmergencyCaseSummary>[],
      );
      expect(find.text('No emergency cases'), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.byType(AppSearchBar), findsOneWidget);
    },
  );

  testWidgets(
    'post-mutation sync: Quick arrival patches Active board',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        items: const <EmergencyCaseSummary>[],
      );

      expect(find.text('No emergency cases'), findsOneWidget);
      expect(find.text('Quick arrival'), findsOneWidget);

      await tester.tap(find.text('Quick arrival'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Active');
      await tester.enterText(find.byType(TextFormField).at(1), 'Patient');
      await tester.tap(find.text('Open case'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Active Tab Patient'), findsOneWidget);
      expect(find.text('Arrival opened'), findsOneWidget);
      verify(() => repository.createQuickArrival(any())).called(1);
    },
  );

  testWidgets('mobile + dark: read-only chrome hides write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.emergencyRead},
    );

    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(find.text(EmergencyText.activeCases), findsWidgets);
    expect(find.text('Quick arrival'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
    expect(find.byType(AppSearchBar), findsOneWidget);
  });

  testWidgets('desktop + light: write ∩ mounts Quick arrival', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      },
    );

    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.text('Active Tab Patient'), findsOneWidget);
  });
}
