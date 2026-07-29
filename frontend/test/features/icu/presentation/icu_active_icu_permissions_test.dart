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
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _needsBed = IcuPatientSummary(
  id: 'ADM-ACT-1',
  admissionId: 'ADM-ACT-1',
  displayId: 'ADM-A1',
  patientDisplayName: 'Ada Active',
  icuStatus: 'ACTIVE',
  hasActiveBed: false,
  encounterId: 'ENC-ACT-1',
);

const IcuPatientSummary _needsObservation = IcuPatientSummary(
  id: 'ADM-ACT-2',
  admissionId: 'ADM-ACT-2',
  displayId: 'ADM-A2',
  patientDisplayName: 'Omar Observed',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-2',
  hasActiveBed: true,
  encounterId: 'ENC-ACT-2',
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
  List<IcuPatientSummary> board = const <IcuPatientSummary>[
    _needsBed,
    _needsObservation,
  ],
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
    () => repository.assignBed(
      detail: any(named: 'detail'),
      bedId: any(named: 'bedId'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final IcuPatientDetail detail =
        invocation.namedArguments[#detail] as IcuPatientDetail;
    return Result<IcuPatientDetail>.success(
      detail.copyWith(
        summary: detail.summary.copyWith(hasActiveBed: true),
      ),
    );
  });
}

Future<void> _pumpActiveTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary> board = const <IcuPatientSummary>[
    _needsBed,
    _needsObservation,
  ],
  Result<AppPage<IcuPatientSummary>>? listOverride,
  String initialLocation = '/icu',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(repository, board: board, listOverride: listOverride);

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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  if (initialLocation.contains('id=')) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
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

  group('IcuActiveIcuAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          IcuActiveIcuAtomPermissions.tab,
          icuWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuActiveIcuAtomPermissions.listChrome,
          icuWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuActiveIcuAtomPermissions.write,
          icuWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuActiveIcuAtomPermissions.nextActionAssignBed,
          icuWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuActiveIcuAtomPermissions.nextActionOpenIpd,
          icuNavigationRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuActiveIcuAtomPermissions.routeEntry,
          RouteAccessCatalog.icuEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuWorkspaceWriteRequirement.writeRequirement,
          icuWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          icuBoardTabRequirement(IcuWorkspaceSection.active),
          IcuActiveIcuAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          IcuActiveIcuAtomPermissions.nestedWrite,
          icuWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: clinical:read alone does not grant write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuActiveIcuAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IcuActiveIcuAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IcuActiveIcuAtomPermissions.nextActionAssignBed.isAllowed(reader),
        isFalse,
      );
      expect(
        IcuActiveIcuAtomPermissions.endStay.isAllowed(reader),
        isFalse,
      );
      expect(canWriteIcu(reader), isFalse);
      expect(canViewIcuActive(reader), isTrue);
    });

    test('full write set: clinical:write ∪ source grants mutations', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IcuActiveIcuAtomPermissions.write.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        IcuActiveIcuAtomPermissions.assignBed.isAllowed(clinicalWriter),
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
        IcuActiveIcuAtomPermissions.write.isAllowed(emergencyWriter),
        isTrue,
      );
    });

    test('∪ allowance: emergency:read satisfies Active ICU tab', () {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(
        IcuActiveIcuAtomPermissions.tab.isAllowed(emergencyReader),
        isTrue,
      );
      expect(canViewIcuActive(emergencyReader), isTrue);
      expect(canReadIcu(emergencyReader), isTrue);
      expect(
        IcuActiveIcuAtomPermissions.write.isAllowed(emergencyReader),
        isFalse,
      );
    });

    test('∪ allowance: operations:read satisfies route entry, not tab read', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        IcuActiveIcuAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      expect(canEnterIcuWorkspace(opsReader), isTrue);
      expect(canViewIcuActive(opsReader), isFalse);
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
      expect(IcuActiveIcuAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(IcuActiveIcuAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(icuAllowedSections(noModule), isEmpty);
    });

    test(
      'ABAC: missing facility still allows Active chrome '
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
        expect(IcuActiveIcuAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(IcuActiveIcuAtomPermissions.write.isAllowed(noFacility), isTrue);
        expect(
          IcuActiveIcuAtomPermissions.routeEntry.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test('nested cross-module rows are n/a; nestedWrite reuses write ∪', () {
      expect(
        identical(
          IcuActiveIcuAtomPermissions.nestedWrite,
          icuWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        IcuActiveIcuAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
    });

    test('next-action / panel deep-link requirements map correctly', () {
      expect(
        icuNextActionRequirement(IcuNextActionKind.assignBed),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.openIpd),
        same(icuNavigationRequirement),
      );
      expect(
        icuFocusedPanelRequirement(IcuDetailPanel.vitals),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuActiveIcuAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuBoardNextActionKind(_needsBed, IcuWorkspaceSection.active),
        IcuNextActionKind.assignBed,
      );
      expect(
        icuBoardNextActionKind(_needsObservation, IcuWorkspaceSection.active),
        IcuNextActionKind.recordObservation,
      );
    });
  });

  testWidgets(
    'read-only ∩ denial: Active list visible; Assign bed / writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpActiveTab(tester, repository: repository, accessPolicy: reader);

      expect(find.textContaining('Active ICU'), findsWidgets);
      expect(find.text('Ada Active'), findsOneWidget);
      expect(find.text('Omar Observed'), findsOneWidget);
      expect(find.text('Assign ICU bed'), findsNothing);
      expect(find.text('Record observation'), findsNothing);
      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.byType(AppListTable<IcuPatientSummary>), findsOneWidget);
    },
  );

  testWidgets(
    'authorized writer: Assign bed next-action present',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpActiveTab(tester, repository: repository, accessPolicy: writer);

      expect(find.text('Assign ICU bed'), findsWidgets);
      expect(find.text('Observation'), findsWidgets);
      expect(find.text('Ada Active'), findsOneWidget);
    },
  );

  testWidgets(
    'post-mutation sync: Assign bed patches selected stay + board via write ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IcuActiveIcuAtomPermissions.assignBed.isAllowed(writer), isTrue);

      const IcuPatientSummary assigned = IcuPatientSummary(
        id: 'ADM-ACT-1',
        admissionId: 'ADM-ACT-1',
        displayId: 'ADM-A1',
        patientDisplayName: 'Ada Active',
        icuStatus: 'ACTIVE',
        bedLabel: 'ICU-1',
        hasActiveBed: true,
        encounterId: 'ENC-ACT-1',
      );

      when(() => repository.listIcuBoard(any())).thenAnswer((
        Invocation invocation,
      ) async {
        final IcuBoardQuery query =
            invocation.positionalArguments.single as IcuBoardQuery;
        return Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: const <IcuPatientSummary>[_needsBed],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
        );
      });
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) async =>
            const Result<IcuReferenceData>.success(IcuReferenceData()),
      );
      when(() => repository.loadBedBoard()).thenAnswer(
        (_) async => const Result<IcuBedBoard>.success(
          IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
        ),
      );
      when(() => repository.loadIcuDetail(any())).thenAnswer(
        (_) async => Result<IcuPatientDetail>.success(
          IcuPatientDetail(
            summary: _needsBed,
            activeStay: const IcuStaySummary(id: 'stay-1'),
          ),
        ),
      );
      when(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: any(named: 'bedId'),
        ),
      ).thenAnswer((_) async {
        // Subsequent board refresh (refreshBoardAfter) returns assigned stay.
        when(() => repository.listIcuBoard(any())).thenAnswer((
          Invocation invocation,
        ) async {
          final IcuBoardQuery query =
              invocation.positionalArguments.single as IcuBoardQuery;
          return Result<AppPage<IcuPatientSummary>>.success(
            AppPage<IcuPatientSummary>(
              items: const <IcuPatientSummary>[assigned],
              request: query.pageRequest,
              totalItemCount: 1,
            ),
          );
        });
        return const Result<IcuPatientDetail>.success(
          IcuPatientDetail(
            summary: assigned,
            activeStay: IcuStaySummary(id: 'stay-1'),
          ),
        );
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/icu',
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
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(writer),
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
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _needsBed,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.assignBed('BED-ACT-1');
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: 'BED-ACT-1',
        ),
      ).called(1);
      verify(() => repository.listIcuBoard(any())).called(greaterThan(1));

      final IcuWorkspaceState? state = container
          .read(icuWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (IcuWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.selectedDetail?.summary.hasActiveBed, isTrue);
      expect(
        state?.board.items.any(
          (IcuPatientSummary item) =>
              item.id == assigned.id && item.hasActiveBed,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    '∪ emergency:read shows Active tab without write next-actions',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.textContaining('Active ICU'), findsWidgets);
      expect(find.text('Ada Active'), findsOneWidget);
      expect(find.text('Assign ICU bed'), findsNothing);
    },
  );

  testWidgets(
    'operations:read alone collapses strip (no board read)',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(AppListTable<IcuPatientSummary>), findsNothing);
    },
  );

  testWidgets('authorized empty state remains observable for readers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      listOverride: Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[],
          request: const AppPageRequest(pageIndex: 0, pageSize: 25),
          totalItemCount: 0,
        ),
      ),
    );
    expect(find.text('No ICU patients'), findsOneWidget);
    expect(find.text('Assign ICU bed'), findsNothing);
  });

  testWidgets('authorized error/retry surface remains observable on Active', (
    WidgetTester tester,
  ) async {
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      listOverride: const Result<AppPage<IcuPatientSummary>>.failure(
        AppFailure.network(),
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('mobile + dark: read-only chrome hides write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );
    expect(find.textContaining('Active ICU'), findsWidgets);
    expect(find.text('Assign ICU bed'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
    expect(find.byType(AppSearchBar), findsOneWidget);
  });

  testWidgets('desktop + light: write ∪ mounts Assign bed', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );
    expect(find.text('Assign ICU bed'), findsWidgets);
    expect(find.text('Ada Active'), findsOneWidget);
  });

  testWidgets('detail write actions absent for read-only; print remains', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpActiveTab(tester, repository: repository, accessPolicy: reader);

    await tester.tap(find.text('Ada Active'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Print summary'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.text('Assign ICU bed'),
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
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.textContaining('End'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'authorized writer detail: complementary writes present; Assign bed omitted as next-action',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        board: const <IcuPatientSummary>[_needsBed],
      );

      await tester.tap(find.text('Ada Active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Print summary'), findsOneWidget);
      // Row next-action was Assign bed — omitted from detail Quick Actions.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Assign ICU bed'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Observation'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.textContaining('End'),
        ),
        findsWidgets,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('integration: Active tab selected via default /icu deep link', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      initialLocation: '/icu',
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any(
        (IcuBoardQuery q) =>
            q.scope == IcuBoardScope.active || q.scope == null,
      ),
      isTrue,
    );
    expect(find.textContaining('Active ICU'), findsWidgets);
  });

  testWidgets(
    '∪ navigate: discharge-planned Open clearance remains for read-only',
    (WidgetTester tester) async {
      const IcuPatientSummary dischargePlanned = IcuPatientSummary(
        id: 'ADM-ACT-CLR',
        admissionId: 'ADM-ACT-CLR',
        displayId: 'ADM-CLR',
        patientDisplayName: 'Clearance Ready',
        icuStatus: 'ACTIVE',
        bedLabel: 'ICU-9',
        hasActiveBed: true,
        dischargeStatus: 'PLANNED',
        encounterId: 'ENC-ACT-CLR',
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        board: const <IcuPatientSummary>[dischargePlanned],
      );

      expect(find.text('Clearance Ready'), findsOneWidget);
      expect(find.text('Open discharge clearance'), findsWidgets);
      expect(find.text('Assign ICU bed'), findsNothing);
      expect(find.text('Observation'), findsNothing);
    },
  );
}
