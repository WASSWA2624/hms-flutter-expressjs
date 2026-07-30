import 'dart:async';

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
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _pendingReadiness = IcuPatientSummary(
  id: 'ADM-DR-1',
  admissionId: 'ADM-DR-1',
  displayId: 'ADM-DR1',
  patientDisplayName: 'Dana Discharge',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-3',
  hasActiveBed: true,
  encounterId: 'ENC-DR-1',
);

const IcuPatientSummary _plannedClearance = IcuPatientSummary(
  id: 'ADM-DR-2',
  admissionId: 'ADM-DR-2',
  displayId: 'ADM-DR2',
  patientDisplayName: 'Pat Planned',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-4',
  hasActiveBed: true,
  dischargeStatus: 'PLANNED',
  encounterId: 'ENC-DR-2',
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
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBoard(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> board = const <IcuPatientSummary>[_pendingReadiness],
  Result<AppPage<IcuPatientSummary>>? listOverride,
  IcuPatientDetail? detailOverride,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> items = board;
    if (query.scope == IcuBoardScope.discharge) {
      items = board;
    }
    if (query.search.trim().isNotEmpty) {
      final String needle = query.search.trim().toLowerCase();
      items = items
          .where((IcuPatientSummary item) => item.matchesSearch(needle))
          .toList(growable: false);
    }
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(
      IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
    ),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<IcuPatientDetail>.success(detailOverride);
    }
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    return Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: summary,
        activeStay: const IcuStaySummary(id: 'stay-1'),
      ),
    );
  });
  when(
    () => repository.markDischargeReady(
      detail: any(named: 'detail'),
      summary: any(named: 'summary'),
      dischargedAt: any(named: 'dischargedAt'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final IcuPatientDetail detail =
        invocation.namedArguments[#detail] as IcuPatientDetail;
    final IcuPatientDetail updated = detail.copyWith(
      summary: detail.summary.copyWith(dischargeStatus: 'PLANNED'),
    );
    return Result<IcuPatientDetail>.success(updated);
  });
}

Future<void> _pumpDischargeReadyTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary>? items,
  Result<AppPage<IcuPatientSummary>>? listOverride,
  IcuPatientDetail? detailOverride,
  String initialLocation = '/icu?section=discharge',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(
    repository,
    board: items ?? <IcuPatientSummary>[_pendingReadiness],
    listOverride: listOverride,
    detailOverride: detailOverride,
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
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('discharge-clearance')),
      ),
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('ipd-workspace')),
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

  group('IcuDischargeReadyAtomPermissions mapping', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IcuDischargeReadyAtomPermissions.tab,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.listChrome,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.loading,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.detail,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.printSummary,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.write,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.write,
        same(IcuWorkspaceWriteRequirement.writeRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.validation,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.success,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.nextActionMarkReadiness,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.nextActionOpenDischargeClearance,
        same(icuNavigationRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.navigate,
        same(icuNavigationRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.delete,
        same(icuWorkspaceDeleteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.routeEntry,
        same(icuWorkspaceRouteEntryRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.discharge),
        same(IcuDischargeReadyAtomPermissions.tab),
      );
      expect(
        icuDetailReadRequirement(IcuWorkspaceSection.discharge),
        same(IcuDischargeReadyAtomPermissions.detail),
      );
      expect(
        icuWriteRequirementForSection(IcuWorkspaceSection.discharge),
        same(IcuDischargeReadyAtomPermissions.write),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: clinical:read alone does not grant write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuDischargeReadyAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IcuDischargeReadyAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IcuDischargeReadyAtomPermissions.markReadiness.isAllowed(reader),
        isFalse,
      );
      expect(
        IcuDischargeReadyAtomPermissions.nextActionMarkReadiness.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        IcuDischargeReadyAtomPermissions.endStay.isAllowed(reader),
        isFalse,
      );
      expect(
        IcuDischargeReadyAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(canWriteIcu(reader), isFalse);
      expect(canViewIcuDischargeReady(reader), isTrue);
      // Navigate next-action stays available without write.
      expect(
        IcuDischargeReadyAtomPermissions.nextActionOpenDischargeClearance
            .isAllowed(reader),
        isTrue,
      );
      expect(
        icuBoardShowsNextActionColumn(reader, IcuWorkspaceSection.discharge),
        isTrue,
      );
    });

    test(
      'full write set: clinical:write ∪ source (or emergency:write) grants mutations',
      () {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(
          IcuDischargeReadyAtomPermissions.write.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(
          IcuDischargeReadyAtomPermissions.markReadiness.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          IcuDischargeReadyAtomPermissions.validation.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(canWriteIcu(clinicalWriter), isTrue);

        final AppAccessPolicy emergencyWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        );
        // Source keep ∪ emergency:write (matrix ∩ clinical:write alone).
        expect(
          IcuDischargeReadyAtomPermissions.write.isAllowed(emergencyWriter),
          isTrue,
        );
      },
    );

    test('∪ allowance: emergency:read satisfies Discharge ready tab', () {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(
        IcuDischargeReadyAtomPermissions.tab.isAllowed(emergencyReader),
        isTrue,
      );
      expect(
        IcuDischargeReadyAtomPermissions.loading.isAllowed(emergencyReader),
        isTrue,
      );
      expect(canViewIcuDischargeReady(emergencyReader), isTrue);
      expect(canReadIcu(emergencyReader), isTrue);
      expect(
        IcuDischargeReadyAtomPermissions.write.isAllowed(emergencyReader),
        isFalse,
      );
    });

    test('∪ allowance: operations:read satisfies route entry, not tab read', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'icu-critical-care',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        IcuDischargeReadyAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      expect(canEnterIcuWorkspace(opsReader), isTrue);
      expect(canViewIcuDischargeReady(opsReader), isFalse);
      expect(canReadIcu(opsReader), isFalse);
      expect(icuAllowedSections(opsReader), isEmpty);
    });

    test('subscription strip: icu-critical-care required for tab / write', () {
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
      expect(
        IcuDischargeReadyAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        IcuDischargeReadyAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(icuAllowedSections(noModule), isEmpty);
    });

    test(
      'ABAC: missing facility still allows Discharge chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          IcuDischargeReadyAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          IcuDischargeReadyAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
        expect(
          IcuDischargeReadyAtomPermissions.routeEntry.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test('nested cross-module rows are n/a; nestedWrite reuses write ∪', () {
      expect(
        IcuDischargeReadyAtomPermissions.nestedWrite,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.nestedRead,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.nestedWrite.anyPermissions.toSet(),
        <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        },
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        IcuDischargeReadyAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
    });

    test('next-action / panel deep-link requirements map correctly', () {
      expect(
        icuNextActionRequirement(IcuNextActionKind.markReadiness),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.openDischargeClearance),
        same(icuNavigationRequirement),
      );
      expect(
        icuFocusedPanelRequirement(IcuDetailPanel.discharge),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuBoardNextActionKind(
          _pendingReadiness,
          IcuWorkspaceSection.discharge,
        ),
        IcuNextActionKind.markReadiness,
      );
      expect(
        icuBoardNextActionKind(
          _plannedClearance,
          IcuWorkspaceSection.discharge,
        ),
        IcuNextActionKind.openDischargeClearance,
      );
      expect(
        icuBoardShowsNextActionColumn(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
          IcuWorkspaceSection.discharge,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only ∩ denial: Discharge list visible; Mark readiness / writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Dana Discharge'), findsOneWidget);
      expect(find.textContaining('Discharge ready'), findsWidgets);
      expect(find.text('Discharge readiness'), findsNothing);
      expect(find.text('Mark discharge readiness'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppSearchBar), findsOneWidget);
    },
  );

  testWidgets(
    '∪ allowance: emergency:read shows Discharge ready tab chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.textContaining('Discharge ready'), findsWidgets);
      expect(find.text('Dana Discharge'), findsOneWidget);
      expect(find.text('Discharge readiness'), findsNothing);
    },
  );

  testWidgets(
    'planned row: Open discharge clearance remains for read-only users',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        items: const <IcuPatientSummary>[_plannedClearance],
      );

      expect(find.text('Pat Planned'), findsOneWidget);
      expect(find.text('Open discharge clearance'), findsWidgets);
      expect(find.text('Discharge readiness'), findsNothing);
    },
  );

  testWidgets(
    'write ∩ presence: Mark readiness mounts for clinical:write',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Dana Discharge'), findsOneWidget);
      expect(find.text('Discharge readiness'), findsWidgets);
    },
  );

  testWidgets(
    'read-only detail omits write actions; navigate / print remain',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('Dana Discharge'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Print summary'), findsOneWidget);
      expect(find.text('Open in IPD'), findsOneWidget);
      expect(find.text('Open billing'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Discharge readiness'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('End ICU stay'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Critical alert'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized writer detail mounts Mark readiness complementary action',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        items: const <IcuPatientSummary>[_plannedClearance],
      );

      await tester.tap(find.text('Pat Planned'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Planned next-action is Open clearance (omitted from detail); Mark
      // readiness remains as complementary write.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Discharge readiness'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Open discharge clearance'),
        ),
        findsNothing,
      );
      expect(find.text('Print summary'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription strip collapses Discharge chrome without icu-critical-care',
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

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Dana Discharge'), findsNothing);
      expect(find.text('Discharge readiness'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'panel=discharge denied falls back to read-only detail (no write dialog)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        initialLocation: '/icu?section=discharge&id=ADM-DR1&panel=discharge',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('ICU STAY'), findsOneWidget);
      expect(find.text('MARK DISCHARGE READINESS'), findsNothing);
      expect(find.text('Mark ready'), findsNothing);
      expect(find.text('Print summary'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'panel=discharge authorized opens readiness dialog without empty detail shell',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        initialLocation: '/icu?section=discharge&id=ADM-DR1&panel=discharge',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('MARK DISCHARGE READINESS'), findsOneWidget);
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

    await _pumpDischargeReadyTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      items: const <IcuPatientSummary>[],
    );
    expect(find.text('No ICU patients'), findsOneWidget);
    expect(find.text('Discharge readiness'), findsNothing);
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

    await _pumpDischargeReadyTab(
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

  testWidgets(
    'post-mutation sync: Mark readiness patches selected stay via write ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IcuDischargeReadyAtomPermissions.markReadiness.isAllowed(writer),
        isTrue,
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Discharge readiness'), findsWidgets);

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _pendingReadiness,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.markDischargeReady(
        summary: 'Ready for step-down',
      );
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.markDischargeReady(
          detail: any(named: 'detail'),
          summary: 'Ready for step-down',
          dischargedAt: any(named: 'dischargedAt'),
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
      expect(state?.selectedDetail?.summary.isDischargePlanned, isTrue);
      expect(
        state?.board.items.any(
          (IcuPatientSummary item) =>
              item.id == _pendingReadiness.id && item.isDischargePlanned,
        ),
        isTrue,
      );
    },
  );

  testWidgets('mobile + dark: read-only chrome hides write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpDischargeReadyTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('Discharge ready'), findsWidgets);
    expect(find.text('Discharge readiness'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
    expect(find.byType(AppSearchBar), findsOneWidget);
    // Mobile list may render after scope apply; patient or empty chrome must
    // stay authorized without write affordances.
    expect(
      find.text('Dana Discharge').evaluate().isNotEmpty ||
          find.text('No ICU patients').evaluate().isNotEmpty ||
          find.byType(AppListTable<IcuPatientSummary>).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('desktop + light: write ∪ mounts Mark readiness', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpDischargeReadyTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Discharge readiness'), findsWidgets);
    expect(find.text('Dana Discharge'), findsOneWidget);
  });

  testWidgets('integration: Discharge tab selected via section=discharge', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpDischargeReadyTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      initialLocation: '/icu?section=discharge',
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.discharge),
      isTrue,
    );
    expect(find.textContaining('Discharge ready'), findsWidgets);
  });

  testWidgets(
    'authorized readiness dialog shows validation on empty submit',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IcuDischargeReadyAtomPermissions.validation.isAllowed(writer),
        isTrue,
      );

      await _pumpDischargeReadyTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final AppFailure? selectFailure = await container
          .read(icuWorkspaceControllerProvider.notifier)
          .selectPatient(_pendingReadiness);
      expect(selectFailure, isNull);
      await tester.pump();

      // Do not await — dialog future completes only when dismissed.
      final Future<void> dialogFuture = openIcuReadinessDialog(element);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // AppDialog uppercases plain Text titles.
      expect(find.text('MARK DISCHARGE READINESS'), findsOneWidget);
      await tester.tap(find.text('Mark ready'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      verifyNever(
        () => repository.markDischargeReady(
          detail: any(named: 'detail'),
          summary: any(named: 'summary'),
          dischargedAt: any(named: 'dischargedAt'),
        ),
      );

      // Dismiss so the dialog future can complete cleanly.
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();
      await dialogFuture;
    },
  );

  testWidgets('authorized loading chrome remains observable', (
    WidgetTester tester,
  ) async {
    final Completer<Result<AppPage<IcuPatientSummary>>> listCompleter =
        Completer<Result<AppPage<IcuPatientSummary>>>();
    when(() => repository.listIcuBoard(any())).thenAnswer(
      (_) => listCompleter.future,
    );
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
    );
    when(() => repository.loadBedBoard()).thenAnswer(
      (_) async => const Result<IcuBedBoard>.success(
        IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
      ),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/icu?section=discharge',
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
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.clinicalRead},
            ),
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Loading ICU board'), findsOneWidget);
    expect(find.text('Discharge readiness'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);

    listCompleter.complete(
      Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[_pendingReadiness],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
