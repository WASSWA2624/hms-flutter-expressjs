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
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/opd_access.dart';
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const OpdQueueEntry _queueEntry = OpdQueueEntry(
  id: 'queue-opd-1',
  publicId: 'QUE-OPD-1',
  patientDisplayName: 'Queue Patient',
  patientIdentifier: 'PAT-QUE',
  status: 'CONFIRMED',
  providerUserId: 'USR-DOC-1',
  providerDisplayName: 'Dr Queue',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientRead ||
        permission == AppPermissions.patientWrite,
  );
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
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
          code: opdSchedulingQueueModule,
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

AppAccessPolicy _readerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.clinicalRead,
    },
    roles: const <String>['CUSTOM_READER'],
  );
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
    },
    roles: const <String>['RECEPTIONIST', 'NURSE', 'DOCTOR'],
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(
        code: opdSchedulingQueueModule,
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'inpatient-bed-management',
        licenseStatus: 'ACTIVE',
      ),
    ],
  );
}

void _stubWorkspace(
  _MockOpdRepository repository, {
  List<OpdQueueEntry> queueEntries = const <OpdQueueEntry>[_queueEntry],
  bool failLists = false,
}) {
  when(() => repository.listAppointments(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdAppointment>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.listVisitQueues(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdQueueEntry>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: queueEntries,
        request:
            (invocation.positionalArguments.single as OpdQueueQuery).pageRequest,
        totalItemCount: queueEntries.length,
      ),
    );
  });
  when(() => repository.listOpdFlows(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.listTriageQueue(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async => const Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: 0),
    ),
  );
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(
    () => repository.getBillingDefaults(
      facilityId: any(named: 'facilityId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async => const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
  );
}

Future<GoRouter> _pumpQueueTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/opd?section=queue',
  List<OpdQueueEntry> queueEntries = const <OpdQueueEntry>[_queueEntry],
  bool failLists = false,
}) async {
  _stubWorkspace(
    repository,
    queueEntries: queueEntries,
    failLists: failLists,
  );
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
        path: '/opd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: OpdWorkspacePage(
              initialQuery: OpdWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        opdRepositoryProvider.overrideWithValue(repository),
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
  return router;
}

