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

const IpdAdmissionSummary _transferPending = IpdAdmissionSummary(
  id: 'adm-transfer',
  displayId: 'ADM-XFER',
  patientId: 'pat-xfer',
  patientDisplayName: 'Terry Transfer',
  stage: 'TRANSFER_REQUESTED',
  admissionStatus: 'ADMITTED',
  nextStep: 'APPROVE_TRANSFER',
  hasActiveBed: true,
  openTransferRequestId: 'tr-1',
  encounterId: 'enc-xfer',
  wardDisplayName: 'Medical Ward',
  bedDisplayLabel: 'Bed 101',
  transferStatus: 'REQUESTED',
);

const IpdTransferRequest _openTransfer = IpdTransferRequest(
  id: 'tr-1',
  status: 'REQUESTED',
  fromWard: IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
  toWard: IpdWardOption(id: 'ward-2', name: 'Surgical Ward'),
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
    _transferPending,
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
  when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[
      IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
      IpdWardOption(id: 'ward-2', name: 'Surgical Ward'),
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
      IpdBedOption(id: 'bed-1', label: 'Bed 101', status: 'OCCUPIED'),
      IpdBedOption(
        id: 'bed-2',
        label: 'Bed 201',
        status: 'AVAILABLE',
        wardId: 'ward-2',
        wardName: 'Surgical Ward',
      ),
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
        openTransferRequest: _openTransfer,
        transferRequests: const <IpdTransferRequest>[_openTransfer],
        activeBedAssignment: const IpdBedAssignment(
          id: 'ba-1',
          bed: IpdBedOption(
            id: 'bed-1',
            label: 'Bed 101',
            wardId: 'ward-1',
            wardName: 'Medical Ward',
          ),
        ),
      ),
    );
  });
  when(() => repository.updateTransfer(any(), any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: _transferPending.copyWith(
          stage: 'TRANSFER_IN_PROGRESS',
          nextStep: 'COMPLETE_TRANSFER',
          transferStatus: 'IN_PROGRESS',
        ),
        openTransferRequest: const IpdTransferRequest(
          id: 'tr-1',
          status: 'IN_PROGRESS',
        ),
      ),
    ),
  );
}

