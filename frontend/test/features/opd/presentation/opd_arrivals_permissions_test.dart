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
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_board_next_action.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const OpdAppointment _arrival = OpdAppointment(
  id: 'appointment-arrivals-1',
  publicId: 'APT-ARR-1',
  patientDisplayName: 'Arrivals Patient',
  patientIdentifier: 'PAT-ARR',
  status: 'SCHEDULED',
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
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
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
  List<OpdAppointment> appointments = const <OpdAppointment>[_arrival],
  bool failLists = false,
}) {
  when(() => repository.listAppointments(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdAppointment>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: appointments,
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: appointments.length,
      ),
    );
  });
  when(() => repository.listVisitQueues(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdQueueEntry>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[],
        request:
            (invocation.positionalArguments.single as OpdQueueQuery).pageRequest,
        totalItemCount: 0,
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

Future<GoRouter> _pumpArrivalsTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/opd?section=arrivals',
  List<OpdAppointment> appointments = const <OpdAppointment>[_arrival],
  bool failLists = false,
}) async {
  _stubWorkspace(
    repository,
    appointments: appointments,
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

  group('OpdArrivalsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(OpdArrivalsAtomPermissions.tab, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.search,
          opdWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.empty,
          opdWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.startEncounter,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.nextActionCheckIn,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.frontDesk,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.reschedule,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdArrivalsAtomPermissions.routeEntry,
          RouteAccessCatalog.opdEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          opdSectionTabRequirement(OpdWorkspaceSection.arrivals),
          OpdArrivalsAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        opdNextActionRequirement(OpdBoardNextActionKind.checkInAppointment),
        same(opdFrontDeskActionRequirement),
      );
      expect(
        identical(
          opdStartEncounterRequirementForSection(OpdWorkspaceSection.arrivals),
          OpdArrivalsAtomPermissions.startEncounter,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ clinical:write via clinicalWrite; source keep encounter/front-desk',
      () {
        expect(
          OpdArrivalsAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(OpdArrivalsAtomPermissions.startEncounter.anyRoles, isNotEmpty);
        expect(
          OpdArrivalsAtomPermissions.write.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
        expect(
          OpdArrivalsAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
      },
    );

    test('∪ allowance: patient:read or clinical:read grants Arrivals chrome', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['CUSTOM_READER'],
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['CUSTOM_READER'],
      );
      expect(OpdArrivalsAtomPermissions.tab.isAllowed(patientOnly), isTrue);
      expect(OpdArrivalsAtomPermissions.tab.isAllowed(clinicalOnly), isTrue);
      expect(canViewOpdArrivals(patientOnly), isTrue);
      expect(canReadOpd(clinicalOnly), isTrue);
    });

    test('∪ allowance: route-entry union accepts billing:read; Arrivals still ∪', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        roles: const <String>['BILLING'],
      );
      expect(
        OpdArrivalsAtomPermissions.routeEntryUnion.isAllowed(billingOnly),
        isTrue,
      );
      // Shell catalog keeps unique opd:read — billing alone does not enter.
      expect(
        OpdArrivalsAtomPermissions.routeEntry.isAllowed(billingOnly),
        isFalse,
      );
      expect(OpdArrivalsAtomPermissions.tab.isAllowed(billingOnly), isFalse);
    });

    test('∩ denial: clinical:write alone does not grant nested billing write', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(OpdArrivalsAtomPermissions.tab.isAllowed(clinicalWriter), isTrue);
      expect(
        OpdArrivalsAtomPermissions.clinicalWrite.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        OpdArrivalsAtomPermissions.nestedBillingWrite.isAllowed(clinicalWriter),
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
        OpdArrivalsAtomPermissions.create.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(canWriteOpdClinical(clinicalWriter), isTrue);
    });

    test('subscription strip: scheduling-queue required for Arrivals tab', () {
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
      expect(OpdArrivalsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewOpdArrivals(noModule), isFalse);
      expect(
        OpdArrivalsAtomPermissions.startEncounter.isAllowed(noModule),
        isFalse,
      );
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
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        OpdArrivalsAtomPermissions.nestedAdmissionWrite.isAllowed(noInpatient),
        isFalse,
      );
    });

    test('nested cross-module matrix rows n/a except billing + admission', () {
      expect(
        OpdArrivalsAtomPermissions.nestedRead,
        same(opdWorkspaceReadRequirement),
      );
      expect(
        OpdArrivalsAtomPermissions.nestedWrite,
        same(opdFrontDeskActionRequirement),
      );
      expect(
        OpdArrivalsAtomPermissions.nestedBillingWrite,
        same(opdBillingActionRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Arrivals chrome '
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
        expect(OpdArrivalsAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          OpdArrivalsAtomPermissions.clinicalWrite.isAllowed(noFacility),
          isTrue,
        );
        expect(
          OpdArrivalsAtomPermissions.routeEntryUnion.isAllowed(noFacility),
          isTrue,
        );
      },
    );
  });

  group('Opd Arrivals tab UI gates', () {
    testWidgets(
      'read-only: Arrivals list visible; mutation atoms absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpArrivalsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.text('Arrivals'), findsWidgets);
        expect(find.text('Arrivals Patient'), findsOneWidget);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.text('Next action'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Start encounter next-action + toolbar present', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Next action'), findsWidgets);
      expect(find.text('Arrivals Patient'), findsOneWidget);
    });

    testWidgets('∪ allowance: clinical:read alone shows Arrivals chrome', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Arrivals'), findsWidgets);
      expect(find.text('Arrivals Patient'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
    });

    testWidgets('∪ allowance: patient:read alone shows Arrivals list', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Arrivals Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('billing-only: Arrivals tab collapsed (no patient/clinical read)', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Arrivals Patient'), findsNothing);
    });

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        appointments: const <OpdAppointment>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppWorkspaceStatePanel), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport: read-only hides Start encounter', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Arrivals Patient'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('desktop dark theme: writer Start encounter still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Arrivals Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets('post-mutation sync path: Start encounter opens dialog', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Start OPD encounter').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
    });

    testWidgets('integration: section=arrivals deep link selects Arrivals', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?section=arrivals',
      );

      expect(router.state.uri.queryParameters['section'], 'arrivals');
      expect(find.text('Arrivals'), findsWidgets);
    });

    testWidgets('row select hub omits Start duplicate for writer', (
      WidgetTester tester,
    ) async {
      await _pumpArrivalsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Arrivals Patient'));
      await tester.pumpAndSettle();

      expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start OPD encounter'),
        ),
        findsNothing,
      );
      expect(find.text('Reschedule'), findsOneWidget);
    });

    testWidgets(
      'nested write: read-only hub omits Reschedule/Cancel (∩ denial)',
      (WidgetTester tester) async {
        await _pumpArrivalsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        await tester.tap(find.text('Arrivals Patient'));
        await tester.pumpAndSettle();

        expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
        expect(find.text('Reschedule'), findsNothing);
        expect(find.text('Cancel appointment'), findsNothing);
        expect(find.text('Check in'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });
}