void main() {
  late _MockOpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockOpdRepository();
  });

  group('OpdQueueAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(OpdQueueAtomPermissions.tab, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.search,
          opdWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(OpdQueueAtomPermissions.empty, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.loading,
          opdWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(OpdQueueAtomPermissions.retry, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.startEncounter,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.frontDesk,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.prioritize,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.changeStatus,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.assignDoctor,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(OpdQueueAtomPermissions.write, opdFrontDeskActionRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdQueueAtomPermissions.routeEntry,
          RouteAccessCatalog.opdEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          opdSectionTabRequirement(OpdWorkspaceSection.queue),
          OpdQueueAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          opdStartEncounterRequirementForSection(OpdWorkspaceSection.queue),
          OpdQueueAtomPermissions.startEncounter,
        ),
        isTrue,
      );
      expect(
        opdBoardShowsNextActionColumn(
          _writerPolicy(),
          OpdWorkspaceSection.queue,
        ),
        isFalse,
      );
    });

    test(
      'mapping note: matrix ∩ clinical:write via clinicalWrite; '
      'source keep encounter/front-desk for Start + hub',
      () {
        expect(
          OpdQueueAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(OpdQueueAtomPermissions.startEncounter.anyRoles, isNotEmpty);
        expect(
          OpdQueueAtomPermissions.write.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
        expect(
          OpdQueueAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          OpdQueueAtomPermissions.update.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          OpdQueueAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
      },
    );

    test('∪ allowance: patient:read or clinical:read grants Queue chrome', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['CUSTOM_READER'],
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['CUSTOM_READER'],
      );
      expect(OpdQueueAtomPermissions.tab.isAllowed(patientOnly), isTrue);
      expect(OpdQueueAtomPermissions.tab.isAllowed(clinicalOnly), isTrue);
      expect(canViewOpdQueue(patientOnly), isTrue);
      expect(canReadOpd(clinicalOnly), isTrue);
    });

    test('∪ allowance: route-entry union accepts billing:read; Queue still ∪', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        roles: const <String>['BILLING'],
      );
      expect(
        OpdQueueAtomPermissions.routeEntryUnion.isAllowed(billingOnly),
        isTrue,
      );
      expect(OpdQueueAtomPermissions.routeEntry.isAllowed(billingOnly), isFalse);
      expect(OpdQueueAtomPermissions.tab.isAllowed(billingOnly), isFalse);
    });

    test('∩ denial: clinical:write alone does not grant nested billing write', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(OpdQueueAtomPermissions.tab.isAllowed(clinicalWriter), isTrue);
      expect(
        OpdQueueAtomPermissions.clinicalWrite.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        OpdQueueAtomPermissions.nestedBillingWrite.isAllowed(clinicalWriter),
        isFalse,
      );
    });

    test('full intersection set: clinical:write + module allows matrix create', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['CUSTOM_WRITER'],
      );
      expect(
        OpdQueueAtomPermissions.create.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(canWriteOpdClinical(clinicalWriter), isTrue);
    });

    test('subscription strip: scheduling-queue required for Queue tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(OpdQueueAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewOpdQueue(noModule), isFalse);
      expect(
        OpdQueueAtomPermissions.startEncounter.isAllowed(noModule),
        isFalse,
      );
      expect(OpdQueueAtomPermissions.write.isAllowed(noModule), isFalse);
    });

    test('nested cross-module: admission handoff needs inpatient module', () {
      final AppAccessPolicy noInpatient = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: opdSchedulingQueueModule,
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        OpdQueueAtomPermissions.nestedAdmissionWrite.isAllowed(noInpatient),
        isFalse,
      );
    });

    test('nested cross-module matrix rows n/a except billing + admission refs', () {
      expect(
        OpdQueueAtomPermissions.nestedRead,
        same(opdWorkspaceReadRequirement),
      );
      expect(
        OpdQueueAtomPermissions.nestedWrite,
        same(opdFrontDeskActionRequirement),
      );
      expect(
        OpdQueueAtomPermissions.nestedBillingWrite,
        same(opdBillingActionRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Queue chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(OpdQueueAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          OpdQueueAtomPermissions.clinicalWrite.isAllowed(noFacility),
          isTrue,
        );
        expect(
          OpdQueueAtomPermissions.routeEntryUnion.isAllowed(noFacility),
          isTrue,
        );
      },
    );
  });

  group('Opd Queue tab UI gates', () {
    testWidgets(
      'read-only: Queue list visible; mutation atoms absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpQueueTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.text('Queue'), findsWidgets);
        expect(find.text('Queue Patient'), findsOneWidget);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.text('Next action'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Start encounter toolbar present; no next-action column', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Queue Patient'), findsOneWidget);
      expect(find.text('Next action'), findsNothing);
    });

    testWidgets('∪ allowance: clinical:read alone shows Queue chrome', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Queue'), findsWidgets);
      expect(find.text('Queue Patient'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
    });

    testWidgets('∪ allowance: patient:read alone shows Queue list', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Queue Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('billing-only: Queue tab collapsed (no patient/clinical read)', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Queue Patient'), findsNothing);
    });

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        queueEntries: const <OpdQueueEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppWorkspaceStatePanel), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.text('Start OPD encounter'), findsNothing);
    });

    testWidgets('authorized loading chrome remains observable on Queue', (
      WidgetTester tester,
    ) async {
      final Completer<Result<AppPage<OpdQueueEntry>>> queueCompleter =
          Completer<Result<AppPage<OpdQueueEntry>>>();
      when(() => repository.listAppointments(any())).thenAnswer(
        (invocation) async => Result<AppPage<OpdAppointment>>.success(
          AppPage<OpdAppointment>(
            items: const <OpdAppointment>[],
            request:
                (invocation.positionalArguments.single as OpdAppointmentQuery)
                    .pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repository.listVisitQueues(any())).thenAnswer(
        (_) => queueCompleter.future,
      );
      when(() => repository.listOpdFlows(any())).thenAnswer(
        (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
          AppPage<OpdFlowSummary>(
            items: const <OpdFlowSummary>[],
            request: (invocation.positionalArguments.single as OpdFlowQuery)
                .pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repository.listTriageQueue(any())).thenAnswer(
        (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
          AppPage<OpdFlowSummary>(
            items: const <OpdFlowSummary>[],
            request:
                (invocation.positionalArguments.single as OpdTriageQueueQuery)
                    .pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repository.getOpdSummaryCounts()).thenAnswer(
        (_) async => const Result<OpdFlowAggregateCounts>.success(
          OpdFlowAggregateCounts(activeOpd: 0),
        ),
      );
      when(
        () => repository.listClinicalAlertThresholds(
          vitalType: any(named: 'vitalType'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
          <OpdClinicalAlertThreshold>[],
        ),
      );
      when(() => repository.listProviderSchedules()).thenAnswer(
        (_) async => const Result<List<OpdProviderSchedule>>.success(
          <OpdProviderSchedule>[],
        ),
      );
      when(() => repository.listProviders()).thenAnswer(
        (_) async => const Result<List<OpdProviderOption>>.success(
          <OpdProviderOption>[],
        ),
      );
      when(
        () => repository.getBillingDefaults(
          facilityId: any(named: 'facilityId'),
          tenantId: any(named: 'tenantId'),
        ),
      ).thenAnswer(
        (_) async =>
            const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/opd?section=queue',
        routes: <RouteBase>[
          GoRoute(
            path: '/opd',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: OpdWorkspacePage(
                  initialQuery: OpdWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            opdRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_readerPolicy()),
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

      expect(find.textContaining('Loading OPD'), findsWidgets);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      queueCompleter.complete(
        Result<AppPage<OpdQueueEntry>>.success(
          AppPage<OpdQueueEntry>(
            items: const <OpdQueueEntry>[_queueEntry],
            request: const AppPageRequest(pageSize: 12),
            totalItemCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Queue Patient'), findsOneWidget);
    });

    testWidgets(
      'subscription strip UI: without scheduling-queue Queue chrome collapses',
      (WidgetTester tester) async {
        await _pumpQueueTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'patient-registry',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Queue Patient'), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('mobile light theme: read-only hides Start encounter', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Queue Patient'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('desktop dark theme: writer Start encounter still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Queue Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets('post-mutation sync path: Start encounter opens dialog', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Start OPD encounter').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
    });

    testWidgets('integration: section=queue deep link selects Queue', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?section=queue',
      );

      expect(router.state.uri.queryParameters['section'], 'queue');
      expect(find.text('Queue'), findsWidgets);
    });

    testWidgets('row select opens Queue Actions hub for writer', (
      WidgetTester tester,
    ) async {
      await _pumpQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Queue Patient'));
      await tester.pumpAndSettle();

      expect(find.byType(QueueActionsDialog), findsOneWidget);
      expect(find.text('QUEUE ACTIONS'), findsOneWidget);
      expect(find.text('Prioritize'), findsOneWidget);
      expect(find.text('Change status'), findsOneWidget);
      expect(find.text('Change doctor'), findsOneWidget);
    });

    testWidgets(
      'nested write: read-only hub omits Prioritize/Change status/doctor (∩ denial)',
      (WidgetTester tester) async {
        await _pumpQueueTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        await tester.tap(find.text('Queue Patient'));
        await tester.pumpAndSettle();

        expect(find.byType(QueueActionsDialog), findsOneWidget);
        expect(find.text('QUEUE ACTIONS'), findsOneWidget);
        expect(find.text('Prioritize'), findsNothing);
        expect(find.text('Change status'), findsNothing);
        expect(find.text('Change doctor'), findsNothing);
        expect(find.text('Assign doctor'), findsNothing);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized nested Change status shows validation when status unset',
      (WidgetTester tester) async {
        await _pumpQueueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          queueEntries: const <OpdQueueEntry>[
            OpdQueueEntry(
              id: 'queue-opd-2',
              publicId: 'QUE-OPD-2',
              patientDisplayName: 'Queue Patient',
              patientIdentifier: 'PAT-QUE',
              status: 'UNKNOWN_STATUS',
              providerUserId: 'USR-DOC-1',
              providerDisplayName: 'Dr Queue',
            ),
          ],
        );

        await tester.tap(find.text('Queue Patient'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change status'));
        await tester.pumpAndSettle();

        expect(find.text('Change queue status'), findsOneWidget);
        // Submit footer reuses the action label; tap the dialog primary.
        await tester.tap(find.text('Change status').last);
        await tester.pumpAndSettle();

        expect(find.text('This field is required.'), findsOneWidget);
        expect(find.text('Change queue status'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module: Queue Actions hub has no Pay / Admission writes',
      (WidgetTester tester) async {
        await _pumpQueueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Queue Patient'));
        await tester.pumpAndSettle();

        expect(find.byType(QueueActionsDialog), findsOneWidget);
        expect(find.text('Pay consultation'), findsNothing);
        expect(find.text('Admission'), findsNothing);
        expect(find.textContaining('Admit'), findsNothing);
        expect(find.text('Prioritize'), findsOneWidget);
      },
    );
  });
}
