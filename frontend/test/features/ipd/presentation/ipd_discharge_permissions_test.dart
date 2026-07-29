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
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
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

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _dischargePlanned = IpdAdmissionSummary(
  id: 'adm-discharge',
  displayId: 'ADM-DISC',
  patientId: 'pat-disc',
  patientDisplayName: 'Dana Discharge',
  stage: 'DISCHARGE_PLANNED',
  admissionStatus: 'ADMITTED',
  nextStep: 'FINALIZE_DISCHARGE',
  hasActiveBed: true,
  encounterId: 'enc-disc',
  wardDisplayName: 'Medical Ward',
  dischargeStatus: 'PLANNED',
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
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[
    _dischargePlanned,
  ],
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
      IpdAdmissionDetail(
        summary: summary,
        latestDischargeSummary: const IpdDischargeSummary(
          id: 'ds-1',
          status: 'PLANNED',
          summary: 'Ready for clearance.',
        ),
      ),
    );
  });
  when(() => repository.planDischarge(any(), any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: _dischargePlanned,
        latestDischargeSummary: const IpdDischargeSummary(
          id: 'ds-1',
          status: 'PLANNED',
          summary: 'Updated plan.',
        ),
      ),
    ),
  );
}

void _stubDischargeRepository(
  _MockDischargeRepository repository, {
  IpdAdmissionSummary summary = _dischargePlanned,
}) {
  when(() => repository.getAdmissionDetail(any())).thenAnswer(
    (_) async => Result<DischargeAdmissionDetail>.success(
      DischargeAdmissionDetail(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: summary.patientId ?? 'patient-1',
        encounterId: summary.encounterId ?? 'encounter-1',
        ipd: IpdAdmissionDetail(
          summary: summary,
          latestDischargeSummary: const IpdDischargeSummary(
            id: 'ds-1',
            status: 'PLANNED',
            summary: 'Ready for clearance.',
          ),
        ),
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
}

Future<void> _pumpDischargeTab(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  _MockDischargeRepository? dischargeRepository,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  String initialLocation = '/ipd?section=discharge',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items ?? const <IpdAdmissionSummary>[_dischargePlanned],
    listOverride: listOverride,
  );
  final _MockDischargeRepository discharge =
      dischargeRepository ?? _MockDischargeRepository();
  _stubDischargeRepository(discharge);

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
        dischargeRepositoryProvider.overrideWithValue(discharge),
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
    registerFallbackValue(_dischargePlanned);
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IpdDischargeAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IpdDischargeAtomPermissions.tab,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.listChrome,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.empty,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.loading,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.retry,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.startAdmission,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.create,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.update,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.delete,
        same(ipdWorkspaceDeleteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.clinicalWrite,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.nextActionDischarge,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.planDischarge,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.manageDischarge,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.billingPanel,
        same(ipdBillingPanelReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.billingRead,
        same(ipdBillingReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.manageBeds,
        same(ipdBedManageRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.routeEntry,
        same(RouteAccessCatalog.ipdEntry),
      );
      expect(
        IpdDischargeAtomPermissions.nestedWrite,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.nestedRead,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.panelDeepLink,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        ipdBoardTabRequirement(IpdWorkspaceSection.dischargePlanned),
        same(IpdDischargeAtomPermissions.tab),
      );
      expect(
        ipdBoardNextActionRequirement(
          IpdBoardNextActionKind.planOrManageDischarge,
        ),
        same(ipdClinicalWriteRequirement),
      );
      expect(
        ipdFocusedMutationRequirement(panel: IpdDetailPanel.discharge),
        same(ipdClinicalWriteRequirement),
      );
      expect(ipdRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: clinical:write missing hides discharge write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IpdDischargeAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(canViewIpdDischarge(reader), isTrue);
      expect(IpdDischargeAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IpdDischargeAtomPermissions.nextActionDischarge.isAllowed(reader),
        isFalse,
      );
      expect(
        IpdDischargeAtomPermissions.planDischarge.isAllowed(reader),
        isFalse,
      );
      expect(
        IpdDischargeAtomPermissions.manageDischarge.isAllowed(reader),
        isFalse,
      );
      expect(canWriteIpdClinical(reader), isFalse);
    });

    test('∪ allowance: operations:read satisfies Discharge tab chrome', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(canViewIpdDischarge(opsReader), isTrue);
      expect(canReadIpd(opsReader), isTrue);
      expect(
        IpdDischargeAtomPermissions.listChrome.isAllowed(opsReader),
        isTrue,
      );
      expect(
        IpdDischargeAtomPermissions.startAdmission.isAllowed(opsReader),
        isFalse,
      );
      expect(
        IpdDischargeAtomPermissions.nextActionDischarge.isAllowed(opsReader),
        isFalse,
      );
      expect(
        IpdDischargeAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
    });

    test('∪ allowance: billing:read satisfies route entry but not tab', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(
        IpdDischargeAtomPermissions.routeEntry.isAllowed(billingOnly),
        isTrue,
      );
      expect(canViewIpdDischarge(billingOnly), isFalse);
      expect(
        ipdAllowedSections(billingOnly).contains(
          IpdWorkspaceSection.dischargePlanned,
        ),
        isFalse,
      );
      expect(
        IpdDischargeAtomPermissions.billingPanel.isAllowed(billingOnly),
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
        IpdDischargeAtomPermissions.billingPanel.isAllowed(clinical),
        isFalse,
      );
      expect(canReadIpdBilling(clinical), isFalse);
    });

    test('full intersection set: clinical write + module allows discharge', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IpdDischargeAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(IpdDischargeAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        IpdDischargeAtomPermissions.nextActionDischarge.isAllowed(writer),
        isTrue,
      );
      expect(
        IpdDischargeAtomPermissions.startAdmission.isAllowed(writer),
        isTrue,
      );
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
      expect(IpdDischargeAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        IpdDischargeAtomPermissions.nextActionDischarge.isAllowed(noModule),
        isFalse,
      );
      expect(canViewIpdDischarge(noModule), isFalse);
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
          IpdDischargeAtomPermissions.startAdmission.isAllowed(opsWriter),
          isTrue,
        );
        expect(
          IpdDischargeAtomPermissions.releaseBed.isAllowed(opsWriter),
          isTrue,
        );
        expect(
          IpdDischargeAtomPermissions.nextActionDischarge.isAllowed(opsWriter),
          isFalse,
        );
      },
    );

    test('manage beds not unlocked by unit:manage alone (source gate)', () {
      final AppAccessPolicy unitManager = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.unitManage,
        },
        roles: const <String>['UNIT_MANAGER'],
      );
      expect(
        IpdDischargeAtomPermissions.manageBeds.isAllowed(unitManager),
        isFalse,
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
        IpdDischargeAtomPermissions.routeEntry.anyPermissions.toSet(),
        equals(AppRoutes.ipd.requiredAnyPermissions.toSet()),
      );
    });
  });

  testWidgets(
    'read-only ∪: Discharge visible; Start admission / Manage discharge absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpDischargeTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Discharge'), findsWidgets);
      expect(find.text('Dana Discharge'), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.text('Manage discharge'), findsNothing);
      expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
    },
  );

  testWidgets('authorized clinical writer: Start admission + Manage discharge', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpDischargeTab(
      tester,
      repository: repository,
      accessPolicy: writer,
    );

    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Manage discharge'), findsWidgets);
    expect(find.text('Dana Discharge'), findsOneWidget);
  });

  testWidgets('∪ operations:read shows Discharge without clinical write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy opsReader = _policy(
      permissions: <AppPermission>{AppPermissions.operationsRead},
    );
    await _pumpDischargeTab(
      tester,
      repository: repository,
      accessPolicy: opsReader,
    );

    expect(find.textContaining('Discharge'), findsWidgets);
    expect(find.text('Dana Discharge'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsNothing);
    expect(find.text('Manage discharge'), findsNothing);
  });

  testWidgets('billing:read alone collapses strip (no board read)', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy billingOnly = _policy(
      permissions: <AppPermission>{AppPermissions.billingRead},
    );
    await _pumpDischargeTab(
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
    await _pumpDischargeTab(
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
    await _pumpDischargeTab(
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

  testWidgets('mobile viewport: Discharge row + Start admission remain reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpDischargeTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );

    expect(find.textContaining('Discharge'), findsWidgets);
    expect(find.text('Dana Discharge'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    // Mobile list chrome omits the next-action column; row select opens detail.
    await tester.tap(find.text('Dana Discharge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.textContaining('Release bed'),
      ),
      findsWidgets,
    );
  });

  testWidgets('dark theme: authorized Discharge chrome remains visible', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpDischargeTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('Discharge'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Manage discharge'), findsWidgets);
  });

  testWidgets(
    'post-mutation sync: Manage discharge opens planning dialog for writers',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdDischargeAtomPermissions.manageDischarge.isAllowed(writer),
        isTrue,
      );

      await _pumpDischargeTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Manage discharge'), findsWidgets);
      await tester.tap(find.text('Manage discharge').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
    },
  );

  testWidgets(
    'detail Release bed present for writer; Manage discharge omitted from Quick Actions',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpDischargeTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Dana Discharge'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final Finder dialog = find.byType(AppDialog);
      expect(dialog, findsWidgets);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Release bed'),
        ),
        findsWidgets,
      );
      // Stage next-action is omitted from detail Quick Actions (list may still
      // show Manage discharge behind the dialog).
      expect(
        find.descendant(of: dialog, matching: find.text('Manage discharge')),
        findsNothing,
      );
    },
  );
}
