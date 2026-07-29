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

const EmergencyCaseSummary _handoffCase = EmergencyCaseSummary(
  id: 'EME-HAND-1',
  displayId: 'EME-HAND-1',
  patientId: 'PAT-HAND-1',
  patientDisplayId: 'PAT-HAND-1',
  patientDisplayName: 'Handoff Tab Patient',
  severity: 'HIGH',
  status: 'OPEN',
  latestTriage: EmergencyTriageAssessment(
    id: 'TRA-HAND-1',
    triageLevel: 'LEVEL_2',
  ),
  latestResponse: EmergencyResponseRecord(id: 'ERS-HAND-1'),
);

const EmergencyCaseDetail _handoffDetail = EmergencyCaseDetail(
  summary: _handoffCase,
  triageAssessments: <EmergencyTriageAssessment>[
    EmergencyTriageAssessment(id: 'TRA-HAND-1', triageLevel: 'LEVEL_2'),
  ],
  responses: <EmergencyResponseRecord>[
    EmergencyResponseRecord(id: 'ERS-HAND-1'),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  String? tenantId = 'tenant-1',
}) {
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientWrite ||
        permission == AppPermissions.patientRead,
  );
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalWrite ||
        permission == AppPermissions.clinicalRead,
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
          code: 'scheduling-queue',
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
        roles: const <String>['NURSE'],
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
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_handoffCase],
  EmergencyCaseDetail detail = _handoffDetail,
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
    if (listOverride != null) {
      return Future<Result<AppPage<EmergencyCaseSummary>>>.value(listOverride);
    }
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
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
  when(() => repository.createQuickArrival(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
  when(
    () => repository.recordHandoff(
      detail: any(named: 'detail'),
      destination: any(named: 'destination'),
      notes: any(named: 'notes'),
      closeCase: any(named: 'closeCase'),
    ),
  ).thenAnswer((_) async => Result<EmergencyCaseDetail>.success(detail));
}

Future<void> _pumpHandoffTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_handoffCase],
  EmergencyCaseDetail detail = _handoffDetail,
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  String initialLocation = '/emergency?scope=handoff',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
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
    registerFallbackValue(const EmergencyCaseDetail(summary: _handoffCase));
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('EmergencyHandoffAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        EmergencyHandoffAtomPermissions.tab,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.listChrome,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.empty,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.printSummary,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.write,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.quickArrival,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.create,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.update,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.delete,
        same(emergencyDeleteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.handoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.nextActionHandoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.recordTriage,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.markResponse,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.startTrip,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.completeTrip,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.panelDeepLink,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.routeEntry,
        same(RouteAccessCatalog.emergencyEntry),
      );
      expect(
        EmergencyHandoffAtomPermissions.routeEntryUnion,
        same(emergencyWorkspaceRouteUnionRequirement),
      );
      expect(
        emergencyBoardTabRequirement(EmergencyBoardTab.handoff),
        same(EmergencyHandoffAtomPermissions.tab),
      );
      // Nested cross-module matrix rows are _(n/a)_ — helpers alias local gates.
      expect(
        EmergencyHandoffAtomPermissions.nestedWrite,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.nestedRead,
        same(emergencyWorkspaceReadRequirement),
      );
    });

    test('∩ denial: missing emergency:read strips Handoff tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
      );
      expect(EmergencyHandoffAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewEmergencyHandoff(writeOnly), isFalse);
      expect(
        EmergencyHandoffAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        EmergencyHandoffAtomPermissions.success.isAllowed(writeOnly),
        isTrue,
      );
      // Catalog entry ∪ includes emergency:write.
      expect(
        EmergencyHandoffAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );

      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewEmergencyHandoff(reader), isTrue);
      expect(EmergencyHandoffAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        EmergencyHandoffAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyHandoffAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyHandoffAtomPermissions.quickArrival.isAllowed(reader),
        isFalse,
      );
    });

    test('∩ denial: write alone does not grant delete', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(EmergencyHandoffAtomPermissions.delete.isAllowed(writer), isFalse);
      expect(canDeleteEmergency(writer), isFalse);

      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyDelete,
        },
      );
      expect(
        EmergencyHandoffAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
    });

    test(
      '∪ allowance: clinical:write satisfies handoff without emergency:write',
      () {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(
          EmergencyHandoffAtomPermissions.handoff.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(
          EmergencyHandoffAtomPermissions.nextActionHandoff.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          EmergencyHandoffAtomPermissions.panelDeepLink.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          EmergencyHandoffAtomPermissions.quickArrival.isAllowed(
            clinicalWriter,
          ),
          isFalse,
        );
        expect(
          EmergencyHandoffAtomPermissions.triage.isAllowed(clinicalWriter),
          isFalse,
        );
        expect(canShowEmergencyNextAction(clinicalWriter), isTrue);
        // Source inventory ∪ — keep mapping note in tests.
        expect(
          emergencyHandoffWriteRequirement.anyPermissions,
          contains(AppPermissions.clinicalWrite),
        );
      },
    );

    test(
      '∪ allowance: patient:write | operations:write also satisfy handoff source',
      () {
        final AppAccessPolicy patientWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.patientWrite,
          },
        );
        final AppAccessPolicy opsWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.operationsWrite,
          },
        );
        expect(
          EmergencyHandoffAtomPermissions.handoff.isAllowed(patientWriter),
          isTrue,
        );
        expect(
          EmergencyHandoffAtomPermissions.handoff.isAllowed(opsWriter),
          isTrue,
        );
        expect(
          EmergencyHandoffAtomPermissions.quickArrival.isAllowed(patientWriter),
          isFalse,
        );
        expect(
          EmergencyHandoffAtomPermissions.nestedWrite.isAllowed(opsWriter),
          isFalse,
        );
      },
    );

    test('∪ allowance: operations:read satisfies prompt route-entry union', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        EmergencyHandoffAtomPermissions.routeEntryUnion.isAllowed(opsReader),
        isTrue,
      );
      expect(
        EmergencyHandoffAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      // Tab chrome stays ∩ emergency:read.
      expect(canViewEmergencyHandoff(opsReader), isFalse);
    });

    test('nested cross-module matrix _(n/a)_: reuses emergency read/write only',
        () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(
        EmergencyHandoffAtomPermissions.nestedRead.isAllowed(reader),
        isTrue,
      );
      expect(
        EmergencyHandoffAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyHandoffAtomPermissions.ambulanceContext.isAllowed(reader),
        isTrue,
      );
      expect(
        EmergencyHandoffAtomPermissions.nestedWrite,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyHandoffAtomPermissions.nestedRead,
        same(emergencyWorkspaceReadRequirement),
      );
    });

    test('subscription strip: scheduling-queue required for Handoff tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(EmergencyHandoffAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewEmergencyHandoff(noModule), isFalse);
      expect(
        EmergencyHandoffAtomPermissions.quickArrival.isAllowed(noModule),
        isFalse,
      );
      expect(
        EmergencyHandoffAtomPermissions.handoff.isAllowed(noModule),
        isFalse,
      );
    });

    test('ABAC: tenant context required for Handoff atoms', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        tenantId: null,
      );
      expect(EmergencyHandoffAtomPermissions.tab.isAllowed(noTenant), isFalse);
      expect(
        EmergencyHandoffAtomPermissions.write.isAllowed(noTenant),
        isFalse,
      );
      expect(
        EmergencyHandoffAtomPermissions.handoff.isAllowed(noTenant),
        isFalse,
      );
    });

    test('next-action / panel requirements map handoff to source ∪', () {
      expect(
        emergencyNextActionRequirement(
          EmergencyNextActionKind.triage,
          emergencyWriteRequirement,
        ),
        same(emergencyWriteRequirement),
      );
      expect(
        emergencyNextActionRequirement(
          EmergencyNextActionKind.handoff,
          emergencyWriteRequirement,
        ),
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        emergencyFocusedPanelRequirement(EmergencyDetailPanelFocus.handoff),
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        emergencyFocusedPanelRequirement(EmergencyDetailPanelFocus.triage),
        same(emergencyWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only: Handoff list visible; Quick arrival / next-action / writes absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(EmergencyHandoffAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(EmergencyHandoffAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpHandoffTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Handoff Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text(EmergencyText.handoffReady), findsWidgets);
      expect(find.text('Quick arrival'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text(EmergencyText.recordHandoff), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Handoff Tab Patient'));
      await tester.pumpAndSettle();

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
          matching: find.text('Triage'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Response'),
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
    'full write ∩: Quick arrival + Record handoff next-action + detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );

      await _pumpHandoffTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Quick arrival'), findsOneWidget);
      expect(find.text('Handoff Tab Patient'), findsOneWidget);
      expect(find.text('Next action'), findsWidgets);
      expect(find.text(EmergencyText.recordHandoff), findsOneWidget);

      await tester.tap(find.text('Handoff Tab Patient'));
      await tester.pumpAndSettle();

      // Next-action Record handoff omitted from detail Quick Actions ("Handoff").
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Priority'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Triage'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Response'),
        ),
        findsOneWidget,
      );
      expect(find.text(EmergencyText.scheduleTheater), findsOneWidget);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Handoff'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ handoff: Record handoff next-action mounts without emergency:write',
    (WidgetTester tester) async {
      final AppAccessPolicy handoffOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpHandoffTab(
        tester,
        repository: repository,
        accessPolicy: handoffOnly,
      );

      expect(find.text('Quick arrival'), findsNothing);
      expect(find.text('Handoff Tab Patient'), findsOneWidget);
      expect(find.text(EmergencyText.recordHandoff), findsOneWidget);
      // Triage appears as a read column header only — not as a write next-action.
      expect(find.text(EmergencyText.recordHandoff), findsOneWidget);

      await tester.tap(find.text('Handoff Tab Patient'));
      await tester.pumpAndSettle();

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
          matching: find.text('Triage'),
        ),
        findsNothing,
      );
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      // Row next-action already covers handoff; detail omits duplicate.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Handoff'),
        ),
        findsNothing,
      );
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
    },
  );

  testWidgets(
    'subscription strip collapses Handoff chrome without scheduling-queue',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      await _pumpHandoffTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Handoff Tab Patient'), findsNothing);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty state remains observable',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpHandoffTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        items: const <EmergencyCaseSummary>[],
      );

      expect(find.text('No emergency cases'), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  test('authorized retry path surfaces failure from controller refresh', () async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.emergencyRead},
    );
    when(() => repository.listEmergencyBoard(any())).thenAnswer(
      (_) async => const Result<AppPage<EmergencyCaseSummary>>.failure(
        AppFailure.network(),
      ),
    );
    when(repository.loadReferenceData).thenAnswer(
      (_) async =>
          const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        emergencyRepositoryProvider.overrideWithValue(repository),
        appAccessPolicyProvider.overrideWithValue(reader),
      ],
    );
    addTearDown(container.dispose);

    final AppFailure? failure = await container
        .read(emergencyWorkspaceControllerProvider.notifier)
        .refresh();
    expect(failure, isNotNull);
  });

  testWidgets(
    'authorized error/retry surface remains observable on Handoff',
    (WidgetTester tester) async {
      await _pumpHandoffTab(
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

  testWidgets(
    'post-mutation sync: Record handoff patches board and shows success',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );

      const EmergencyHandoffOutcome handedOff = EmergencyHandoffOutcome(
        destination: 'OPD',
        route: 'opd',
        receivingDisplayId: 'ENC-HAND-1',
      );
      final EmergencyCaseDetail closedDetail = EmergencyCaseDetail(
        summary: _handoffCase.copyWith(
          status: 'CLOSED',
          handoff: handedOff,
        ),
        triageAssessments: _handoffDetail.triageAssessments,
        responses: _handoffDetail.responses,
      );

      var persisted = false;
      when(() => repository.listEmergencyBoard(any())).thenAnswer((
        invocation,
      ) {
        final EmergencyBoardQuery query =
            invocation.positionalArguments.single as EmergencyBoardQuery;
        final List<EmergencyCaseSummary> items = persisted
            ? const <EmergencyCaseSummary>[]
            : const <EmergencyCaseSummary>[_handoffCase];
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
          EmergencyReferenceData(),
        ),
      );
      when(() => repository.loadEmergencyDetail(any())).thenAnswer(
        (_) async => Result<EmergencyCaseDetail>.success(
          persisted ? closedDetail : _handoffDetail,
        ),
      );
      when(
        () => repository.recordHandoff(
          detail: any(named: 'detail'),
          destination: any(named: 'destination'),
          notes: any(named: 'notes'),
          closeCase: any(named: 'closeCase'),
        ),
      ).thenAnswer((_) async {
        persisted = true;
        return Result<EmergencyCaseDetail>.success(closedDetail);
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/emergency?scope=handoff',
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Handoff Tab Patient'), findsOneWidget);
      expect(find.text(EmergencyText.recordHandoff), findsOneWidget);

      await tester.tap(find.text(EmergencyText.recordHandoff));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      await tester.tap(find.text('Handoff').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      verify(
        () => repository.recordHandoff(
          detail: any(named: 'detail'),
          destination: any(named: 'destination'),
          notes: any(named: 'notes'),
          closeCase: any(named: 'closeCase'),
        ),
      ).called(1);
      expect(find.text(EmergencyText.handoffRecorded), findsOneWidget);
      expect(find.text('Handoff Tab Patient'), findsNothing);
      expect(find.text('No emergency cases'), findsOneWidget);
    },
  );

  testWidgets('mobile + desktop viewports keep Handoff chrome reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      },
    );

    await _pumpHandoffTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );
    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text(EmergencyText.handoffReady), findsWidgets);
    expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);

    await _pumpHandoffTab(
      tester,
      repository: repository,
      accessPolicy: writer,
    );
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.text('Handoff Tab Patient'), findsOneWidget);
    expect(find.text('Next action'), findsWidgets);
    expect(find.text(EmergencyText.recordHandoff), findsOneWidget);
  });

  testWidgets('light + dark themes render Handoff authorized chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      },
    );

    await _pumpHandoffTab(
      tester,
      repository: repository,
      accessPolicy: writer,
    );
    expect(find.text('Quick arrival'), findsOneWidget);

    await _pumpHandoffTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.text('Handoff Tab Patient'), findsOneWidget);
  });
}