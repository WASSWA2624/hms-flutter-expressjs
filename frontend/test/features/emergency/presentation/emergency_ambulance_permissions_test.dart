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
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
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

const EmergencyAmbulanceDispatch _dispatch = EmergencyAmbulanceDispatch(
  id: 'ADS-AMB-1',
  displayId: 'ADS-AMB-1',
  emergencyCaseId: 'EME-AMB-1',
  ambulanceId: 'AMB-1',
  ambulanceDisplayId: 'AMB-1',
  ambulanceLabel: 'Ambulance 1',
  status: 'DISPATCHED',
);

const EmergencyCaseSummary _ambulanceCase = EmergencyCaseSummary(
  id: 'EME-AMB-1',
  displayId: 'EME-AMB-1',
  patientId: 'PAT-AMB-1',
  patientDisplayId: 'PAT-AMB-1',
  patientDisplayName: 'Ambulance Tab Patient',
  severity: 'HIGH',
  status: 'OPEN',
  latestTriage: EmergencyTriageAssessment(
    id: 'TRA-AMB-1',
    triageLevel: 'LEVEL_2',
  ),
  latestResponse: EmergencyResponseRecord(id: 'ERS-AMB-1'),
  latestDispatch: _dispatch,
);

const EmergencyCaseDetail _ambulanceDetail = EmergencyCaseDetail(
  summary: _ambulanceCase,
  triageAssessments: <EmergencyTriageAssessment>[
    EmergencyTriageAssessment(id: 'TRA-AMB-1', triageLevel: 'LEVEL_2'),
  ],
  responses: <EmergencyResponseRecord>[
    EmergencyResponseRecord(id: 'ERS-AMB-1'),
  ],
  dispatches: <EmergencyAmbulanceDispatch>[_dispatch],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  String? tenantId = 'tenant-1',
}) {
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsPatient = permissions.contains(AppPermissions.patientWrite);
  final bool needsClinical = permissions.contains(AppPermissions.clinicalWrite);
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'scheduling-queue',
          licenseStatus: 'ACTIVE',
        ),
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        if (needsPatient)
          const AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['AMBULANCE_OPERATOR'],
        tenantId: tenantId,
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockEmergencyRepository repository, {
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _ambulanceCase,
  ],
  EmergencyCaseDetail detail = _ambulanceDetail,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
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
    (_) async => const Result<EmergencyReferenceData>.success(
      EmergencyReferenceData(
        ambulances: <EmergencyAmbulance>[
          EmergencyAmbulance(
            id: 'AMB-1',
            displayId: 'AMB-1',
            identifier: 'Ambulance 1',
            status: 'AVAILABLE',
          ),
        ],
      ),
    ),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
  when(() => repository.createQuickArrival(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
  when(
    () => repository.startAmbulanceTrip(
      detail: any(named: 'detail'),
      ambulanceId: any(named: 'ambulanceId'),
    ),
  ).thenAnswer((_) async => Result<EmergencyCaseDetail>.success(detail));
}

Future<void> _pumpAmbulanceTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _ambulanceCase,
  ],
  EmergencyCaseDetail detail = _ambulanceDetail,
  String initialLocation = '/emergency?scope=ambulance',
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (listOverride != null) {
    when(() => repository.listEmergencyBoard(any())).thenAnswer(
      (_) async => listOverride,
    );
  } else {
    _stubRepository(repository, items: items, detail: detail);
  }

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
    registerFallbackValue(
      const EmergencyQuickArrivalInput(
        firstName: '',
        lastName: '',
        severity: 'CRITICAL',
      ),
    );
    registerFallbackValue(_ambulanceDetail);
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('EmergencyAmbulanceAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        EmergencyAmbulanceAtomPermissions.tab,
        same(emergencyAmbulanceTabRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.listChrome,
        same(emergencyAmbulanceTabRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.write,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.quickArrival,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.nextAction,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.dispatch,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.startTrip,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.delete,
        same(emergencyWorkspaceDeleteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.handoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.nextActionHandoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.printSummary,
        same(emergencyAmbulanceTabRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.openReceivingModule,
        same(emergencyAmbulanceTabRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.openInReceivingModule,
        same(emergencyAmbulanceTabRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.routeEntry,
        same(emergencyWorkspaceEntryRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.routeEntry,
        same(RouteAccessCatalog.emergencyEntry),
      );
      expect(
        emergencyBoardTabRequirement(EmergencyBoardTab.ambulance),
        same(EmergencyAmbulanceAtomPermissions.tab),
      );
      expect(
        emergencyDetailReadRequirement(EmergencyBoardTab.ambulance),
        same(EmergencyAmbulanceAtomPermissions.detail),
      );
    });

    test('∩ denial: write alone fails Ambulance tab; delete denied to writers', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
      );
      expect(canViewEmergencyAmbulance(writeOnly), isFalse);
      expect(EmergencyAmbulanceAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        EmergencyAmbulanceAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        EmergencyAmbulanceAtomPermissions.delete.isAllowed(writeOnly),
        isFalse,
      );

      final AppAccessPolicy readerWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(
        EmergencyAmbulanceAtomPermissions.delete.isAllowed(readerWriter),
        isFalse,
      );
      expect(canDeleteEmergency(readerWriter), isFalse);
    });

    test('∪ allowance: operations:read alone shows Ambulance tab', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(canViewEmergencyAmbulance(opsReader), isTrue);
      expect(EmergencyAmbulanceAtomPermissions.tab.isAllowed(opsReader), isTrue);
      expect(
        EmergencyAmbulanceAtomPermissions.printSummary.isAllowed(opsReader),
        isTrue,
      );
      expect(
        EmergencyAmbulanceAtomPermissions.detail.isAllowed(opsReader),
        isTrue,
      );
      expect(canOpenEmergencyCaseDetail(opsReader), isTrue);
      expect(
        EmergencyAmbulanceAtomPermissions.write.isAllowed(opsReader),
        isFalse,
      );
      expect(
        EmergencyAmbulanceAtomPermissions.quickArrival.isAllowed(opsReader),
        isFalse,
      );
      expect(canViewEmergencyTab(opsReader, EmergencyBoardTab.active), isFalse);
      expect(canViewEmergencyTab(opsReader, EmergencyBoardTab.all), isFalse);
      expect(
        emergencyAllowedBoardTabs(opsReader),
        <EmergencyBoardTab>[EmergencyBoardTab.ambulance],
      );
    });

    test('∪ allowance: emergency:read alone shows Ambulance among board tabs', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewEmergencyAmbulance(reader), isTrue);
      expect(canViewEmergencyTab(reader, EmergencyBoardTab.active), isTrue);
      expect(
        EmergencyAmbulanceAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
    });

    test('subscription strip: scheduling-queue missing denies Ambulance tab', () {
      final AppAccessPolicy stripped = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.operationsRead,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(canViewEmergencyAmbulance(stripped), isFalse);
      expect(emergencyAllowedBoardTabs(stripped), isEmpty);
      expect(canOpenEmergencyCaseDetail(stripped), isFalse);
    });

    test('ABAC: tenant context required for Ambulance atoms', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
          AppPermissions.operationsRead,
        },
        tenantId: null,
      );
      expect(EmergencyAmbulanceAtomPermissions.tab.isAllowed(noTenant), isFalse);
      expect(
        EmergencyAmbulanceAtomPermissions.write.isAllowed(noTenant),
        isFalse,
      );
      expect(canOpenEmergencyCaseDetail(noTenant), isFalse);
    });

    test('nested cross-module matrix rows are n/a (aliases keep emergency gates)', () {
      expect(
        EmergencyAmbulanceAtomPermissions.nestedRead,
        same(emergencyAmbulanceTabRequirement),
      );
      expect(
        EmergencyAmbulanceAtomPermissions.nestedWrite,
        same(emergencyWorkspaceWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only emergency:read: Ambulance list visible; writes absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpAmbulanceTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Ambulance Tab Patient'), findsOneWidget);
      expect(find.text(EmergencyText.ambulance), findsWidgets);
      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Start trip'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.ensureVisible(find.text('Ambulance Tab Patient'));
      await tester.tap(find.text('Ambulance Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY CASE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Priority'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Dispatch'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start trip'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Handoff'),
        ),
        findsNothing,
      );
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Quick arrival, Start trip next-action, detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(
        EmergencyAmbulanceAtomPermissions.quickArrival.isAllowed(writer),
        isTrue,
      );
      expect(
        EmergencyAmbulanceAtomPermissions.startTrip.isAllowed(writer),
        isTrue,
      );
      expect(
        emergencyBoardShowsNextActionColumn(
          writer,
          EmergencyBoardTab.ambulance,
        ),
        isTrue,
      );

      await _pumpAmbulanceTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Ambulance Tab Patient'), findsOneWidget);
      expect(find.text('Quick arrival'), findsOneWidget);
      expect(find.text('Start trip'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Ambulance Tab Patient'));
      await tester.tap(find.text('Ambulance Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY CASE'), findsOneWidget);
      expect(find.text('Priority'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start trip'),
        ),
        findsNothing,
      );
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ operations:read alone: Ambulance chrome mounts; other tabs and writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        EmergencyAmbulanceAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );

      await _pumpAmbulanceTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      expect(strip.tabs.length, 1);
      expect(strip.tabs.single.label, EmergencyText.ambulance);
      expect(find.text('Ambulance Tab Patient'), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.text('Start trip'), findsNothing);
      expect(find.text(EmergencyText.activeCases), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.ensureVisible(find.text('Ambulance Tab Patient'));
      await tester.tap(find.text('Ambulance Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY CASE'), findsOneWidget);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start trip'),
        ),
        findsNothing,
      );
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: missing scheduling-queue omits Ambulance chrome',
    (WidgetTester tester) async {
      await _pumpAmbulanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Ambulance Tab Patient'), findsNothing);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty state remains observable', (
    WidgetTester tester,
  ) async {
    when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
      final EmergencyBoardQuery query =
          invocation.positionalArguments.single as EmergencyBoardQuery;
      return Future<Result<AppPage<EmergencyCaseSummary>>>.value(
        Result<AppPage<EmergencyCaseSummary>>.success(
          AppPage<EmergencyCaseSummary>(
            items: const <EmergencyCaseSummary>[],
            request: query.pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
    });
    when(repository.loadReferenceData).thenAnswer(
      (_) async =>
          const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
    );

    await _pumpAmbulanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      items: const <EmergencyCaseSummary>[],
    );

    expect(find.text('No emergency cases'), findsOneWidget);
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'authorized error/retry surface remains observable on Ambulance',
    (WidgetTester tester) async {
      await _pumpAmbulanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        ),
        listOverride: const Result<AppPage<EmergencyCaseSummary>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('desktop viewport keeps authorized Ambulance chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAmbulanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Ambulance Tab Patient'), findsOneWidget);
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('mobile viewport keeps authorized Ambulance chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAmbulanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text(EmergencyText.ambulance), findsWidgets);
    // Narrow toolbars may hide the Quick arrival label and keep the icon.
    expect(
      find.byIcon(Icons.add_circle_outline),
      findsWidgets,
    );
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('dark theme keeps authorized Ambulance chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAmbulanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Ambulance Tab Patient'), findsOneWidget);
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('light theme keeps authorized Ambulance chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAmbulanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Ambulance Tab Patient'), findsOneWidget);
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  test(
    'post-mutation sync: startAmbulanceTrip patches board via controller',
    () async {
      _stubRepository(repository);
      var started = false;
      when(
        () => repository.startAmbulanceTrip(
          detail: any(named: 'detail'),
          ambulanceId: any(named: 'ambulanceId'),
        ),
      ).thenAnswer((_) async {
        started = true;
        return Result<EmergencyCaseDetail>.success(_ambulanceDetail);
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [
          emergencyRepositoryProvider.overrideWithValue(repository),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.emergencyRead,
                AppPermissions.emergencyWrite,
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(emergencyWorkspaceControllerProvider.future);
      await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .selectCase(_ambulanceCase);

      final AppFailure? failure = await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .startAmbulanceTrip(ambulanceId: 'AMB-1');

      expect(failure, isNull);
      expect(started, isTrue);
      final EmergencyWorkspaceState state = container
          .read(emergencyWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (EmergencyWorkspaceState value) => value,
            failure: (AppFailure err) => throw StateError(err.code),
          );
      expect(
        state.board.items.any(
          (EmergencyCaseSummary item) => item.id == 'EME-AMB-1',
        ),
        isTrue,
      );
      expect(state.isSaving, isFalse);
    },
  );

  testWidgets(
    '∪ handoff: patient:write satisfies handoff without emergency:write',
    (WidgetTester tester) async {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        EmergencyAmbulanceAtomPermissions.handoff.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        EmergencyAmbulanceAtomPermissions.quickArrival.isAllowed(patientWriter),
        isFalse,
      );
      expect(canShowEmergencyNextAction(patientWriter), isTrue);

      await _pumpAmbulanceTab(
        tester,
        repository: repository,
        accessPolicy: patientWriter,
      );

      expect(find.text('Quick arrival'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
