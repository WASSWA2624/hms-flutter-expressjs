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
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _openTransferPatient = IcuPatientSummary(
  id: 'ADM-XFER-1',
  admissionId: 'ADM-XFER-1',
  displayId: 'ADMXFER1',
  patientDisplayName: 'Transfer Tab Patient',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-5',
  hasActiveBed: true,
  transferStatus: 'REQUESTED',
  encounterId: 'ENC-XFER-1',
);

const IcuPatientSummary _noOpenTransferPatient = IcuPatientSummary(
  id: 'ADM-XFER-2',
  admissionId: 'ADM-XFER-2',
  displayId: 'ADMXFER2',
  patientDisplayName: 'Request Transfer Patient',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-6',
  hasActiveBed: true,
  encounterId: 'ENC-XFER-2',
);

const IcuPatientDetail _openTransferDetail = IcuPatientDetail(
  summary: _openTransferPatient,
  activeStay: IcuStaySummary(id: 'STAY-XFER-1'),
  transferRequests: <IcuTransferRequest>[
    IcuTransferRequest(
      id: 'TR-1',
      status: 'REQUESTED',
      toWardName: 'Ward B',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalWrite ||
        permission == AppPermissions.clinicalRead,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyWrite ||
        permission == AppPermissions.emergencyRead,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsWrite ||
        permission == AppPermissions.operationsRead,
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
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_openTransferPatient],
  IcuPatientDetail? detail,
  Result<AppPage<IcuPatientSummary>>? listOverride,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) async {
    if (listOverride != null) {
      return listOverride;
    }
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> filtered = items;
    if (query.scope == IcuBoardScope.transfer) {
      filtered = items
          .where((IcuPatientSummary item) => item.hasOpenTransfer)
          .toList(growable: false);
      // Transfers tab may also show patients eligible to request when API
      // returns the scoped page as-is; keep provided items when none open.
      if (filtered.isEmpty && items.isNotEmpty) {
        filtered = items;
      }
    }
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(
      IcuReferenceData(
        wards: <IcuWardOption>[
          IcuWardOption(id: 'ward-icu', name: 'ICU A', wardType: 'ICU'),
          IcuWardOption(id: 'ward-b', name: 'Ward B', wardType: 'GENERAL'),
        ],
      ),
    ),
  );
  when(repository.loadBedBoard).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((invocation) async {
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    if (detail != null) {
      return Result<IcuPatientDetail>.success(detail);
    }
    return Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: summary,
        activeStay: const IcuStaySummary(id: 'STAY-XFER-1'),
        transferRequests: summary.hasOpenTransfer
            ? const <IcuTransferRequest>[
                IcuTransferRequest(
                  id: 'TR-1',
                  status: 'REQUESTED',
                  toWardName: 'Ward B',
                ),
              ]
            : const <IcuTransferRequest>[],
      ),
    );
  });
  when(
    () => repository.requestTransfer(
      detail: any(named: 'detail'),
      toWardId: any(named: 'toWardId'),
      fromWardId: any(named: 'fromWardId'),
    ),
  ).thenAnswer((invocation) async {
    final IcuPatientDetail current =
        invocation.namedArguments[#detail] as IcuPatientDetail;
    return Result<IcuPatientDetail>.success(
      current.copyWith(
        summary: current.summary.copyWith(transferStatus: 'REQUESTED'),
      ),
    );
  });
  when(
    () => repository.updateTransfer(
      detail: any(named: 'detail'),
      transferRequestId: any(named: 'transferRequestId'),
      action: any(named: 'action'),
      toBedId: any(named: 'toBedId'),
    ),
  ).thenAnswer((invocation) async {
    final IcuPatientDetail current =
        invocation.namedArguments[#detail] as IcuPatientDetail;
    return Result<IcuPatientDetail>.success(
      current.copyWith(
        summary: current.summary.copyWith(transferStatus: 'APPROVED'),
      ),
    );
  });
}

Future<void> _pumpTransfersTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary>? items,
  IcuPatientDetail? detail,
  Result<AppPage<IcuPatientSummary>>? listOverride,
  String initialLocation = '/icu?section=transfers',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items ?? <IcuPatientSummary>[_openTransferPatient],
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
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('ipd-workspace')),
      ),
      GoRoute(
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('discharge-clearance')),
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('billing-workspace')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
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
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
    registerFallbackValue(_openTransferDetail);
    registerFallbackValue(IcuTransferAction.approve);
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('IcuTransfersAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IcuTransfersAtomPermissions.tab,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.transferColumn,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.detail,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.printSummary,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.write,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.write,
        same(IcuWorkspaceWriteRequirement.writeRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.nextActionManageTransfer,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.nextActionRequestTransfer,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.delete,
        same(icuWorkspaceDeleteRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.routeEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        IcuTransfersAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        icuWriteRequirementForSection(IcuWorkspaceSection.transfers),
        same(IcuTransfersAtomPermissions.write),
      );
      expect(
        icuDetailReadRequirement(IcuWorkspaceSection.transfers),
        same(IcuTransfersAtomPermissions.detail),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.transfers),
        same(IcuTransfersAtomPermissions.tab),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('nested cross-module matrix _(n/a)_: no extra module keys', () {
      expect(
        IcuTransfersAtomPermissions.nestedWrite,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.nestedRead,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuTransfersAtomPermissions.nestedWrite.anyPermissions.toSet(),
        <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        },
      );
    });

    test('∩ denial via missing write: clinical:read alone strips mutations', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuTransfersAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(canViewIcuTransfers(reader), isTrue);
      expect(IcuTransfersAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IcuTransfersAtomPermissions.nextActionManageTransfer.isAllowed(reader),
        isFalse,
      );
      expect(
        IcuTransfersAtomPermissions.requestTransfer.isAllowed(reader),
        isFalse,
      );
      expect(
        IcuTransfersAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(
        icuBoardShowsNextActionColumn(reader, IcuWorkspaceSection.transfers),
        isFalse,
      );
    });

    test('source write ∪: clinical:write alone satisfies transfer mutations', () {
      // Matrix lists ∩ clinical:write; source keeps ∪ clinical|emergency write.
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IcuTransfersAtomPermissions.write.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        IcuTransfersAtomPermissions.nextActionManageTransfer.isAllowed(
          clinicalWriter,
        ),
        isTrue,
      );
      expect(
        icuBoardShowsNextActionColumn(
          clinicalWriter,
          IcuWorkspaceSection.transfers,
        ),
        isTrue,
      );

      final AppAccessPolicy emergencyWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(
        IcuTransfersAtomPermissions.write.isAllowed(emergencyWriter),
        isTrue,
      );
    });

    test('∪ allowance: emergency:read shows Transfers tab without clinical:read',
        () {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewIcuTransfers(emergencyReader), isTrue);
      expect(
        IcuTransfersAtomPermissions.tab.isAllowed(emergencyReader),
        isTrue,
      );
      expect(
        IcuTransfersAtomPermissions.write.isAllowed(emergencyReader),
        isFalse,
      );
    });

    test('∪ allowance: operations:read enters route but not Transfers tab', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        IcuTransfersAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      expect(canViewIcuTransfers(opsReader), isFalse);
      expect(icuAllowedBoardSections(opsReader), isEmpty);
    });

    test('subscription strip: icu-critical-care required for Transfers tab', () {
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
      expect(IcuTransfersAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewIcuTransfers(noModule), isFalse);
      expect(IcuTransfersAtomPermissions.write.isAllowed(noModule), isFalse);
    });

    test('next-action / panel requirements map transfer kinds to write ∪', () {
      expect(
        icuBoardNextActionKind(
          _openTransferPatient,
          IcuWorkspaceSection.transfers,
        ),
        IcuNextActionKind.manageTransfer,
      );
      expect(
        icuBoardNextActionKind(
          _noOpenTransferPatient,
          IcuWorkspaceSection.transfers,
        ),
        IcuNextActionKind.requestTransfer,
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.manageTransfer),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.requestTransfer),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.openIpd),
        same(icuNavigationRequirement),
      );
      expect(
        icuFocusedPanelRequirement(IcuDetailPanel.transfer),
        same(icuWorkspaceWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only: Transfers list visible; Manage / Request writes absent (∪ read, write denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Transfer Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Transfers'), findsWidgets);
      expect(find.text('Manage transfer'), findsNothing);
      expect(find.text('Request transfer'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.textContaining('Next'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppSearchBar), findsOneWidget);

      await tester.tap(find.text('Transfer Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Manage transfer'), findsNothing);
      expect(find.text('Request transfer'), findsNothing);
      expect(find.text('End ICU stay'), findsNothing);
      expect(find.text('Critical alert'), findsNothing);
      expect(find.text('Print summary'), findsOneWidget);
      expect(find.text('Open billing'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∪: Manage transfer next-action + detail complementary writes mount',
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
      );

      expect(find.text('Transfer Tab Patient'), findsOneWidget);
      expect(find.text('Manage transfer'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Transfer Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Row next-action Manage transfer omitted from detail Quick Actions.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Manage transfer'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('ICU round'),
        ),
        findsOneWidget,
      );
      expect(find.text('Print summary'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: Request transfer mounts when patient has no open transfer',
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
        items: const <IcuPatientSummary>[_noOpenTransferPatient],
      );

      expect(find.text('Request Transfer Patient'), findsOneWidget);
      expect(find.text('Request transfer'), findsWidgets);
      expect(find.text('Manage transfer'), findsNothing);
    },
  );

  testWidgets(
    '∪ emergency:read alone shows Transfers tab content',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.text('Transfer Tab Patient'), findsOneWidget);
      expect(find.textContaining('Transfers'), findsWidgets);
      expect(find.text('Manage transfer'), findsNothing);
      expect(find.text('Request transfer'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip collapses Transfers chrome without icu-critical-care',
    (WidgetTester tester) async {
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

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Transfer Tab Patient'), findsNothing);
      expect(find.text('Manage transfer'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized requestTransfer syncs selected stay via write ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      final IcuPatientSummary afterRequest = _noOpenTransferPatient.copyWith(
        transferStatus: 'REQUESTED',
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        items: const <IcuPatientSummary>[_noOpenTransferPatient],
      );

      // After mutation + board refresh, return the patched transfer row.
      when(() => repository.listIcuBoard(any())).thenAnswer((invocation) async {
        final IcuBoardQuery query =
            invocation.positionalArguments.single as IcuBoardQuery;
        return Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: <IcuPatientSummary>[afterRequest],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
        );
      });
      when(() => repository.loadIcuDetail(any())).thenAnswer((_) async {
        return Result<IcuPatientDetail>.success(
          IcuPatientDetail(
            summary: afterRequest,
            activeStay: const IcuStaySummary(id: 'STAY-XFER-1'),
            transferRequests: const <IcuTransferRequest>[
              IcuTransferRequest(
                id: 'TR-1',
                status: 'REQUESTED',
                toWardName: 'Ward B',
              ),
            ],
          ),
        );
      });

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _noOpenTransferPatient,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.requestTransfer(
        toWardId: 'ward-b',
      );
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.requestTransfer(
          detail: any(named: 'detail'),
          toWardId: 'ward-b',
          fromWardId: any(named: 'fromWardId'),
        ),
      ).called(1);

      final IcuWorkspaceState? state = container
          .read(icuWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (IcuWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.selectedDetail?.summary.hasOpenTransfer, isTrue);
      expect(
        state?.board.items.any(
          (IcuPatientSummary item) => item.hasOpenTransfer,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'authorized updateTransfer syncs selected stay via write ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      final IcuPatientSummary afterApprove = _openTransferPatient.copyWith(
        transferStatus: 'APPROVED',
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        detail: _openTransferDetail,
      );

      when(() => repository.listIcuBoard(any())).thenAnswer((invocation) async {
        final IcuBoardQuery query =
            invocation.positionalArguments.single as IcuBoardQuery;
        return Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: <IcuPatientSummary>[afterApprove],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
        );
      });
      when(() => repository.loadIcuDetail(any())).thenAnswer((_) async {
        return Result<IcuPatientDetail>.success(
          IcuPatientDetail(
            summary: afterApprove,
            activeStay: const IcuStaySummary(id: 'STAY-XFER-1'),
            transferRequests: const <IcuTransferRequest>[
              IcuTransferRequest(
                id: 'TR-1',
                status: 'APPROVED',
                toWardName: 'Ward B',
              ),
            ],
          ),
        );
      });

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _openTransferPatient,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.updateTransfer(
        transferRequestId: 'TR-1',
        action: IcuTransferAction.approve,
      );
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.updateTransfer(
          detail: any(named: 'detail'),
          transferRequestId: 'TR-1',
          action: IcuTransferAction.approve,
          toBedId: any(named: 'toBedId'),
        ),
      ).called(1);

      final IcuWorkspaceState? state = container
          .read(icuWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (IcuWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.selectedDetail?.summary.transferStatus, 'APPROVED');
      expect(
        state?.board.items.any(
          (IcuPatientSummary item) => item.transferStatus == 'APPROVED',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'panel=transfer denied falls back to read-only detail (no write dialog)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpTransfersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        initialLocation: '/icu?section=transfers&id=ADMXFER1&panel=transfer',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('ICU STAY'), findsOneWidget);
      expect(find.text('REQUEST TRANSFER'), findsNothing);
      expect(find.text('Manage transfer'), findsNothing);
      expect(find.text('Print summary'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'panel=transfer authorized opens transfer dialog without empty detail shell',
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
        items: const <IcuPatientSummary>[_noOpenTransferPatient],
        initialLocation: '/icu?section=transfers&id=ADMXFER2&panel=transfer',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('REQUEST TRANSFER'), findsOneWidget);
      expect(find.text('ICU STAY'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

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
      items: const <IcuPatientSummary>[],
      listOverride: Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[],
          request: const AppPageRequest(),
          totalItemCount: 0,
        ),
      ),
    );

    expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
    expect(find.text('Manage transfer'), findsNothing);
    expect(find.text('Request transfer'), findsNothing);
    expect(find.byType(AppSearchBar), findsOneWidget);
  });

  testWidgets('authorized error/retry surface remains observable', (
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
      listOverride: const Result<AppPage<IcuPatientSummary>>.failure(
        AppFailure.network(),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('integration: Transfers tab selected via section=transfers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      initialLocation: '/icu?section=transfers',
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.transfer),
      isTrue,
    );
  });

  testWidgets('mobile viewport: Transfers read chrome + no write affordance', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpTransfersTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.text('Manage transfer'), findsNothing);
    expect(find.text('Request transfer'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('mobile + writer: Manage transfer trailing mounts', (
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Transfer Tab Patient'), findsOneWidget);
    expect(find.text('Manage transfer'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + light: Transfers write affordances remain for writer', (
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
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Transfer Tab Patient'), findsOneWidget);
    expect(find.text('Manage transfer'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + dark: Transfers write affordances remain for writer', (
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
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Transfer Tab Patient'), findsOneWidget);
    expect(find.text('Manage transfer'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });
}
