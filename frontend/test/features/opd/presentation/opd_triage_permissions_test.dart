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

const OpdFlowSummary _triageFlow = OpdFlowSummary(
  id: 'encounter-triage-1',
  publicId: 'ENC-TRIAGE-1',
  patientDisplayName: 'Triage Patient',
  patientIdentifier: 'PAT-TRI-1',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_VITALS',
  triageLevel: 'LEVEL_3',
);

const OpdFlowSummary _assignDoctorFlow = OpdFlowSummary(
  id: 'encounter-triage-assign',
  publicId: 'ENC-TRIAGE-ASSIGN',
  patientDisplayName: 'Assign Triage',
  patientIdentifier: 'PAT-TRI-ASSIGN',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_DOCTOR_ASSIGNMENT',
  triageLevel: 'LEVEL_4',
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
      AppPermissions.opdRead,
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
  List<OpdFlowSummary> triageFlows = const <OpdFlowSummary>[_triageFlow],
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
        items: triageFlows,
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: triageFlows.length,
      ),
    );
  });
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async => Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: triageFlows.length),
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
  when(() => repository.getOpdFlow(any())).thenAnswer((invocation) async {
    final String id = invocation.positionalArguments.single as String;
    final OpdFlowSummary summary = triageFlows.firstWhere(
      (OpdFlowSummary flow) => flow.id == id || flow.publicId == id,
      orElse: () => _triageFlow,
    );
    return Result<OpdFlowDetail>.success(OpdFlowDetail(summary: summary));
  });
}

