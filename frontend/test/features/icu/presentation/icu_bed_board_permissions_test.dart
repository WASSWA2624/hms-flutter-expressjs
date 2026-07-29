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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuBed _availableBed = IcuBed(
  id: 'bed-1',
  label: 'ICU-1',
  status: 'AVAILABLE',
  wardId: 'ward-1',
  wardName: 'ICU Ward',
);

const IcuBed _occupiedBed = IcuBed(
  id: 'bed-2',
  label: 'ICU-2',
  status: 'OCCUPIED',
  wardId: 'ward-1',
  wardName: 'ICU Ward',
  occupantAdmissionId: 'ADM-1',
  occupantDisplayId: 'ADM0001',
  occupantName: 'Ada Occupant',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyRead ||
        permission == AppPermissions.emergencyWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsInpatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.facilityAdmin ||
        permission == AppPermissions.tenantAdmin ||
        permission == AppPermissions.systemAdmin ||
        permission == AppPermissions.unitManage ||
        permission == AppPermissions.roomsBedsRead,
  );

  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'icu-critical-care',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsEmergency)
          const AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        if (needsInpatient)
          const AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockIcuRepository repository, {
  List<IcuBed> beds = const <IcuBed>[_availableBed, _occupiedBed],
  Result<IcuBedBoard>? bedBoardOverride,
  Result<AppPage<IcuPatientSummary>>? boardOverride,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) {
    if (boardOverride != null) {
      return Future<Result<AppPage<IcuPatientSummary>>>.value(boardOverride);
    }
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    return Future<Result<AppPage<IcuPatientSummary>>>.value(
      Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer((_) async {
    if (bedBoardOverride != null) {
      return bedBoardOverride;
    }
    return Result<IcuBedBoard>.success(
      IcuBedBoard(
        wards: const <IcuBedWard>[IcuBedWard(id: 'ward-1', name: 'ICU Ward')],
        beds: beds,
      ),
    );
  });
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => const Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
      ),
    ),
  );
}

