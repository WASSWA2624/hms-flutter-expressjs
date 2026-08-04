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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_bed_board_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdBedBoardEntry _availableBed = IpdBedBoardEntry(
  id: 'bed-1',
  label: 'Bed 101',
  status: 'AVAILABLE',
  wardName: 'Medical Ward',
);

const IpdBedBoardEntry _occupiedBed = IpdBedBoardEntry(
  id: 'bed-2',
  label: 'Bed 102',
  status: 'OCCUPIED',
  wardName: 'Medical Ward',
  occupantPatientName: 'Ada Occupant',
  occupantAdmissionId: 'adm-active',
  occupantAdmissionDisplayId: 'ADM-ACTIVE',
);

const IpdAdmissionSummary _activeAdmission = IpdAdmissionSummary(
  id: 'adm-active',
  displayId: 'ADM-ACTIVE',
  patientId: 'pat-active',
  patientDisplayName: 'Ada Occupant',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
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
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  final bool needsInpatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.facilityAdmin ||
        permission == AppPermissions.tenantAdmin ||
        permission == AppPermissions.systemAdmin ||
        permission == AppPermissions.unitManage,
  );

  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        if (needsBilling)
          const AppModuleEntitlement(
            code: 'billing-payments',
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
  _MockIpdRepository repository, {
  List<IpdBedBoardEntry> beds = const <IpdBedBoardEntry>[
    _availableBed,
    _occupiedBed,
  ],
  Result<List<IpdBedBoardEntry>>? bedBoardOverride,
  Result<AppPage<IpdAdmissionSummary>>? admissionsOverride,
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((invocation) {
    if (admissionsOverride != null) {
      return Future<Result<AppPage<IpdAdmissionSummary>>>.value(
        admissionsOverride,
      );
    }
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Future<Result<AppPage<IpdAdmissionSummary>>>.value(
      Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: const <IpdAdmissionSummary>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
  });
  when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[
      IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
    ]),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async {
    if (bedBoardOverride != null) {
      return bedBoardOverride;
    }
    return Result<List<IpdBedBoardEntry>>.success(beds);
  });
  when(() => repository.getAdmission(any())).thenAnswer(
    (_) async => const Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: _activeAdmission),
    ),
  );
  when(
    () => repository.updateBedStatus(
      bedId: any(named: 'bedId'),
      status: any(named: 'status'),
    ),
  ).thenAnswer((_) async => const Result<void>.success(null));
}

