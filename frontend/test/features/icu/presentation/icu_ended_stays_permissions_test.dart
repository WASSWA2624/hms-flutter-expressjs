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

const IcuPatientSummary _endedStay = IcuPatientSummary(
  id: 'ADM-END-1',
  admissionId: 'ADM-END-1',
  displayId: 'ADM-END1',
  patientDisplayName: 'Ended Stay Patient',
  icuStatus: 'ENDED',
  admissionStatus: 'DISCHARGED',
  bedLabel: 'ICU-9',
  hasActiveBed: true,
  encounterId: 'ENC-END-1',
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
  List<IcuPatientSummary> board = const <IcuPatientSummary>[_endedStay],
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
    if (query.scope == IcuBoardScope.ended) {
      items = board
          .where((IcuPatientSummary item) => item.isEndedIcu)
          .toList(growable: false);
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
        // Historical stay — no active ICU stay (prefer read-only).
        latestStay: const IcuStaySummary(id: 'stay-ended-1'),
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

Future<void> _pumpEndedStaysTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary>? items,
  Result<AppPage<IcuPatientSummary>>? listOverride,
  IcuPatientDetail? detailOverride,
  String initialLocation = '/icu?section=ended',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(
    repository,
    board: items ?? <IcuPatientSummary>[_endedStay],
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

  group('IcuEndedStaysAtomPermissions mapping', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IcuEndedStaysAtomPermissions.tab,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.listChrome,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.loading,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.detail,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.printSummary,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.write,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.write,
        same(IcuWorkspaceWriteRequirement.writeRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.validation,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.success,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.nextActionOpenIpd,
        same(icuNavigationRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.nextAction,
        same(icuNavigationRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.navigate,
        same(icuNavigationRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.delete,
        same(icuWorkspaceDeleteRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.routeEntry,
        same(icuWorkspaceRouteEntryRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.ended),
        same(IcuEndedStaysAtomPermissions.tab),
      );
      expect(
        icuDetailReadRequirement(IcuWorkspaceSection.ended),
        same(IcuEndedStaysAtomPermissions.detail),
      );
      expect(
        icuWriteRequirementForSection(IcuWorkspaceSection.ended),
        same(IcuEndedStaysAtomPermissions.write),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: clinical:read alone does not grant write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuEndedStaysAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IcuEndedStaysAtomPermissions.write.isAllowed(reader), isFalse);
      expect(IcuEndedStaysAtomPermissions.round.isAllowed(reader), isFalse);
      expect(IcuEndedStaysAtomPermissions.endStay.isAllowed(reader), isFalse);
      expect(IcuEndedStaysAtomPermissions.create.isAllowed(reader), isFalse);
      expect(
        IcuEndedStaysAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(canWriteIcu(reader), isFalse);
      expect(canViewIcuEndedStays(reader), isTrue);
      // Navigate next-action stays available without write.
      expect(
        IcuEndedStaysAtomPermissions.nextActionOpenIpd.isAllowed(reader),
        isTrue,
      );
      expect(
        icuBoardShowsNextActionColumn(reader, IcuWorkspaceSection.ended),
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
          IcuEndedStaysAtomPermissions.write.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(
          IcuEndedStaysAtomPermissions.round.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(
          IcuEndedStaysAtomPermissions.validation.isAllowed(clinicalWriter),
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
          IcuEndedStaysAtomPermissions.write.isAllowed(emergencyWriter),
          isTrue,
        );
      },
    );

    test('∪ allowance: emergency:read satisfies Ended stays tab', () {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(
        IcuEndedStaysAtomPermissions.tab.isAllowed(emergencyReader),
        isTrue,
      );
      expect(
        IcuEndedStaysAtomPermissions.loading.isAllowed(emergencyReader),
        isTrue,
      );
      expect(canViewIcuEndedStays(emergencyReader), isTrue);
      expect(canReadIcu(emergencyReader), isTrue);
      expect(
        IcuEndedStaysAtomPermissions.write.isAllowed(emergencyReader),
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
        IcuEndedStaysAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      expect(canEnterIcuWorkspace(opsReader), isTrue);
      expect(canViewIcuEndedStays(opsReader), isFalse);
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
      expect(IcuEndedStaysAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(IcuEndedStaysAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(icuAllowedSections(noModule), isEmpty);
    });

    test('nested cross-module rows are n/a; nestedWrite reuses write ∪', () {
      expect(
        IcuEndedStaysAtomPermissions.nestedWrite,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.nestedRead,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.nestedWrite.anyPermissions.toSet(),
        <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        },
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        IcuEndedStaysAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
    });

    test('next-action Open IPD is navigate; panel deep-links stay write ∪', () {
      expect(
        icuBoardNextActionKind(_endedStay, IcuWorkspaceSection.ended),
        IcuNextActionKind.openIpd,
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.openIpd),
        same(icuNavigationRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.nextAction,
        same(icuNavigationRequirement),
      );
      expect(
        icuFocusedPanelRequirement(IcuDetailPanel.vitals),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuEndedStaysAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuBoardShowsNextActionColumn(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
          IcuWorkspaceSection.ended,
        ),
        isTrue,
      );
    });

    test(
      'ABAC: missing facility still allows Ended chrome '
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
        expect(IcuEndedStaysAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          IcuEndedStaysAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
        expect(
          IcuEndedStaysAtomPermissions.routeEntry.isAllowed(noFacility),
          isTrue,
        );
      },
    );
  });

  testWidgets(
    'read-only ∩ denial: Ended list visible; write atoms absent; Open IPD remains',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Ended Stay Patient'), findsOneWidget);
      expect(find.textContaining('Ended stays'), findsWidgets);
      expect(find.text('Open in IPD'), findsWidgets);
      expect(find.text('Start ICU stay'), findsNothing);
      expect(find.text('End ICU stay'), findsNothing);
      expect(find.text('Assign ICU bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppSearchBar), findsOneWidget);
    },
  );

  testWidgets(
    '∪ allowance: emergency:read shows Ended stays tab chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.textContaining('Ended stays'), findsWidgets);
      expect(find.text('Ended Stay Patient'), findsOneWidget);
      expect(find.text('Open in IPD'), findsWidgets);
      expect(find.text('End ICU stay'), findsNothing);
    },
  );

  testWidgets(
    'write ∪ presence: Open IPD remains; ineligible stay mutations stay absent',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Ended Stay Patient'), findsOneWidget);
      expect(find.text('Open in IPD'), findsWidgets);
      // Historical stay — no active stay ⇒ End stay / Observation absent on row.
      expect(find.text('End ICU stay'), findsNothing);
      expect(find.text('Observation'), findsNothing);
    },
  );

  testWidgets(
    'read-only detail omits write actions; navigate / print remain',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('Ended Stay Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Print summary'), findsOneWidget);
      expect(find.text('Open billing'), findsOneWidget);
      // Open IPD is the row next-action — omitted from detail Quick Actions.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Open in IPD'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('ICU round'),
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
    'authorized writer detail mounts complementary write ∪ atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Ended Stay Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('ICU round'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Discharge readiness'),
        ),
        findsOneWidget,
      );
      // No active stay — End stay / Observation / Raise alert stay absent.
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
          matching: find.text('Observation'),
        ),
        findsNothing,
      );
      expect(find.text('Print summary'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription strip collapses Ended chrome without icu-critical-care',
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

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Ended Stay Patient'), findsNothing);
      expect(find.text('Open in IPD'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty state remains observable for readers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpEndedStaysTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      items: const <IcuPatientSummary>[],
    );
    expect(find.text('No ICU patients'), findsOneWidget);
    expect(find.text('End ICU stay'), findsNothing);
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

    await _pumpEndedStaysTab(
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
        IcuEndedStaysAtomPermissions.markReadiness.isAllowed(writer),
        isTrue,
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _endedStay,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.markDischargeReady(
        summary: 'Historical readiness note',
      );
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.markDischargeReady(
          detail: any(named: 'detail'),
          summary: 'Historical readiness note',
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
    },
  );

  testWidgets('integration: Ended tab selected via section=ended deep link', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpEndedStaysTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      initialLocation: '/icu?section=ended',
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.ended),
      isTrue,
    );
  });

  testWidgets('mobile + dark: read-only chrome hides write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpEndedStaysTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('Ended stays'), findsWidgets);
    expect(find.text('End ICU stay'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
    expect(find.byType(AppSearchBar), findsOneWidget);
    expect(
      find.text('Ended Stay Patient').evaluate().isNotEmpty ||
          find.text('No ICU patients').evaluate().isNotEmpty ||
          find.byType(AppListTable<IcuPatientSummary>).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('desktop + light: navigate Open IPD mounts for writer', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpEndedStaysTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Open in IPD'), findsWidgets);
    expect(find.text('Ended Stay Patient'), findsOneWidget);
  });

  testWidgets(
    'Open IPD navigates for authorized reader (integration)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Open in IPD'), findsWidgets);
      await tester.tap(find.text('Open in IPD').first);
      await tester.pumpAndSettle();

      expect(find.text('ipd-workspace'), findsOneWidget);
    },
  );

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
        IcuEndedStaysAtomPermissions.validation.isAllowed(writer),
        isTrue,
      );

      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final AppFailure? selectFailure = await container
          .read(icuWorkspaceControllerProvider.notifier)
          .selectPatient(_endedStay);
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
      initialLocation: '/icu?section=ended',
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
    expect(find.text('End ICU stay'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);

    listCompleter.complete(
      Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[_endedStay],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ended Stay Patient'), findsOneWidget);
  });
}