Future<void> _pumpTransfersTab(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  String initialLocation = '/ipd?section=transfers',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items ?? const <IpdAdmissionSummary>[_transferPending],
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
    registerFallbackValue(_transferPending);
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IpdTransfersAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IpdTransfersAtomPermissions.tab,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.listChrome,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.empty,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.loading,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.retry,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.startAdmission,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.create,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.update,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.delete,
        same(ipdWorkspaceDeleteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.write,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.operationalWrite,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.clinicalWrite,
        same(ipdClinicalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.nextActionManageTransfer,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.manageTransfer,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.requestTransfer,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.billingPanel,
        same(ipdBillingPanelReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.billingRead,
        same(ipdBillingReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.manageBeds,
        same(ipdBedManageRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.routeEntry,
        same(RouteAccessCatalog.ipdEntry),
      );
      expect(
        IpdTransfersAtomPermissions.nestedWrite,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.nestedRead,
        same(ipdWorkspaceReadRequirement),
      );
      expect(
        IpdTransfersAtomPermissions.panelDeepLink,
        same(ipdOperationalWriteRequirement),
      );
      expect(
        ipdBoardTabRequirement(IpdWorkspaceSection.transferPending),
        same(IpdTransfersAtomPermissions.tab),
      );
      expect(
        ipdBoardNextActionRequirement(IpdBoardNextActionKind.manageTransfer),
        same(ipdOperationalWriteRequirement),
      );
      expect(
        ipdFocusedMutationRequirement(panel: IpdDetailPanel.transfer),
        same(ipdOperationalWriteRequirement),
      );
      expect(ipdRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: operational write missing hides transfer write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IpdTransfersAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(canViewIpdTransfers(reader), isTrue);
      expect(IpdTransfersAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IpdTransfersAtomPermissions.nextActionManageTransfer.isAllowed(reader),
        isFalse,
      );
      expect(
        IpdTransfersAtomPermissions.manageTransfer.isAllowed(reader),
        isFalse,
      );
      expect(
        IpdTransfersAtomPermissions.startAdmission.isAllowed(reader),
        isFalse,
      );
      expect(canWriteIpdOperational(reader), isFalse);
    });

    test('∪ allowance: operations:read satisfies Transfers tab chrome', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(canViewIpdTransfers(opsReader), isTrue);
      expect(canReadIpd(opsReader), isTrue);
      expect(
        IpdTransfersAtomPermissions.listChrome.isAllowed(opsReader),
        isTrue,
      );
      expect(
        IpdTransfersAtomPermissions.startAdmission.isAllowed(opsReader),
        isFalse,
      );
      expect(
        IpdTransfersAtomPermissions.nextActionManageTransfer.isAllowed(
          opsReader,
        ),
        isFalse,
      );
      expect(
        IpdTransfersAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
    });

    test('∪ allowance: billing:read satisfies route entry but not tab', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(
        IpdTransfersAtomPermissions.routeEntry.isAllowed(billingOnly),
        isTrue,
      );
      expect(canViewIpdTransfers(billingOnly), isFalse);
      expect(
        ipdAllowedSections(billingOnly).contains(
          IpdWorkspaceSection.transferPending,
        ),
        isFalse,
      );
      expect(
        IpdTransfersAtomPermissions.billingPanel.isAllowed(billingOnly),
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
        IpdTransfersAtomPermissions.billingPanel.isAllowed(clinical),
        isFalse,
      );
      expect(canReadIpdBilling(clinical), isFalse);
    });

    test(
      'full intersection set: clinical write + module allows transfer ops',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(IpdTransfersAtomPermissions.tab.isAllowed(writer), isTrue);
        expect(IpdTransfersAtomPermissions.write.isAllowed(writer), isTrue);
        expect(
          IpdTransfersAtomPermissions.nextActionManageTransfer.isAllowed(
            writer,
          ),
          isTrue,
        );
        expect(
          IpdTransfersAtomPermissions.startAdmission.isAllowed(writer),
          isTrue,
        );
      },
    );

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
      expect(IpdTransfersAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        IpdTransfersAtomPermissions.nextActionManageTransfer.isAllowed(
          noModule,
        ),
        isFalse,
      );
      expect(canViewIpdTransfers(noModule), isFalse);
    });

    test(
      'source mapping: operations:write satisfies manage transfer without clinical:write',
      () {
        final AppAccessPolicy opsWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
          roles: const <String>['OPERATIONS'],
        );
        expect(
          IpdTransfersAtomPermissions.startAdmission.isAllowed(opsWriter),
          isTrue,
        );
        expect(
          IpdTransfersAtomPermissions.manageTransfer.isAllowed(opsWriter),
          isTrue,
        );
        expect(
          IpdTransfersAtomPermissions.nextActionManageTransfer.isAllowed(
            opsWriter,
          ),
          isTrue,
        );
        // Clinical-only detail writes remain matrix ∩ clinical:write.
        expect(
          IpdTransfersAtomPermissions.nextActionNursingNote.isAllowed(
            opsWriter,
          ),
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
        IpdTransfersAtomPermissions.manageBeds.isAllowed(unitManager),
        isFalse,
      );
    });

    test(
      'ABAC: missing facility still allows Transfers chrome '
      '(facility scope enforced server-side)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          facilityId: null,
        );
        expect(canViewIpdTransfers(noFacility), isTrue);
        expect(
          IpdTransfersAtomPermissions.manageTransfer.isAllowed(noFacility),
          isFalse,
        );
      },
    );

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
        IpdTransfersAtomPermissions.routeEntry.anyPermissions.toSet(),
        equals(AppRoutes.ipd.requiredAnyPermissions.toSet()),
      );
    });
  });

  testWidgets(
    'read-only ∪: Transfers visible; Start admission / Manage transfer absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Transfers'), findsWidgets);
      expect(find.text('Terry Transfer'), findsOneWidget);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.text('Manage transfer'), findsNothing);
      expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
    },
  );

  testWidgets('authorized writer: Start admission + Manage transfer', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: writer,
    );

    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Manage transfer'), findsWidgets);
    expect(find.text('Terry Transfer'), findsOneWidget);
  });

  testWidgets('∪ operations:read shows Transfers without write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy opsReader = _policy(
      permissions: <AppPermission>{AppPermissions.operationsRead},
    );
    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: opsReader,
    );

    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.text('Terry Transfer'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsNothing);
    expect(find.text('Manage transfer'), findsNothing);
  });

  testWidgets('billing:read alone collapses strip (no board read)', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy billingOnly = _policy(
      permissions: <AppPermission>{AppPermissions.billingRead},
    );
    await _pumpTransfersTab(
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
    await _pumpTransfersTab(
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
    await _pumpTransfersTab(
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

  testWidgets('mobile viewport: Transfers row + Start admission remain reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );

    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.text('Terry Transfer'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    // Mobile list chrome omits the next-action column; row select opens detail.
    await tester.tap(find.text('Terry Transfer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    // Stage next-action Manage transfer is omitted from detail Quick Actions.
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Manage transfer'),
      ),
      findsNothing,
    );
  });

  testWidgets('desktop viewport: Manage transfer next-action remains reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Manage transfer'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('light theme: authorized Transfers chrome remains visible', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.light,
    );

    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Manage transfer'), findsWidgets);
  });

  testWidgets('dark theme: authorized Transfers chrome remains visible', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.text('Manage transfer'), findsWidgets);
  });

  testWidgets(
    'post-mutation sync: Manage transfer opens update dialog for writers',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdTransfersAtomPermissions.manageTransfer.isAllowed(writer),
        isTrue,
      );

      when(() => repository.updateTransfer(any(), any())).thenAnswer((_) async {
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
        when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
        return Result<IpdAdmissionDetail>.success(
          IpdAdmissionDetail(
            summary: _transferPending.copyWith(
              stage: 'TRANSFER_IN_PROGRESS',
              nextStep: 'COMPLETE_TRANSFER',
              transferStatus: 'IN_PROGRESS',
            ),
            openTransferRequest: const IpdTransferRequest(
              id: 'tr-1',
              status: 'IN_PROGRESS',
            ),
          ),
        );
      });

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Manage transfer'), findsWidgets);
      await tester.tap(find.text('Manage transfer').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Transfer update dialog opens for authorized writers (gate integration).
      expect(find.byType(AppDialog), findsWidgets);
      expect(find.textContaining('MANAGE TRANSFER'), findsWidgets);
    },
  );

  testWidgets(
    'panel=transfers deep link denied without operational write',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        ipdFocusedMutationRequirement(panel: IpdDetailPanel.transfer)!
            .isAllowed(reader),
        isFalse,
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        initialLocation: '/ipd?section=transfers&id=adm-transfer&panel=transfers',
      );

      // Restricted deep link must not mount the write dialog; no routine banner.
      expect(find.textContaining('MANAGE TRANSFER'), findsNothing);
      expect(find.textContaining('No access'), findsNothing);
      expect(find.text('Terry Transfer'), findsOneWidget);
    },
  );

  testWidgets(
    'panel=transfers deep link opens update dialog for operational writers',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        initialLocation: '/ipd?section=transfers&id=adm-transfer&panel=transfers',
      );

      expect(find.textContaining('MANAGE TRANSFER'), findsWidgets);
      expect(find.text('ADMISSION DETAIL'), findsNothing);
    },
  );

  testWidgets(
    'Manage beds not mounted on Transfers; billing panel absent without billing:read',
    (WidgetTester tester) async {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: clinicalWriter,
      );

      expect(find.byTooltip('Manage beds'), findsNothing);
      expect(find.textContaining('Manage beds'), findsNothing);

      await tester.tap(find.text('Terry Transfer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Nested billing / insurance panel needs ∩ billing:read + module.
      expect(
        IpdTransfersAtomPermissions.billingPanel.isAllowed(clinicalWriter),
        isFalse,
      );
      expect(find.textContaining('Insurance'), findsNothing);
    },
  );

  testWidgets(
    'detail omits Manage transfer next-action; nested write absent for readers',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('Terry Transfer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final Finder dialog = find.byType(AppDialog);
      expect(dialog, findsWidgets);
      expect(
        find.descendant(of: dialog, matching: find.text('Manage transfer')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Request transfer')),
        findsNothing,
      );
    },
  );
}