Future<void> _pumpBedBoard(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdBedBoardEntry> beds = const <IpdBedBoardEntry>[
    _availableBed,
    _occupiedBed,
  ],
  Result<List<IpdBedBoardEntry>>? bedBoardOverride,
  Result<AppPage<IpdAdmissionSummary>>? admissionsOverride,
}) async {
  _stubRepository(
    repository,
    beds: beds,
    bedBoardOverride: bedBoardOverride,
    admissionsOverride: admissionsOverride,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/ipd?section=bed-board',
    routes: <RouteBase>[
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery: IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/rooms-beds',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Rooms & beds'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ipdRepositoryProvider.overrideWithValue(repository),
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
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IpdBedBoardAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(IpdBedBoardAtomPermissions.tab, same(ipdWorkspaceReadRequirement));
      expect(
        IpdBedBoardAtomPermissions.listChrome,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.startAdmission,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.create,
        same(ipdOperationalWriteRequirement),
      );
      // Matrix ∩ clinical:write alone — source keeps operational ∪.
      expect(
        ipdOperationalWriteRequirement.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.clinicalWrite,
          AppPermissions.operationsWrite,
        ]),
      );
      expect(
        IpdBedBoardAtomPermissions.manageBeds,
        same(ipdBedManageRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.nextAction,
        same(ipdBedManageRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.nestedWrite,
        same(ipdBedManageRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.nestedRead,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.billingPanel,
        same(ipdBillingPanelReadRequirement),
      );
      expect(
        IpdBedBoardAtomPermissions.routeEntry,
        same(RouteAccessCatalog.ipdEntry),
      );
      expect(
        ipdBoardTabRequirement(IpdWorkspaceSection.bedBoard),
        same(IpdBedBoardAtomPermissions.tab),
      );
      expect(ipdRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: write without read strips Bed board tab', () {
      // Matrix create ∩ clinical:write is remapped to source operational ∪;
      // missing clinical:read and operations:read still denies tab chrome.
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.operationsWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(IpdBedBoardAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewIpdBedBoard(writeOnly), isFalse);
      expect(IpdBedBoardAtomPermissions.write.isAllowed(writeOnly), isTrue);
      expect(IpdBedBoardAtomPermissions.success.isAllowed(writeOnly), isTrue);
      expect(
        IpdBedBoardAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
    });

    test('∪ allowance: clinical:read alone shows Bed board', () {
      final AppAccessPolicy clinicalReader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewIpdBedBoard(clinicalReader), isTrue);
      expect(
        IpdBedBoardAtomPermissions.write.isAllowed(clinicalReader),
        isFalse,
      );
      expect(
        IpdBedBoardAtomPermissions.startAdmission.isAllowed(clinicalReader),
        isFalse,
      );
      expect(
        IpdBedBoardAtomPermissions.manageBeds.isAllowed(clinicalReader),
        isFalse,
      );
    });

    test('∪ allowance: operations:read alone shows Bed board', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(canViewIpdBedBoard(opsReader), isTrue);
      expect(IpdBedBoardAtomPermissions.write.isAllowed(opsReader), isFalse);
      expect(IpdBedBoardAtomPermissions.manageBeds.isAllowed(opsReader), isFalse);
    });

    test(
      '∪ allowance: billing:read satisfies route entry but not Bed board tab',
      () {
        final AppAccessPolicy billingReader = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        );
        expect(
          IpdBedBoardAtomPermissions.routeEntry.isAllowed(billingReader),
          isTrue,
        );
        expect(canViewIpdBedBoard(billingReader), isFalse);
        expect(canEnterIpdWorkspace(billingReader), isTrue);
      },
    );

    test('nested cross-module manage absent without rooms-beds admin', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(canViewIpdBedBoard(clinicalWriter), isTrue);
      expect(canManageIpdBeds(clinicalWriter), isFalse);
      expect(
        IpdBedBoardAtomPermissions.nestedWrite.isAllowed(clinicalWriter),
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
      expect(canManageIpdBeds(facilityAdmin), isTrue);
      expect(
        IpdBedBoardAtomPermissions.nestedWrite.isAllowed(facilityAdmin),
        isTrue,
      );
    });

    test(
      'nested matrix unit:manage alone does not unlock manage (keep source)',
      () {
        final AppAccessPolicy unitOnly = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.unitManage,
          },
        );
        expect(canViewIpdBedBoard(unitOnly), isTrue);
        expect(canManageIpdBeds(unitOnly), isFalse);
      },
    );

    test('subscription strip: inpatient-bed-management required for tab', () {
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
      expect(IpdBedBoardAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewIpdBedBoard(noModule), isFalse);
      expect(IpdBedBoardAtomPermissions.write.isAllowed(noModule), isFalse);
    });

    test(
      'subscription/ABAC strip: manageBeds needs inpatient module even with admin',
      () {
        final AppAccessPolicy adminNoInpatient = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.facilityAdmin,
          },
          roles: const <String>['FACILITY_ADMIN'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(canViewIpdBedBoard(adminNoInpatient), isFalse);
        expect(canManageIpdBeds(adminNoInpatient), isFalse);

        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          facilityId: null,
        );
        expect(canViewIpdBedBoard(noFacility), isTrue);
      },
    );

    test('billing panel ∩ billing:read; absent without billing module', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        IpdBedBoardAtomPermissions.billingPanel.isAllowed(clinicalOnly),
        isFalse,
      );

      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.billingRead,
        },
      );
      expect(
        IpdBedBoardAtomPermissions.billingPanel.isAllowed(withBilling),
        isTrue,
      );
    });

    test('authorized UI-state atoms map to read / write helpers', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IpdBedBoardAtomPermissions.loading.isAllowed(reader), isTrue);
      expect(IpdBedBoardAtomPermissions.empty.isAllowed(reader), isTrue);
      expect(IpdBedBoardAtomPermissions.retry.isAllowed(reader), isTrue);
      expect(IpdBedBoardAtomPermissions.success.isAllowed(reader), isFalse);
      expect(IpdBedBoardAtomPermissions.validation.isAllowed(reader), isFalse);

      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(IpdBedBoardAtomPermissions.success.isAllowed(writer), isTrue);
      expect(IpdBedBoardAtomPermissions.validation.isAllowed(writer), isTrue);
    });
  });

  testWidgets(
    'read-only: Bed board visible; no Start admission / Manage beds / next-action',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.byType(IpdBedBoardPanel), findsOneWidget);
      expect(find.textContaining('Bed board'), findsWidgets);
      expect(find.textContaining('Ada Occupant'), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.byTooltip('Manage beds'), findsNothing);
      expect(find.text('Next action'), findsNothing);
      expect(find.textContaining('Reserve bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ operations:read mounts Bed board; mutate chrome absent',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.byType(IpdBedBoardPanel), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.byTooltip('Manage beds'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'writer: Start admission present; Manage beds / next-action absent',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byType(IpdBedBoardPanel), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsOneWidget);
      expect(find.byTooltip('Manage beds'), findsNothing);
      expect(find.text('Next action'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested manage ∪: facility admin mounts Manage beds and navigates',
    (WidgetTester tester) async {
      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: facilityAdmin,
      );

      expect(find.byTooltip('Manage beds'), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsOneWidget);
      expect(find.text('Next action'), findsOneWidget);
      expect(find.textContaining('Reserve bed'), findsOneWidget);

      await tester.tap(find.byTooltip('Manage beds'));
      await tester.pumpAndSettle();
      expect(find.text('Rooms & beds'), findsOneWidget);
    },
  );

  testWidgets(
    '∩ denial: write-only policy collapses workspace (no Bed board chrome)',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.operationsWrite,
        },
        roles: const <String>['DOCTOR'],
      );

      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(IpdBedBoardPanel), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip collapses Bed board without inpatient module',
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
      expect(find.byType(IpdBedBoardPanel), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty state remains observable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpBedBoard(
      tester,
      repository: repository,
      accessPolicy: reader,
      beds: const <IpdBedBoardEntry>[],
    );

    expect(find.text('No beds match'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized error/retry surface remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpBedBoard(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
      admissionsOverride: const Result<AppPage<IpdAdmissionSummary>>.failure(
        AppFailure.network(),
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  test('post-mutation sync: updateBedStatus reloads bed board', () async {
    final AppAccessPolicy manager = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.facilityAdmin,
      },
      roles: const <String>['FACILITY_ADMIN'],
    );
    expect(canManageIpdBeds(manager), isTrue);

    _stubRepository(repository);
    when(
      () => repository.updateBedStatus(
        bedId: any(named: 'bedId'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => const Result<void>.success(null));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        ipdRepositoryProvider.overrideWithValue(repository),
        appAccessPolicyProvider.overrideWithValue(manager),
      ],
    );
    addTearDown(container.dispose);

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );
    await controller.loadBedBoard(force: true);
    clearInteractions(repository);
    _stubRepository(repository);
    when(
      () => repository.updateBedStatus(
        bedId: any(named: 'bedId'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => const Result<void>.success(null));

    final AppFailure? failure = await controller.updateBedStatus(
      _availableBed,
      'RESERVED',
    );
    expect(failure, isNull);
    verify(
      () => repository.updateBedStatus(bedId: 'bed-1', status: 'RESERVED'),
    ).called(1);
    verify(
      () => repository.listBedBoard(
        wardId: any(named: 'wardId'),
        status: any(named: 'status'),
        statusAny: any(named: 'statusAny'),
        limit: any(named: 'limit'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('occupied row select opens admission detail (authorized read)', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpBedBoard(
      tester,
      repository: repository,
      accessPolicy: reader,
    );

    await tester.tap(find.text('Ada Occupant'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('ADMISSION DETAIL'), findsOneWidget);
    verify(() => repository.getAdmission('adm-active')).called(1);
  });

  testWidgets('mobile viewport keeps Bed board chrome reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      roles: const <String>['DOCTOR'],
    );

    await _pumpBedBoard(
      tester,
      repository: repository,
      accessPolicy: writer,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(IpdBedBoardPanel), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('desktop viewport + dark theme keeps Bed board authorized', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy facilityAdmin = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.facilityAdmin,
      },
      roles: const <String>['FACILITY_ADMIN'],
    );

    await _pumpBedBoard(
      tester,
      repository: repository,
      accessPolicy: facilityAdmin,
      viewport: const Size(1440, 900),
      themeMode: ThemeMode.dark,
    );

    expect(find.byType(IpdBedBoardPanel), findsOneWidget);
    expect(find.byTooltip('Manage beds'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });
}
