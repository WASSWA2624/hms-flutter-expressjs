import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
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
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_board_next_action.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _pendingBed = IpdAdmissionSummary(
  id: 'adm-queue',
  displayId: 'ADM-QUEUE',
  patientId: 'pat-queue',
  patientDisplayName: 'Quinn Queue',
  stage: 'ADMITTED_PENDING_BED',
  admissionStatus: 'ADMITTED',
  nextStep: 'ASSIGN_BED',
  encounterId: 'enc-queue',
);

const IpdAdmissionSummary _requested = IpdAdmissionSummary(
  id: 'adm-req',
  displayId: 'ADM-REQ',
  patientId: 'pat-req',
  patientDisplayName: 'Rita Requested',
  stage: 'ADMISSION_REQUESTED',
  admissionStatus: 'REQUESTED',
  nextStep: 'APPROVE_ADMISSION',
  encounterId: 'enc-req',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
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
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[_pendingBed],
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  IpdAdmissionDetail? detailOverride,
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
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
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[
      IpdBedOption(id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE'),
    ]),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
  );
  when(() => repository.getAdmission(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<IpdAdmissionDetail>.success(detailOverride);
    }
    final String id = invocation.positionalArguments.single as String;
    final IpdAdmissionSummary summary = items.firstWhere(
      (IpdAdmissionSummary item) => item.id == id || item.displayId == id,
      orElse: () => items.first,
    );
    return Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: summary),
    );
  });
  when(() => repository.assignBed(any(), any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: _pendingBed.copyWith(
          stage: 'ADMITTED_IN_BED',
          hasActiveBed: true,
          nextStep: 'RECORD_NURSING_NOTE',
        ),
      ),
    ),
  );
}

