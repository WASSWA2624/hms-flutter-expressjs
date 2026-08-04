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
import 'package:hosspi_hms/shared/opd_actions/opd_board_next_action.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const OpdFlowSummary _activeFlow = OpdFlowSummary(
  id: 'encounter-active-1',
  publicId: 'ENC-ACTIVE-1',
  patientDisplayName: 'Alex Active',
  patientIdentifier: 'PAT-ACT-1',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_VITALS',
);

const OpdFlowSummary _paymentFlow = OpdFlowSummary(
  id: 'encounter-active-pay',
  publicId: 'ENC-ACTIVE-PAY',
  patientDisplayName: 'Pay Active',
  patientIdentifier: 'PAT-ACT-PAY',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_CONSULTATION_PAYMENT',
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
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[_activeFlow],
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
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
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
        items: flows,
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: flows.length,
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
    (_) async => Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: flows.length),
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
    final OpdFlowSummary summary = flows.firstWhere(
      (OpdFlowSummary flow) => flow.id == id || flow.publicId == id,
      orElse: () => _activeFlow,
    );
    return Result<OpdFlowDetail>.success(OpdFlowDetail(summary: summary));
  });
}

Future<GoRouter> _pumpActiveTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/opd?section=active',
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[_activeFlow],
  bool failLists = false,
}) async {
  _stubWorkspace(repository, flows: flows, failLists: failLists);
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

  group('OpdActiveAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(OpdActiveAtomPermissions.tab, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(OpdActiveAtomPermissions.search, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(OpdActiveAtomPermissions.empty, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdActiveAtomPermissions.startEncounter,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdActiveAtomPermissions.nextActionVitals,
          opdVitalsActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdActiveAtomPermissions.payConsultation,
          opdBillingActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdActiveAtomPermissions.admissionHandoff,
          opdAdmissionHandoffRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdActiveAtomPermissions.nextActionDepartmentHandoff,
          opdReceptionActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdActiveAtomPermissions.routeEntry,
          RouteAccessCatalog.opdEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          opdSectionTabRequirement(OpdWorkspaceSection.active),
          OpdActiveAtomPermissions.tab,
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
        opdFocusedPanelRequirement('payment'),
        same(opdBillingActionRequirement),
      );
    });

    test(
      'mapping note: matrix ∩ clinical:write via clinicalWrite; source keep encounter/front-desk',
      () {
        expect(
          OpdActiveAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          OpdActiveAtomPermissions.startEncounter.anyRoles,
          isNotEmpty,
        );
        expect(
          OpdActiveAtomPermissions.write.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          OpdActiveAtomPermissions.frontDesk.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
      },
    );

    test('∪ allowance: patient:read or clinical:read grants Active chrome', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['CUSTOM_READER'],
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['CUSTOM_READER'],
      );
      expect(OpdActiveAtomPermissions.tab.isAllowed(patientOnly), isTrue);
      expect(OpdActiveAtomPermissions.tab.isAllowed(clinicalOnly), isTrue);
      expect(canViewOpdActive(patientOnly), isTrue);
      expect(canReadOpd(clinicalOnly), isTrue);
    });

    test('∪ allowance: route-entry union accepts billing:read; Active still ∪', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        roles: const <String>['BILLING'],
      );
      expect(
        OpdActiveAtomPermissions.routeEntryUnion.isAllowed(billingOnly),
        isTrue,
      );
      expect(OpdActiveAtomPermissions.routeEntry.isAllowed(billingOnly), isFalse);
      expect(OpdActiveAtomPermissions.tab.isAllowed(billingOnly), isFalse);
    });

    test('∩ denial: clinical:write alone does not grant billing next-action', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(OpdActiveAtomPermissions.tab.isAllowed(clinicalWriter), isTrue);
      expect(
        OpdActiveAtomPermissions.clinicalWrite.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        OpdActiveAtomPermissions.payConsultation.isAllowed(clinicalWriter),
        isFalse,
      );
      expect(
        OpdActiveAtomPermissions.nextActionPay.isAllowed(clinicalWriter),
        isFalse,
      );
    });

    test('full intersection set: billing:write + module allows pay atom', () {
      final AppAccessPolicy billingWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.billingWrite,
        },
        roles: const <String>['BILLING'],
      );
      expect(
        OpdActiveAtomPermissions.payConsultation.isAllowed(billingWriter),
        isTrue,
      );
      expect(canWriteOpdBilling(billingWriter), isTrue);
    });

    test('subscription strip: scheduling-queue required for Active tab', () {
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
      expect(OpdActiveAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewOpdActive(noModule), isFalse);
      expect(
        OpdActiveAtomPermissions.startEncounter.isAllowed(noModule),
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
      expect(
        OpdActiveAtomPermissions.admissionHandoff.isAllowed(noInpatient),
        isFalse,
      );
      expect(
        OpdActiveAtomPermissions.nestedAdmissionWrite.isAllowed(noInpatient),
        isFalse,
      );
    });

    test('nested cross-module matrix rows n/a except billing + admission', () {
      expect(
        OpdActiveAtomPermissions.nestedRead,
        same(opdWorkspaceReadRequirement),
      );
      expect(
        OpdActiveAtomPermissions.nestedWrite,
        same(opdClinicalWriteRequirement),
      );
      expect(
        OpdActiveAtomPermissions.nestedBillingWrite,
        same(opdBillingActionRequirement),
      );
      expect(
        OpdActiveAtomPermissions.nestedAdmissionWrite,
        same(opdAdmissionHandoffRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Active chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          },
          roles: const <String>['CUSTOM_READER'],
          facilityId: null,
        );
        expect(OpdActiveAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(canViewOpdActive(noFacility), isTrue);
      },
    );

    test(
      'mapping note: department handoff keeps source reception (not matrix read ∪)',
      () {
        expect(
          OpdActiveAtomPermissions.nextActionDepartmentHandoff,
          same(opdReceptionActionRequirement),
        );
        expect(
          opdNextActionRequirement(OpdBoardNextActionKind.departmentHandoff),
          same(opdReceptionActionRequirement),
        );
      },
    );
  });

  group('Opd Active tab UI gates', () {
    testWidgets('read-only: Active list visible; mutation atoms absent (∩ denial)', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.textContaining('Active'), findsWidgets);
      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.byTooltip('Create or continue an OPD encounter'), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
      expect(find.text('Next action'), findsNothing);
    });

    testWidgets('writer: Start encounter + Record vitals present', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byTooltip('Create or continue an OPD encounter'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Record vitals'), findsWidgets);
      expect(find.text('Next action'), findsWidgets);
    });

    testWidgets('∪ allowance: clinical:read alone shows Active chrome', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
    });

    testWidgets('billing-only: Active tab collapsed (no patient/clinical read)', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Alex Active'), findsNothing);
    });

    testWidgets('pay next-action absent without billing:write', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          roles: const <String>['DOCTOR', 'NURSE'],
        ),
        flows: const <OpdFlowSummary>[_paymentFlow],
      );

      expect(find.text('Pay Active'), findsOneWidget);
      expect(find.text('Pay consultation'), findsNothing);
    });

    testWidgets('pay next-action present with billing:write + module', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        flows: const <OpdFlowSummary>[_paymentFlow],
      );

      expect(find.text('Pay Active'), findsOneWidget);
      expect(find.text('Pay consultation'), findsWidgets);
    });

    testWidgets('deep link panel=vitals blocked without vitals write', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?section=active&flowId=encounter-active-1&panel=vitals',
      );

      expect(find.text('FLOW ACTIONS'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
    });

    testWidgets(
      'deep link panel=vitals opens vitals for authorized writer (integration)',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          initialLocation:
              '/opd?section=active&flowId=encounter-active-1&panel=vitals',
        );

        expect(find.text('FLOW ACTIONS'), findsNothing);
        expect(find.textContaining('Vitals'), findsWidgets);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        flows: const <OpdFlowSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppWorkspaceStatePanel), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport: read-only hides next-action trailing', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.text('Record vitals'), findsNothing);
      expect(find.byTooltip('Create or continue an OPD encounter'), findsNothing);
    });

    testWidgets('desktop dark theme: writer next-action still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Record vitals'), findsWidgets);
      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.byTooltip('Create or continue an OPD encounter'), findsOneWidget);
    });

    testWidgets('mobile light theme: writer Start + next-action mount', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.text('Record vitals'), findsWidgets);
      expect(find.byTooltip('Create or continue an OPD encounter'), findsOneWidget);
    });

    testWidgets(
      'row select opens Flow Actions with Record vitals among patient actions',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Alex Active'));
        await tester.pumpAndSettle();

        expect(find.text('FLOW ACTIONS'), findsOneWidget);
        expect(find.textContaining('Record vitals'), findsWidgets);
        expect(find.byType(AppWorkflowStepper), findsNothing);
        expect(find.text('Correct stage'), findsNothing);
        expect(find.text('Print summary'), findsOneWidget);
      },
    );

    testWidgets('post-mutation sync: vitals dialog opens for writer', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Record vitals').first);
      await tester.pumpAndSettle();

      expect(find.text('FLOW ACTIONS'), findsNothing);
      expect(find.textContaining('Vitals'), findsWidgets);
    });

    testWidgets('integration: section=active deep link selects Active', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?section=active',
      );

      expect(router.state.uri.queryParameters['section'], 'active');
      expect(find.text('Alex Active'), findsOneWidget);
    });
  });
}
