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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyCaseSummary _criticalCase = EmergencyCaseSummary(
  id: 'EME-CRIT-1',
  displayId: 'EME-CRIT-1',
  patientDisplayId: 'PAT-CRIT-1',
  patientDisplayName: 'Critical Tab Patient',
  severity: 'CRITICAL',
  status: 'OPEN',
  createdAt: null,
);

const EmergencyCaseDetail _criticalDetail = EmergencyCaseDetail(
  summary: _criticalCase,
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
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_criticalCase],
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  Result<EmergencyReferenceData>? referenceOverride,
  EmergencyCaseDetail? detail,
  Result<EmergencyCaseDetail>? createOverride,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((
    invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Result<AppPage<EmergencyCaseSummary>>.success(
      AppPage<EmergencyCaseSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        referenceOverride ??
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer((invocation) {
    final EmergencyCaseSummary summary =
        invocation.positionalArguments.single as EmergencyCaseSummary;
    return Future<Result<EmergencyCaseDetail>>.value(
      Result<EmergencyCaseDetail>.success(
        detail ??
            EmergencyCaseDetail(
              summary: summary.id == _criticalCase.id
                  ? _criticalCase
                  : summary,
            ),
      ),
    );
  });
  when(() => repository.createQuickArrival(any())).thenAnswer((_) async {
    return createOverride ??
        const Result<EmergencyCaseDetail>.success(_criticalDetail);
  });
  when(
    () => repository.recordTriage(
      detail: any(named: 'detail'),
      triageLevel: any(named: 'triageLevel'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer((_) async {
    const EmergencyTriageAssessment triage = EmergencyTriageAssessment(
      id: 'TRA-CRIT-1',
      triageLevel: 'LEVEL_1',
    );
    return Result<EmergencyCaseDetail>.success(
      _criticalDetail.copyWith(
        summary: _criticalCase.copyWith(latestTriage: triage),
        triageAssessments: const <EmergencyTriageAssessment>[triage],
      ),
    );
  });
}

Future<void> _pumpCriticalTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _criticalCase,
  ],
  String initialLocation = '/emergency?scope=critical',
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  Result<EmergencyReferenceData>? referenceOverride,
  EmergencyCaseDetail? detail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
    listOverride: listOverride,
    referenceOverride: referenceOverride,
    detail: detail,
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
  // Avoid pumpAndSettle — emergency adaptive polling keeps the frame busy.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
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
    registerFallbackValue(const EmergencyCaseDetail(summary: _criticalCase));
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('EmergencyCriticalAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        EmergencyCriticalAtomPermissions.tab,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.criticalChip,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.empty,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.loading,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.retry,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.detail,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.printSummary,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.openInReceivingModule,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.write,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.quickArrival,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.nextAction,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.nextActionTriage,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.updatePriority,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.recordTriage,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.create,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.update,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.delete,
        same(emergencyDeleteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.handoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.nextActionHandoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.panelDeepLink,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.routeEntry,
        same(RouteAccessCatalog.emergencyEntry),
      );
      expect(
        emergencyWriteRequirementForTab(EmergencyBoardTab.critical),
        same(EmergencyCriticalAtomPermissions.write),
      );
      expect(
        emergencyDetailReadRequirement(EmergencyBoardTab.critical),
        same(EmergencyCriticalAtomPermissions.detail),
      );
      expect(
        emergencyBoardTabRequirement(EmergencyBoardTab.critical),
        same(EmergencyCriticalAtomPermissions.tab),
      );
    });

    test('nested cross-module matrix _(n/a)_: no extra module keys', () {
      expect(
        EmergencyCriticalAtomPermissions.nestedWrite,
        same(emergencyWriteRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.nestedRead,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyCriticalAtomPermissions.nestedWrite.anyPermissions,
        isEmpty,
      );
      expect(
        EmergencyCriticalAtomPermissions.nestedRead.allPermissions,
        <AppPermission>[AppPermissions.emergencyRead],
      );
    });

    test('∩ denial: missing emergency:read strips Critical tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
      );
      expect(EmergencyCriticalAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewEmergencyCritical(writeOnly), isFalse);
      expect(
        EmergencyCriticalAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        EmergencyCriticalAtomPermissions.success.isAllowed(writeOnly),
        isTrue,
      );
      // Catalog entry is ∪ read|write|operations:read — write alone enters.
      expect(
        EmergencyCriticalAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        EmergencyCriticalAtomPermissions.routeEntryUnion.isAllowed(writeOnly),
        isTrue,
      );

      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewEmergencyCritical(reader), isTrue);
      expect(
        EmergencyCriticalAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );
      expect(EmergencyCriticalAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        EmergencyCriticalAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(
        EmergencyCriticalAtomPermissions.delete.isAllowed(reader),
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
      expect(EmergencyCriticalAtomPermissions.delete.isAllowed(writer), isFalse);
      expect(canDeleteEmergency(writer), isFalse);

      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyDelete,
        },
      );
      expect(
        EmergencyCriticalAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
    });

    test('∪ allowance: patient:write satisfies handoff without emergency:write', () {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        EmergencyCriticalAtomPermissions.handoff.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        EmergencyCriticalAtomPermissions.nextActionHandoff.isAllowed(
          patientWriter,
        ),
        isTrue,
      );
      expect(
        EmergencyCriticalAtomPermissions.quickArrival.isAllowed(patientWriter),
        isFalse,
      );
      expect(
        EmergencyCriticalAtomPermissions.triage.isAllowed(patientWriter),
        isFalse,
      );
      expect(canShowEmergencyNextAction(patientWriter), isTrue);
    });

    test('∪ allowance: operations:read satisfies catalog route-entry', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        EmergencyCriticalAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      expect(
        EmergencyCriticalAtomPermissions.routeEntryUnion.isAllowed(opsReader),
        isTrue,
      );
      // Tab chrome stays ∩ emergency:read.
      expect(canViewEmergencyCritical(opsReader), isFalse);
    });

    test('subscription strip: scheduling-queue required for Critical tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(EmergencyCriticalAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewEmergencyCritical(noModule), isFalse);
      expect(
        EmergencyCriticalAtomPermissions.quickArrival.isAllowed(noModule),
        isFalse,
      );
    });

    test('ABAC: tenant context required for Critical atoms', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        tenantId: null,
      );
      expect(EmergencyCriticalAtomPermissions.tab.isAllowed(noTenant), isFalse);
      expect(
        EmergencyCriticalAtomPermissions.write.isAllowed(noTenant),
        isFalse,
      );
    });

    test('next-action requirement maps handoff to source ∪', () {
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
        emergencyFocusedPanelRequirement(EmergencyDetailPanelFocus.triage),
        same(emergencyWriteRequirement),
      );
      expect(
        emergencyFocusedPanelRequirement(EmergencyDetailPanelFocus.handoff),
        same(emergencyHandoffWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only: Critical list visible; Quick arrival / next-action / writes absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(EmergencyCriticalAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(EmergencyCriticalAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Critical Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Critical'), findsWidgets);
      expect(find.text('Quick arrival'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Triage'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Critical Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Response'), findsNothing);
      expect(find.text('Record handoff'), findsNothing);
      expect(find.text(EmergencyText.scheduleTheater), findsNothing);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Quick arrival + Triage next-action + detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Quick arrival'), findsOneWidget);
      expect(find.text('Critical Tab Patient'), findsOneWidget);
      expect(find.text('Next action'), findsWidgets);
      expect(find.text('Triage'), findsOneWidget);

      await tester.tap(find.text('Critical Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Next-action Triage omitted from detail Quick Actions.
      expect(find.text(EmergencyText.scheduleTheater), findsOneWidget);
      expect(find.text('Response'), findsWidgets);
      expect(find.text(EmergencyText.printSummary), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ handoff: Record handoff next-action mounts without emergency:write',
    (WidgetTester tester) async {
      final EmergencyCaseSummary ready = EmergencyCaseSummary(
        id: 'EME-HAND-1',
        displayId: 'EME-HAND-1',
        patientDisplayName: 'Handoff Ready Critical',
        severity: 'CRITICAL',
        status: 'OPEN',
        latestTriage: const EmergencyTriageAssessment(
          id: 't1',
          triageLevel: 'LEVEL_1',
        ),
        latestResponse: const EmergencyResponseRecord(
          id: 'r1',
          notes: 'Stabilized',
        ),
      );
      final AppAccessPolicy handoffOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: handoffOnly,
        items: <EmergencyCaseSummary>[ready],
      );

      expect(find.text('Quick arrival'), findsNothing);
      expect(find.text('Handoff Ready Critical'), findsOneWidget);
      expect(find.text('Record handoff'), findsOneWidget);
      expect(find.text('Triage'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip collapses Critical chrome without scheduling-queue',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Critical Tab Patient'), findsNothing);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty state remains observable for Critical readers',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpCriticalTab(
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

  testWidgets(
    'authorized write path: Critical next-action Triage remains mounted',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Triage'), findsOneWidget);
      expect(find.text('Quick arrival'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile + desktop viewports keep Critical chrome reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      },
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
    );
    expect(find.text('Next action'), findsWidgets);
    expect(find.text('Triage'), findsOneWidget);
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.text('Critical Tab Patient'), findsOneWidget);
  });

  testWidgets('light + dark themes render Critical authorized chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      },
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.light,
    );
    expect(find.text('Quick arrival'), findsOneWidget);

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Quick arrival'), findsOneWidget);
    expect(find.text('Critical Tab Patient'), findsOneWidget);
  });

  testWidgets(
    'tab ∩: emergency:write alone without emergency:read omits Critical chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
      );
      expect(
        EmergencyCriticalAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(EmergencyCriticalAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Critical Tab Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
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
    expect(
      EmergencyCriticalAtomPermissions.retry.isAllowed(reader),
      isTrue,
    );
  });

  testWidgets(
    'post-mutation sync: Quick arrival patches Critical board',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        items: const <EmergencyCaseSummary>[],
      );

      expect(find.text('No emergency cases'), findsOneWidget);
      expect(find.text('Quick arrival'), findsOneWidget);

      await tester.tap(find.text('Quick arrival'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextFormField).at(0), 'Critical');
      await tester.enterText(find.byType(TextFormField).at(1), 'Arrival');
      await tester.tap(find.text(EmergencyText.openCase));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Critical Tab Patient'), findsOneWidget);
      expect(find.text('Arrival opened'), findsOneWidget);
      verify(() => repository.createQuickArrival(any())).called(1);
    },
  );
}