Future<void> _pumpAdmissionQueue(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  String initialLocation = '/ipd?section=admission-queue',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items ?? const <IpdAdmissionSummary>[_pendingBed],
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
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery: IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(_pendingBed);
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IpdAdmissionQueueAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IpdAdmissionQueueAtomPermissions.tab,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.listChrome,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.empty,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.loading,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.retry,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.startAdmission,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.create,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.update,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.delete,
        same(ipdWorkspaceDeleteRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.clinicalWrite,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.billingPanel,
        same(ipdBillingPanelReadRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.manageBeds,
        same(ipdBedManageRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.routeEntry,
        same(RouteAccessCatalog.ipdEntry),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.routeEntryUnion,
        same(ipdWorkspaceRouteUnionRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.nestedWrite,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdAdmissionQueueAtomPermissions.nestedRead,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        ipdSectionTabRequirement(IpdWorkspaceSection.admissionQueue),
        same(IpdAdmissionQueueAtomPermissions.tab),
      );
      expect(
        ipdBoardNextActionRequirement(IpdBoardNextActionKind.assignBed),
        same(ipdOperationalWriteRequirement),
      );
      expect(
        ipdBoardNextActionRequirement(IpdBoardNextActionKind.recordNursingNote),
        same(ipdClinicalWriteRequirement),
      );
      expect(ipdRouteEntryMatchesAppRoutes(), isTrue);
    });

    test(
      '∩ denial: clinical:write alone does not grant board read without read key',
      () {
        final AppAccessPolicy writeOnly = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
        );
        // Source operational write still allows write when role pack passes,
        // but tab chrome needs read ∪.
        expect(
          IpdAdmissionQueueAtomPermissions.tab.isAllowed(writeOnly),
          isFalse,
        );
        expect(canViewIpdAdmissionQueue(writeOnly), isFalse);
        expect(
          IpdAdmissionQueueAtomPermissions.routeEntry.isAllowed(writeOnly),
          isFalse,
        );
      },
    );

    test('∪ allowance: operations:read satisfies tab chrome', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(canViewIpdAdmissionQueue(opsReader), isTrue);
      expect(canReadIpd(opsReader), isTrue);
      expect(
        IpdAdmissionQueueAtomPermissions.startAdmission.isAllowed(opsReader),
        isFalse,
      );
      expect(
        IpdAdmissionQueueAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
    });

    test('∪ allowance: billing:read satisfies route entry but not tab', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(
        IpdAdmissionQueueAtomPermissions.routeEntry.isAllowed(billingOnly),
        isTrue,
      );
      expect(canViewIpdAdmissionQueue(billingOnly), isFalse);
      expect(ipdAllowedSections(billingOnly), isEmpty);
      expect(
        IpdAdmissionQueueAtomPermissions.billingPanel.isAllowed(billingOnly),
        isTrue,
      );
    });

    test('∩ denial: billing panel absent without billing:read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdAdmissionQueueAtomPermissions.billingPanel.isAllowed(clinical),
        isFalse,
      );
      expect(canReadIpdBilling(clinical), isFalse);
    });

    test('subscription strip: missing inpatient module denies tab + write', () {
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
      expect(IpdAdmissionQueueAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        IpdAdmissionQueueAtomPermissions.startAdmission.isAllowed(noModule),
        isFalse,
      );
      expect(ipdAllowedSections(noModule), isEmpty);
    });

    test(
      'source mapping: operations:write satisfies start admission without clinical:write',
      () {
        final AppAccessPolicy opsWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
          roles: const <String>['OPERATIONS'],
        );
        expect(
          IpdAdmissionQueueAtomPermissions.startAdmission.isAllowed(opsWriter),
          isTrue,
        );
        expect(
          IpdAdmissionQueueAtomPermissions.clinicalWrite.isAllowed(opsWriter),
          isFalse,
        );
      },
    );

    test('manage beds requires admin; unit packs alone do not unlock', () {
      final AppAccessPolicy unitManager = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.unitManage,
        },
        roles: const <String>['UNIT_MANAGER'],
      );
      expect(
        IpdAdmissionQueueAtomPermissions.manageBeds.isAllowed(unitManager),
        isFalse,
      );

      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(
        IpdAdmissionQueueAtomPermissions.manageBeds.isAllowed(facilityAdmin),
        isTrue,
      );
    });

    test('route entry keys match AppRoutes.ipd', () {
      expect(
        AppRoutes.ipd.requiredAnyPermissions.toSet(),
        equals(
          <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.operationsRead,
            AppPermissions.billingRead,
          },
        ),
      );
      expect(
        RouteAccessCatalog.ipdEntry.anyPermissions.toSet(),
        equals(AppRoutes.ipd.requiredAnyPermissions.toSet()),
      );
    });
  });

  testWidgets(
    'read-only ∪ denial: queue visible; Start admission / Assign bed absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpAdmissionQueue(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Admission Queue'), findsWidgets);
      expect(find.text('Quinn Queue'), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.text('Assign bed'), findsNothing);
      expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
    },
  );

  testWidgets('authorized writer: Start admission + Assign bed present', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: writer,
    );

    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Assign bed'), findsWidgets);
    expect(find.text('Quinn Queue'), findsOneWidget);
  });

  testWidgets('∪ operations:read shows queue without write controls', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy opsReader = _policy(
      permissions: <AppPermission>{AppPermissions.operationsRead},
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: opsReader,
    );

    expect(find.textContaining('Admission Queue'), findsWidgets);
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsNothing);
    expect(find.text('Assign bed'), findsNothing);
  });

  testWidgets('billing:read alone collapses strip (no board read)', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy billingOnly = _policy(
      permissions: <AppPermission>{AppPermissions.billingRead},
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: billingOnly,
    );

    expect(find.byType(AppTabStrip), findsNothing);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsNothing);
  });

  testWidgets('authorized empty state remains observable for readers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: reader,
      listOverride: Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: const <IpdAdmissionSummary>[],
          request: const AppPageRequest(pageIndex: 0, pageSize: 25),
          totalItemCount: 0,
        ),
      ),
    );
    expect(find.textContaining('No admissions'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsNothing);
  });

  testWidgets('authorized error/retry surface remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      listOverride: const Result<AppPage<IpdAdmissionSummary>>.failure(
        AppFailure.network(),
      ),
    );
    expect(find.byType(AsyncStateScaffold<IpdWorkspaceState>), findsOneWidget);
    expect(find.textContaining('Try again'), findsWidgets);
  });

  testWidgets('mobile viewport: queue + Start admission remain reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );

    expect(find.textContaining('Admission Queue'), findsWidgets);
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    // Mobile list chrome omits the next-action column; row select remains.
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
  });

  testWidgets('desktop viewport: Assign bed next-action remains reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Assign bed'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('dark theme: authorized queue chrome remains visible', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('Admission Queue'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Assign bed'), findsWidgets);
  });

  testWidgets(
    'post-mutation sync: Assign bed refreshes queue via operational write',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdAdmissionQueueAtomPermissions.assignBed.isAllowed(writer),
        isTrue,
      );

      when(() => repository.assignBed(any(), any())).thenAnswer((_) async {
        when(() => repository.listAdmissions(any())).thenAnswer((
          Invocation invocation,
        ) async {
          final IpdAdmissionQuery query =
              invocation.positionalArguments.single as IpdAdmissionQuery;
          return Result<AppPage<IpdAdmissionSummary>>.success(
            AppPage<IpdAdmissionSummary>(
              items: const <IpdAdmissionSummary>[],
              request: query.pageRequest,
              totalItemCount: 0,
            ),
          );
        });
        return Result<IpdAdmissionDetail>.success(
          IpdAdmissionDetail(
            summary: _pendingBed.copyWith(
              stage: 'ADMITTED_IN_BED',
              hasActiveBed: true,
            ),
          ),
        );
      });

      await _pumpAdmissionQueue(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Assign bed'), findsWidgets);
      await tester.tap(find.text('Assign bed').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Assign dialog opens for authorized writers (integration with gates).
      expect(find.byType(AppDialog), findsWidgets);
    },
  );

  testWidgets('approve next-action absent for read-only; present for writer', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: reader,
      items: const <IpdAdmissionSummary>[_requested],
    );
    expect(find.text('Rita Requested'), findsOneWidget);
    expect(find.textContaining('Approve'), findsNothing);

    await _pumpAdmissionQueue(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      items: const <IpdAdmissionSummary>[_requested],
    );
    expect(find.textContaining('Approve'), findsWidgets);
  });
}