Future<void> _pumpBedBoard(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuBed> beds = const <IcuBed>[_availableBed, _occupiedBed],
  Result<IcuBedBoard>? bedBoardOverride,
  Result<AppPage<IcuPatientSummary>>? boardOverride,
}) async {
  _stubRepository(
    repository,
    beds: beds,
    bedBoardOverride: bedBoardOverride,
    boardOverride: boardOverride,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/icu?section=beds',
    routes: <RouteBase>[
      GoRoute(
        path: '/icu',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IcuWorkspacePage(
              initialQuery: IcuBoardQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('IPD workspace'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
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
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
    );
    registerFallbackValue(
      const IcuPatientDetail(
        summary: IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
      ),
    );
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('IcuBedBoardAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IcuBedBoardAtomPermissions.tab,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.wardFilters,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.summaryChips,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.empty,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.write,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.create,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.update,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.delete,
        same(icuWorkspaceDeleteRequirement),
      );
      // Matrix ∩ clinical:write alone — source keeps ∪ clinical|emergency write.
      expect(
        icuWorkspaceWriteRequirement.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        ]),
      );
      expect(
        IcuBedBoardAtomPermissions.openIpd,
        same(icuNavigationRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.manageBeds,
        same(icuBedBoardManageRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.nestedWrite,
        same(icuBedBoardManageRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.nestedRead,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuBedBoardAtomPermissions.routeEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.beds),
        same(IcuBedBoardAtomPermissions.tab),
      );
      expect(
        icuDetailReadRequirement(IcuWorkspaceSection.beds),
        same(IcuBedBoardAtomPermissions.detail),
      );
      expect(
        icuWriteRequirementForSection(IcuWorkspaceSection.beds),
        same(IcuBedBoardAtomPermissions.write),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: write without read strips Bed board tab', () {
      // Matrix create ∩ clinical:write alone is remapped to source write ∪;
      // missing both clinical:read and emergency:read still denies tab chrome.
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        },
      );
      expect(IcuBedBoardAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewIcuBedBoard(writeOnly), isFalse);
      expect(IcuBedBoardAtomPermissions.write.isAllowed(writeOnly), isTrue);
      expect(IcuBedBoardAtomPermissions.success.isAllowed(writeOnly), isTrue);
      expect(
        IcuBedBoardAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
    });

    test('∪ allowance: clinical:read alone shows Bed board', () {
      final AppAccessPolicy clinicalReader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewIcuBedBoard(clinicalReader), isTrue);
      expect(IcuBedBoardAtomPermissions.write.isAllowed(clinicalReader), isFalse);
      expect(
        IcuBedBoardAtomPermissions.create.isAllowed(clinicalReader),
        isFalse,
      );
      expect(
        IcuBedBoardAtomPermissions.manageBeds.isAllowed(clinicalReader),
        isFalse,
      );
    });

    test('∪ allowance: emergency:read alone shows Bed board', () {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewIcuBedBoard(emergencyReader), isTrue);
      expect(
        IcuBedBoardAtomPermissions.openIpd.isAllowed(emergencyReader),
        isTrue,
      );
      expect(
        IcuBedBoardAtomPermissions.write.isAllowed(emergencyReader),
        isFalse,
      );
    });

    test(
      '∪ allowance: operations:read satisfies route entry but not Bed board tab',
      () {
        final AppAccessPolicy opsReader = _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        );
        expect(
          IcuBedBoardAtomPermissions.routeEntry.isAllowed(opsReader),
          isTrue,
        );
        expect(canViewIcuBedBoard(opsReader), isFalse);
        expect(canEnterIcuWorkspace(opsReader), isTrue);
      },
    );

    test('nested cross-module manage absent without rooms-beds admin', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(canViewIcuBedBoard(clinicalWriter), isTrue);
      expect(canManageIcuBedBoard(clinicalWriter), isFalse);
      expect(
        IcuBedBoardAtomPermissions.nestedWrite.isAllowed(clinicalWriter),
        isFalse,
      );
    });

    test('nested cross-module manage ∪: facility:admin + inpatient module', () {
      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canManageIcuBedBoard(facilityAdmin), isTrue);
      expect(
        IcuBedBoardAtomPermissions.nestedWrite.isAllowed(facilityAdmin),
        isTrue,
      );
    });

    test('nested cross-module manage ∪: unit:manage satisfies manageBeds', () {
      final AppAccessPolicy unitManager = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.unitManage,
        },
      );
      expect(canManageIcuBedBoard(unitManager), isTrue);
    });

    test('subscription strip: icu-critical-care required for Bed board tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(IcuBedBoardAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewIcuBedBoard(noModule), isFalse);
      expect(IcuBedBoardAtomPermissions.write.isAllowed(noModule), isFalse);
    });

    test('authorized UI-state atoms map to read / write helpers', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuBedBoardAtomPermissions.loading.isAllowed(reader), isTrue);
      expect(IcuBedBoardAtomPermissions.empty.isAllowed(reader), isTrue);
      expect(IcuBedBoardAtomPermissions.retry.isAllowed(reader), isTrue);
      expect(IcuBedBoardAtomPermissions.success.isAllowed(reader), isFalse);
      expect(IcuBedBoardAtomPermissions.validation.isAllowed(reader), isFalse);

      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IcuBedBoardAtomPermissions.success.isAllowed(writer), isTrue);
      expect(IcuBedBoardAtomPermissions.validation.isAllowed(writer), isTrue);
    });
  });

  testWidgets(
    'read-only: Bed board visible; Open IPD present; no mutate chrome / no access banner',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.byType(IcuBedBoardPanel), findsOneWidget);
      expect(find.textContaining('Bed board'), findsWidgets);
      expect(find.textContaining('All ICU wards'), findsOneWidget);
      expect(find.textContaining('available'), findsOneWidget);
      expect(find.textContaining('occupied'), findsOneWidget);
      expect(find.textContaining('Ada Occupant'), findsOneWidget);
      expect(find.byTooltip('Open in IPD'), findsOneWidget);
      expect(find.byTooltip('Manage beds'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppListTable<IcuPatientSummary>), findsNothing);
    },
  );

  testWidgets(
    '∪ emergency:read alone mounts Bed board and Open IPD',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.byType(IcuBedBoardPanel), findsOneWidget);
      expect(find.byTooltip('Open in IPD'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ denial: write-only policy collapses Bed board tab from strip',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        },
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(IcuBedBoardPanel), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Open in IPD'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip collapses Bed board without icu-critical-care',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(IcuBedBoardPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty state remains observable',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: reader,
        beds: const <IcuBed>[],
      );

      expect(find.text('No ICU beds'), findsOneWidget);
      expect(find.byTooltip('Open in IPD'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable',
    (WidgetTester tester) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        boardOverride: const Result<AppPage<IcuPatientSummary>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  test('post-mutation sync: assignBed reloads bed board', () async {
    const IcuPatientSummary summary = IcuPatientSummary(
      id: 'ADM-1',
      admissionId: 'ADM-1',
      displayId: 'ADM0001',
    );
    const IcuPatientDetail detail = IcuPatientDetail(summary: summary);
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    when(() => repository.listIcuBoard(any())).thenAnswer((invocation) {
      final IcuBoardQuery query =
          invocation.positionalArguments.single as IcuBoardQuery;
      return Future<Result<AppPage<IcuPatientSummary>>>.value(
        Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: const <IcuPatientSummary>[summary],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
        ),
      );
    });
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
    );
    when(() => repository.loadBedBoard()).thenAnswer(
      (_) async => const Result<IcuBedBoard>.success(
        IcuBedBoard(beds: <IcuBed>[_availableBed]),
      ),
    );
    when(() => repository.loadIcuDetail(any())).thenAnswer(
      (_) async => const Result<IcuPatientDetail>.success(detail),
    );
    when(
      () => repository.assignBed(
        detail: any(named: 'detail'),
        bedId: any(named: 'bedId'),
      ),
    ).thenAnswer(
      (_) async => const Result<IcuPatientDetail>.success(
        IcuPatientDetail(
          summary: IcuPatientSummary(
            id: 'ADM-1',
            admissionId: 'ADM-1',
            displayId: 'ADM0001',
            hasActiveBed: true,
            bedLabel: 'ICU-1',
          ),
        ),
      ),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
        appAccessPolicyProvider.overrideWithValue(writer),
      ],
    );
    addTearDown(container.dispose);

    await container.read(icuWorkspaceControllerProvider.future);
    await container
        .read(icuWorkspaceControllerProvider.notifier)
        .selectPatient(summary);
    clearInteractions(repository);
    when(() => repository.loadBedBoard()).thenAnswer(
      (_) async => const Result<IcuBedBoard>.success(
        IcuBedBoard(beds: <IcuBed>[_occupiedBed]),
      ),
    );
    when(
      () => repository.assignBed(
        detail: any(named: 'detail'),
        bedId: any(named: 'bedId'),
      ),
    ).thenAnswer(
      (_) async => const Result<IcuPatientDetail>.success(
        IcuPatientDetail(
          summary: IcuPatientSummary(
            id: 'ADM-1',
            admissionId: 'ADM-1',
            displayId: 'ADM0001',
            hasActiveBed: true,
            bedLabel: 'ICU-1',
          ),
        ),
      ),
    );

    final AppFailure? failure = await container
        .read(icuWorkspaceControllerProvider.notifier)
        .assignBed('bed-1');
    expect(failure, isNull);
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.loadBedBoard()).called(greaterThanOrEqualTo(1));
  });

  testWidgets(
    'mobile viewport: Bed board chips and Open IPD remain reachable',
    (WidgetTester tester) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        viewport: const Size(390, 844),
      );

      expect(find.byType(IcuBedBoardPanel), findsOneWidget);
      expect(find.textContaining('All ICU wards'), findsOneWidget);
      expect(find.byTooltip('Open in IPD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop dark theme: Bed board occupancy chrome remains visible',
    (WidgetTester tester) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        themeMode: ThemeMode.dark,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(IcuBedBoardPanel), findsOneWidget);
      expect(find.textContaining('Ada Occupant'), findsOneWidget);
      expect(find.byTooltip('Open in IPD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Open IPD navigates for authorized reader (integration)',
    (WidgetTester tester) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      await tester.tap(find.byTooltip('Open in IPD'));
      await tester.pumpAndSettle();

      expect(find.text('IPD workspace'), findsOneWidget);
    },
  );
}
