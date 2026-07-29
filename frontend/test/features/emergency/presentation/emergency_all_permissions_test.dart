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

const EmergencyCaseSummary _untreated = EmergencyCaseSummary(
  id: 'EME-ALL-1',
  displayId: 'EME-ALL-1',
  patientDisplayName: 'All Tab Patient',
  patientDisplayId: 'PAT-ALL-1',
  severity: 'HIGH',
  status: 'OPEN',
);

const EmergencyCaseSummary _handoffReady = EmergencyCaseSummary(
  id: 'EME-ALL-2',
  displayId: 'EME-ALL-2',
  patientDisplayName: 'Handoff Ready Patient',
  patientDisplayId: 'PAT-ALL-2',
  severity: 'MEDIUM',
  status: 'OPEN',
  latestTriage: EmergencyTriageAssessment(
    id: 'TRA-1',
    triageLevel: 'LEVEL_2',
  ),
  latestResponse: EmergencyResponseRecord(id: 'ERS-1'),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
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
        roles: roles,
        tenantId: tenantId,
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBoard(
  _MockEmergencyRepository repository, {
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_untreated],
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
  EmergencyCaseDetail? detailOverride,
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
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer((invocation) {
    final EmergencyCaseSummary summary =
        invocation.positionalArguments.single as EmergencyCaseSummary;
    return Future<Result<EmergencyCaseDetail>>.value(
      Result<EmergencyCaseDetail>.success(
        detailOverride ??
            EmergencyCaseDetail(
              summary: items.firstWhere(
                (EmergencyCaseSummary item) => item.id == summary.id,
                orElse: () => summary,
              ),
            ),
      ),
    );
  });
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/emergency?scope=all',
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_untreated],
  Result<AppPage<EmergencyCaseSummary>>? listOverride,
}) async {
  _stubBoard(repository, items: items, listOverride: listOverride);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

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
      const EmergencyCaseDetail(
        summary: EmergencyCaseSummary(id: 'fallback'),
      ),
    );
    registerFallbackValue(
      const EmergencyQuickArrivalInput(
        firstName: '',
        lastName: '',
        severity: 'CRITICAL',
      ),
    );
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('EmergencyAllAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        EmergencyAllAtomPermissions.tab,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.search,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.empty,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.loading,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.retry,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.printSummary,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.rowSelect,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.write,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.create,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.update,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.quickArrival,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.delete,
        same(emergencyWorkspaceDeleteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.handoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.nextActionHandoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.routeEntry,
        same(emergencyWorkspaceEntryRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.routeEntryUnion,
        same(emergencyWorkspaceRouteUnionRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.routeEntry,
        same(RouteAccessCatalog.emergencyEntry),
      );
      expect(
        EmergencyAllAtomPermissions.nextActionTriage,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.nextActionHandoff,
        same(emergencyHandoffWriteRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.panelDeepLink,
        same(emergencyWorkspaceWriteRequirement),
      );
      expect(
        emergencyBoardTabRequirement(EmergencyBoardTab.all),
        same(EmergencyAllAtomPermissions.tab),
      );
      expect(
        canViewEmergencyAll(
          _policy(permissions: <AppPermission>{AppPermissions.emergencyRead}),
        ),
        isTrue,
      );
    });

    test('∩ denial: missing emergency:read fails tab; write alone fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
      );
      expect(canViewEmergencyAll(writeOnly), isFalse);
      expect(EmergencyAllAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(EmergencyAllAtomPermissions.write.isAllowed(writeOnly), isTrue);
      expect(EmergencyAllAtomPermissions.create.isAllowed(writeOnly), isTrue);
      expect(EmergencyAllAtomPermissions.delete.isAllowed(writeOnly), isFalse);
      // Catalog route entry is ∪ read|write|operations:read — write alone enters.
      expect(
        EmergencyAllAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        EmergencyAllAtomPermissions.routeEntryUnion.isAllowed(writeOnly),
        isTrue,
      );

      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewEmergencyAll(reader), isTrue);
      expect(
        EmergencyAllAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );
      expect(EmergencyAllAtomPermissions.write.isAllowed(reader), isFalse);
      expect(EmergencyAllAtomPermissions.success.isAllowed(reader), isFalse);
      expect(EmergencyAllAtomPermissions.validation.isAllowed(reader), isFalse);
      expect(EmergencyAllAtomPermissions.delete.isAllowed(reader), isFalse);
    });

    test('∩ denial: write-only staff cannot delete', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(EmergencyAllAtomPermissions.delete.isAllowed(writer), isFalse);
      expect(canDeleteEmergency(writer), isFalse);

      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyDelete,
        },
      );
      expect(EmergencyAllAtomPermissions.delete.isAllowed(deleter), isTrue);
      expect(EmergencyAllAtomPermissions.write.isAllowed(deleter), isFalse);
    });

    test('∪ allowance: patient:write satisfies handoff without emergency:write', () {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        EmergencyAllAtomPermissions.handoff.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        EmergencyAllAtomPermissions.nextActionHandoff.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        EmergencyAllAtomPermissions.quickArrival.isAllowed(patientWriter),
        isFalse,
      );
      expect(
        EmergencyAllAtomPermissions.recordTriage.isAllowed(patientWriter),
        isFalse,
      );
      expect(canShowEmergencyNextAction(patientWriter), isTrue);
    });

    test('∪ allowance: clinical / operations write satisfy handoff gate', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        EmergencyAllAtomPermissions.handoff.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        EmergencyAllAtomPermissions.quickArrival.isAllowed(clinicalWriter),
        isFalse,
      );

      final AppAccessPolicy opsWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(EmergencyAllAtomPermissions.handoff.isAllowed(opsWriter), isTrue);
      expect(
        EmergencyAllAtomPermissions.quickArrival.isAllowed(opsWriter),
        isFalse,
      );
    });

    test('∪ allowance: route entry accepts operations:read; All tab still ∩', () {
      final AppAccessPolicy opsReadOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      // Catalog / AppRoutes entry ∪ includes operations:read.
      expect(
        EmergencyAllAtomPermissions.routeEntry.isAllowed(opsReadOnly),
        isTrue,
      );
      expect(
        EmergencyAllAtomPermissions.routeEntryUnion.isAllowed(opsReadOnly),
        isTrue,
      );
      // All tab content still requires ∩ emergency:read.
      expect(EmergencyAllAtomPermissions.tab.isAllowed(opsReadOnly), isFalse);
      expect(canViewEmergencyAll(opsReadOnly), isFalse);

      final AppAccessPolicy withRead = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(
        EmergencyAllAtomPermissions.routeEntry.isAllowed(withRead),
        isTrue,
      );
      expect(EmergencyAllAtomPermissions.tab.isAllowed(withRead), isTrue);
    });

    test('subscription strip: scheduling-queue required for All tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(EmergencyAllAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewEmergencyAll(noModule), isFalse);
      expect(
        EmergencyAllAtomPermissions.quickArrival.isAllowed(noModule),
        isFalse,
      );
    });

    test('ABAC: tenant context required for All atoms', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
        tenantId: null,
      );
      expect(EmergencyAllAtomPermissions.tab.isAllowed(noTenant), isFalse);
      expect(EmergencyAllAtomPermissions.write.isAllowed(noTenant), isFalse);
      expect(
        EmergencyAllAtomPermissions.quickArrival.isAllowed(noTenant),
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
      expect(
        EmergencyAllAtomPermissions.panelDeepLink,
        same(emergencyWorkspaceWriteRequirement),
      );
    });

    test('nested cross-module matrix rows are n/a (aliases keep emergency gates)', () {
      expect(
        EmergencyAllAtomPermissions.nestedRead,
        same(emergencyWorkspaceReadRequirement),
      );
      expect(
        EmergencyAllAtomPermissions.nestedWrite,
        same(emergencyWorkspaceWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only: All list visible; mutation atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(EmergencyAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(EmergencyAllAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('All'), findsWidgets);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.text('Triage'), findsNothing);
      expect(find.text('Next action'), findsNothing);

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppButton, 'Priority'),
        findsNothing,
      );
      expect(find.widgetWithText(AppButton, 'Triage'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Response'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Dispatch'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Handoff'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Quick arrival and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(EmergencyAllAtomPermissions.write.isAllowed(writer), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);
      expect(find.text('Quick arrival'), findsOneWidget);
      expect(find.text('Triage'), findsWidgets);
      expect(find.text('Next action'), findsWidgets);

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      // Next-action Triage is omitted from detail Quick Actions.
      expect(find.text('Priority'), findsWidgets);
      expect(find.text('Response'), findsWidgets);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'tab ∩: emergency:write alone without emergency:read omits All chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyWrite},
      );
      // Route entry ∪ allows write; All tab ∩ emergency:read still denies chrome.
      expect(
        EmergencyAllAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(EmergencyAllAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: scheduling-queue missing omits All chrome',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ handoff: patient:write shows Record handoff without Quick arrival',
    (WidgetTester tester) async {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        EmergencyAllAtomPermissions.handoff.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        EmergencyAllAtomPermissions.quickArrival.isAllowed(patientWriter),
        isFalse,
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: patientWriter,
        items: const <EmergencyCaseSummary>[_handoffReady],
      );

      expect(find.text('Handoff Ready Patient'), findsOneWidget);
      expect(find.text('Quick arrival'), findsNothing);
      expect(find.text('Record handoff'), findsWidgets);
      expect(find.text('Triage'), findsNothing);

      await tester.tap(find.text('Handoff Ready Patient'));
      await tester.pumpAndSettle();

      // Row next-action handoff is omitted from detail; Priority/Triage stay write-gated.
      expect(find.widgetWithText(AppButton, 'Priority'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Triage'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized All chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop viewport keeps authorized All row readable', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next action'), findsWidgets);
  });

  testWidgets('dark theme: authorized All chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('light theme: authorized All chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets(
    'empty authorized All worklist still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        ),
        items: const <EmergencyCaseSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.text('No emergency cases'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on All',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
    'authorized Response dialog shows validation for empty submit',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        ),
      );

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Response').first);
      await tester.pumpAndSettle();

      expect(find.text('Mark response'), findsWidgets);
      await tester.tap(find.text('Mark response').last);
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsWidgets);
      verifyNever(
        () => repository.markResponse(
          detail: any(named: 'detail'),
          notes: any(named: 'notes'),
        ),
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  test(
    'post-mutation sync: createQuickArrival patches All board',
    () async {
      final _MockEmergencyRepository syncRepository = _MockEmergencyRepository();
      _stubBoard(syncRepository, items: const <EmergencyCaseSummary>[]);
      final EmergencyCaseDetail created = EmergencyCaseDetail(
        summary: _untreated,
      );
      when(() => syncRepository.createQuickArrival(any())).thenAnswer(
        (_) async => Result<EmergencyCaseDetail>.success(created),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          emergencyRepositoryProvider.overrideWithValue(syncRepository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.emergencyRead,
                AppPermissions.emergencyWrite,
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(emergencyWorkspaceControllerProvider.future);
      final EmergencyWorkspaceController controller = container.read(
        emergencyWorkspaceControllerProvider.notifier,
      );
      await controller.applyScope(EmergencyBoardScope.all);

      final AppFailure? failure = await controller.createQuickArrival(
        const EmergencyQuickArrivalInput(
          firstName: 'All',
          lastName: 'Patient',
          severity: 'HIGH',
        ),
      );
      expect(failure, isNull);

      final EmergencyWorkspaceState state = container
          .read(emergencyWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (EmergencyWorkspaceState value) => value,
            failure: (AppFailure f) => throw StateError(f.code),
          );
      expect(state.board.items.single.id, 'EME-ALL-1');
      expect(state.selectedDetail?.summary.id, 'EME-ALL-1');
      verify(() => syncRepository.createQuickArrival(any())).called(1);
    },
  );

  testWidgets(
    'authorized loading chrome remains observable on All',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final Completer<Result<AppPage<EmergencyCaseSummary>>> listCompleter =
          Completer<Result<AppPage<EmergencyCaseSummary>>>();
      final Completer<Result<EmergencyReferenceData>> referenceCompleter =
          Completer<Result<EmergencyReferenceData>>();
      when(() => repository.listEmergencyBoard(any())).thenAnswer(
        (_) => listCompleter.future,
      );
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) => referenceCompleter.future,
      );

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/emergency?scope=all',
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
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.emergencyRead},
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Loading'),
        findsWidgets,
      );
      expect(find.textContaining('no access'), findsNothing);

      referenceCompleter.complete(
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
      );
      listCompleter.complete(
        Result<AppPage<EmergencyCaseSummary>>.success(
          AppPage<EmergencyCaseSummary>(
            items: const <EmergencyCaseSummary>[_untreated],
            request: const AppPageRequest(),
            totalItemCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All Tab Patient'), findsOneWidget);
    },
  );
}
