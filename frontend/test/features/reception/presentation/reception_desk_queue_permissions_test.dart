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
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/pages/reception_workspace_page.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_queue_actions_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const OpdQueueEntry _queueEntry = OpdQueueEntry(
  id: 'queue-1',
  publicId: 'QUE000001',
  patientDisplayName: 'Quinn Queue',
  patientIdentifier: 'PAT-QUE',
  status: 'WAITING',
  providerUserId: 'USR-DOC-1',
  providerDisplayName: 'Dr Queue',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['CUSTOM_READER'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientRead ||
        permission == AppPermissions.patientWrite ||
        permission == AppPermissions.patientDelete,
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
  return _policy(permissions: <AppPermission>{AppPermissions.patientRead});
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
    roles: const <String>['RECEPTIONIST'],
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
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
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
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
  when(() => repository.getOpdSummaryCounts()).thenAnswer((_) async {
    if (failLists) {
      return const Result<OpdFlowAggregateCounts>.failure(AppFailure.network());
    }
    return const Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(),
    );
  });
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

Future<GoRouter> _pumpDeskQueueTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/reception?section=desk-queue',
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
        path: '/reception',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ReceptionWorkspacePage(
              initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri),
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

  group('ReceptionDeskQueueAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.tab,
          receptionSchedulingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.register,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.schedule,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.frontDesk,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.frontDesk,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.prioritize,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.changeStatus,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.assignDoctor,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.delete,
          receptionPatientDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.routeEntry,
          receptionWorkspaceRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.queue),
          ReceptionDeskQueueAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionDeskQueueAtomPermissions.catalogEntry,
          RouteAccessCatalog.receptionEntry,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ patient:write / patient:delete; '
      'source keep front-desk for hub',
      () {
        expect(
          ReceptionDeskQueueAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionDeskQueueAtomPermissions.update.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionDeskQueueAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.patientDelete],
        );
        expect(
          ReceptionDeskQueueAtomPermissions.frontDesk.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
        expect(
          ReceptionDeskQueueAtomPermissions.tab.allPermissions,
          <AppPermission>[AppPermissions.patientRead],
        );
      },
    );

    test('∩ denial: patient:read alone does not grant Schedule / Register', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(ReceptionDeskQueueAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ReceptionDeskQueueAtomPermissions.schedule.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionDeskQueueAtomPermissions.register.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionDeskQueueAtomPermissions.frontDesk.isAllowed(reader),
        isFalse,
      );
      expect(canViewReceptionDeskQueue(reader), isTrue);
      expect(receptionDeskQueueShowsNextActionColumn(reader), isTrue);
    });

    test('full intersection set: patient:write + modules allows create', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        ReceptionDeskQueueAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionDeskQueueAtomPermissions.schedule.isAllowed(writer),
        isTrue,
      );
    });

    test('∪ allowance: route entry accepts patient:read or last_office:read', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      final AppAccessPolicy lastOfficeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['RECEPTIONIST'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ReceptionDeskQueueAtomPermissions.routeEntryUnion.isAllowed(
          patientOnly,
        ),
        isTrue,
      );
      expect(
        ReceptionDeskQueueAtomPermissions.routeEntryUnion.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
      // Desk queue tab itself stays ∩ patient:read.
      expect(
        ReceptionDeskQueueAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
    });

    test('subscription strip: scheduling-queue required for Desk queue tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(ReceptionDeskQueueAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewReceptionDeskQueue(noModule), isFalse);
      expect(
        ReceptionDeskQueueAtomPermissions.schedule.isAllowed(noModule),
        isFalse,
      );
      expect(
        ReceptionDeskQueueAtomPermissions.frontDesk.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested cross-module matrix rows _(n/a)_ reuse front-desk / read', () {
      expect(
        ReceptionDeskQueueAtomPermissions.nestedRead,
        same(receptionSchedulingReadRequirement),
      );
      expect(
        ReceptionDeskQueueAtomPermissions.nestedWrite,
        same(receptionFrontDeskWriteRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Desk queue chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          ReceptionDeskQueueAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          ReceptionDeskQueueAtomPermissions.routeEntryUnion.isAllowed(
            noFacility,
          ),
          isTrue,
        );
      },
    );
  });

  group('Reception Desk queue tab UI gates', () {
    testWidgets(
      'read-only: list + next-action guidance visible; mutations absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.textContaining('Desk queue'), findsWidgets);
        expect(find.text('Quinn Queue'), findsOneWidget);
        expect(find.text('Next action'), findsWidgets);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Register + Schedule present; next-action guidance stays', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Register patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Next action'), findsWidgets);
      expect(find.text('Quinn Queue'), findsOneWidget);
    });

    testWidgets(
      '∪ allowance: last_office:read enters workspace; Desk queue tab collapsed',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.lastOfficeRead},
            roles: const <String>['RECEPTIONIST'],
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'patient-registry',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(find.textContaining('Desk queue'), findsNothing);
        expect(find.text('Quinn Queue'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets('∪ allowance: patient:read alone shows Desk queue list', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Quinn Queue'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets(
      'patient:write without front-desk role: Schedule present; hub mutations absent',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
            },
          ),
        );

        expect(find.text('Schedule appointment'), findsOneWidget);
        expect(find.text('Register patient'), findsOneWidget);

        await tester.tap(find.text('Quinn Queue'));
        await tester.pumpAndSettle();

        expect(find.byType(ReceptionQueueActionsDialog), findsOneWidget);
        expect(find.text('Prioritize'), findsNothing);
        expect(find.text('Change status'), findsNothing);
        expect(find.text('Assign doctor'), findsNothing);
        expect(find.text('Change doctor'), findsNothing);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        queueEntries: const <OpdQueueEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppStateView), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.text('Register patient'), findsNothing);
    });

    testWidgets('authorized loading chrome remains observable on Desk queue', (
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
          OpdFlowAggregateCounts(),
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
        initialLocation: '/reception?section=desk-queue',
        routes: <RouteBase>[
          GoRoute(
            path: '/reception',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: ReceptionWorkspacePage(
                  initialQuery: ReceptionWorkspaceQuery.fromUri(state.uri),
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

      expect(find.textContaining('Loading'), findsWidgets);
      expect(find.text('Register patient'), findsNothing);
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
      expect(find.text('Quinn Queue'), findsOneWidget);
    });

    testWidgets(
      'subscription strip UI: without scheduling-queue Desk queue collapses',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'patient-registry',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(find.textContaining('Desk queue'), findsNothing);
        expect(find.text('Quinn Queue'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
      },
    );

    testWidgets('mobile light theme: read-only hides Register / Schedule', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.textContaining('Quinn Queue'), findsOneWidget);
      expect(find.text('Register patient'), findsNothing);
      expect(find.text('Schedule appointment'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('desktop dark theme: writer Register still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Register patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Quinn Queue'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets('integration: section=desk-queue deep link selects tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/reception?section=desk-queue',
      );

      expect(router.state.uri.queryParameters['section'], 'desk-queue');
      expect(find.textContaining('Desk queue'), findsWidgets);
    });

    testWidgets('row select hub: writer sees Prioritize / Change status / doctor', (
      WidgetTester tester,
    ) async {
      await _pumpDeskQueueTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Quinn Queue'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceptionQueueActionsDialog), findsOneWidget);
      final QueueActionsDialog hub = tester.widget<QueueActionsDialog>(
        find.byType(QueueActionsDialog),
      );
      expect(
        hub.actionRequirement,
        same(ReceptionDeskQueueAtomPermissions.frontDesk),
      );
      expect(find.text('Prioritize'), findsOneWidget);
      expect(find.text('Change status'), findsOneWidget);
      expect(find.text('Change doctor'), findsOneWidget);
    });

    testWidgets(
      'nested write: read-only hub omits Prioritize/Change status/doctor (∩ denial)',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        await tester.tap(find.text('Quinn Queue'));
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
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          queueEntries: const <OpdQueueEntry>[
            OpdQueueEntry(
              id: 'queue-2',
              publicId: 'QUE000002',
              patientDisplayName: 'Quinn Queue',
              patientIdentifier: 'PAT-QUE',
              status: 'UNKNOWN_STATUS',
              providerUserId: 'USR-DOC-1',
              providerDisplayName: 'Dr Queue',
            ),
          ],
        );

        await tester.tap(find.text('Quinn Queue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change status'));
        await tester.pumpAndSettle();

        expect(find.text('CHANGE QUEUE STATUS'), findsOneWidget);
        expect(find.byType(AppRadioGroup<String>), findsOneWidget);
        await tester.tap(find.text('Change status').last);
        await tester.pumpAndSettle();

        expect(find.text('This field is required.'), findsOneWidget);
        expect(find.text('CHANGE QUEUE STATUS'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'post-mutation sync path: Prioritize opens nested dialog for writer',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Quinn Queue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prioritize'));
        await tester.pumpAndSettle();

        expect(find.text('PRIORITIZE QUEUE ENTRY'), findsOneWidget);
        expect(find.byType(AppDialog), findsWidgets);
      },
    );

    testWidgets(
      'nested cross-module: Queue Actions hub has no Pay / Admission writes',
      (WidgetTester tester) async {
        await _pumpDeskQueueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Quinn Queue'));
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