Future<GoRouter> _pumpTriageTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/opd?section=triage',
  List<OpdFlowSummary> triageFlows = const <OpdFlowSummary>[_triageFlow],
  bool failLists = false,
}) async {
  _stubWorkspace(
    repository,
    triageFlows: triageFlows,
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

  group('OpdTriageAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(OpdTriageAtomPermissions.tab, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(OpdTriageAtomPermissions.search, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(OpdTriageAtomPermissions.empty, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdTriageAtomPermissions.startEncounter,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdTriageAtomPermissions.nextActionVitals,
          opdVitalsActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdTriageAtomPermissions.recordVitals,
          opdVitalsActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdTriageAtomPermissions.nextActionAssignDoctor,
          opdReceptionActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdTriageAtomPermissions.routeEntry,
          RouteAccessCatalog.opdEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          opdSectionTabRequirement(OpdWorkspaceSection.triage),
          OpdTriageAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        opdNextActionRequirement(OpdBoardNextActionKind.recordVitals),
        same(opdVitalsActionRequirement),
      );
      expect(
        opdFocusedPanelRequirement('vitals'),
        same(opdVitalsActionRequirement),
      );
      expect(
        identical(
          opdStartEncounterRequirementForSection(OpdWorkspaceSection.triage),
          OpdTriageAtomPermissions.startEncounter,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ clinical:write via clinicalWrite; '
      'source keep encounter/vitals/reception',
      () {
        expect(
          OpdTriageAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(OpdTriageAtomPermissions.startEncounter.anyRoles, isNotEmpty);
        expect(
          OpdTriageAtomPermissions.write.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          OpdTriageAtomPermissions.nextActionVitals.anyRoles,
          opdVitalsActionRequirement.anyRoles,
        );
        expect(
          OpdTriageAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
      },
    );

    test('∪ allowance: patient:read or clinical:read grants Triage chrome', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['CUSTOM_READER'],
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['CUSTOM_READER'],
      );
      expect(OpdTriageAtomPermissions.tab.isAllowed(patientOnly), isTrue);
      expect(OpdTriageAtomPermissions.tab.isAllowed(clinicalOnly), isTrue);
      expect(canViewOpdTriage(patientOnly), isTrue);
      expect(canReadOpd(clinicalOnly), isTrue);
    });

    test('∪ allowance: route-entry union accepts billing:read; Triage still ∪', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        roles: const <String>['BILLING'],
      );
      expect(
        OpdTriageAtomPermissions.routeEntryUnion.isAllowed(billingOnly),
        isTrue,
      );
      expect(
        OpdTriageAtomPermissions.routeEntry.isAllowed(billingOnly),
        isFalse,
      );
      expect(OpdTriageAtomPermissions.tab.isAllowed(billingOnly), isFalse);
    });

    test('∩ denial: clinical:write alone does not grant nested billing write', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(OpdTriageAtomPermissions.tab.isAllowed(clinicalWriter), isTrue);
      expect(
        OpdTriageAtomPermissions.clinicalWrite.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        OpdTriageAtomPermissions.nestedBillingWrite.isAllowed(clinicalWriter),
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
        OpdTriageAtomPermissions.create.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(canWriteOpdClinical(clinicalWriter), isTrue);
    });

    test('subscription strip: scheduling-queue required for Triage tab', () {
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
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(OpdTriageAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewOpdTriage(noModule), isFalse);
      expect(
        OpdTriageAtomPermissions.startEncounter.isAllowed(noModule),
        isFalse,
      );
      expect(
        OpdTriageAtomPermissions.nextActionVitals.isAllowed(noModule),
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
        OpdTriageAtomPermissions.nestedAdmissionWrite.isAllowed(noInpatient),
        isFalse,
      );
    });

    test('nested cross-module matrix rows n/a except billing + admission refs', () {
      expect(
        OpdTriageAtomPermissions.nestedRead,
        same(opdWorkspaceReadRequirement),
      );
      expect(
        OpdTriageAtomPermissions.nestedWrite,
        same(opdClinicalWriteRequirement),
      );
      expect(
        OpdTriageAtomPermissions.nestedBillingWrite,
        same(opdBillingActionRequirement),
      );
      expect(
        OpdTriageAtomPermissions.nestedAdmissionWrite,
        same(opdAdmissionHandoffRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Triage chrome '
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
        expect(OpdTriageAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          OpdTriageAtomPermissions.clinicalWrite.isAllowed(noFacility),
          isTrue,
        );
        expect(
          OpdTriageAtomPermissions.routeEntryUnion.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test('next-action column mounts when vitals or assign-doctor allowed', () {
      final AppAccessPolicy nurse = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
        },
        roles: const <String>['NURSE'],
      );
      expect(
        opdBoardShowsNextActionColumn(nurse, OpdWorkspaceSection.triage),
        isTrue,
      );
      expect(
        opdBoardShowsNextActionColumn(
          _readerPolicy(),
          OpdWorkspaceSection.triage,
        ),
        isFalse,
      );
    });
  });

  group('Opd Triage tab UI gates', () {
    testWidgets(
      'read-only: Triage list visible; mutation atoms absent (∩ / source denial)',
      (WidgetTester tester) async {
        await _pumpTriageTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.text('Triage'), findsWidgets);
        expect(find.text('Triage Patient'), findsOneWidget);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.text('Record vitals'), findsNothing);
        expect(find.text('Next action'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Start encounter + Record vitals present', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Record vitals'), findsWidgets);
      expect(find.text('Next action'), findsWidgets);
      expect(find.text('Triage Patient'), findsOneWidget);
    });

    testWidgets('∪ allowance: clinical:read alone shows Triage chrome', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Triage'), findsWidgets);
      expect(find.text('Triage Patient'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
    });

    testWidgets('∪ allowance: patient:read alone shows Triage list', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Triage Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('billing-only: Triage tab collapsed (no patient/clinical read)', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Triage Patient'), findsNothing);
    });

    testWidgets('assign-doctor next-action present for reception writer', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        triageFlows: const <OpdFlowSummary>[_assignDoctorFlow],
      );

      expect(find.text('Assign Triage'), findsOneWidget);
      expect(find.textContaining('doctor'), findsWidgets);
    });

    testWidgets('assign-doctor next-action absent for read-only', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        triageFlows: const <OpdFlowSummary>[_assignDoctorFlow],
      );

      expect(find.text('Assign Triage'), findsOneWidget);
      expect(find.textContaining('Assign doctor'), findsNothing);
      expect(find.textContaining('Change doctor'), findsNothing);
    });

    testWidgets('deep link panel=vitals blocked without vitals write', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation:
            '/opd?section=triage&flowId=encounter-triage-1&panel=vitals',
      );

      expect(find.text('FLOW ACTIONS'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
    });

    testWidgets(
      'deep link panel=vitals opens vitals for authorized writer (integration)',
      (WidgetTester tester) async {
        await _pumpTriageTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          initialLocation:
              '/opd?section=triage&flowId=encounter-triage-1&panel=vitals',
        );

        expect(find.text('FLOW ACTIONS'), findsNothing);
        expect(find.textContaining('Vitals'), findsWidgets);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        triageFlows: const <OpdFlowSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppWorkspaceStatePanel), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport: read-only hides Start / Record vitals', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Triage Patient'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('desktop dark theme: writer Record vitals still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Record vitals'), findsWidgets);
      expect(find.text('Triage Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets('mobile light theme: writer Start + Record vitals mount', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Triage Patient'), findsOneWidget);
      expect(find.text('Record vitals'), findsWidgets);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets(
      'row select opens Flow Actions omitting Record vitals duplicate',
      (WidgetTester tester) async {
        await _pumpTriageTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Triage Patient'));
        await tester.pumpAndSettle();

        expect(find.text('FLOW ACTIONS'), findsOneWidget);
        expect(find.text('Record vitals'), findsNothing);
      },
    );

    testWidgets('post-mutation sync: vitals dialog opens for writer', (
      WidgetTester tester,
    ) async {
      await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Record vitals').first);
      await tester.pumpAndSettle();

      expect(find.text('FLOW ACTIONS'), findsNothing);
      expect(find.textContaining('Vitals'), findsWidgets);
    });

    testWidgets('integration: section=triage deep link selects Triage', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpTriageTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?section=triage',
      );

      expect(router.state.uri.queryParameters['section'], 'triage');
      expect(find.text('Triage'), findsWidgets);
      expect(find.text('Triage Patient'), findsOneWidget);
    });

    testWidgets(
      'nested write: read-only Flow Actions omits vitals write (∩ / source denial)',
      (WidgetTester tester) async {
        await _pumpTriageTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        await tester.tap(find.text('Triage Patient'));
        await tester.pumpAndSettle();

        expect(find.text('FLOW ACTIONS'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Record vitals'),
          ),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });
}
