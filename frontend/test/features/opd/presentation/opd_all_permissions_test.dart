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

const OpdAppointment _arrival = OpdAppointment(
  id: 'appointment-all-1',
  publicId: 'APT-ALL-1',
  patientDisplayName: 'All Arrival Patient',
  patientIdentifier: 'PAT-ALL-ARR',
  status: 'SCHEDULED',
);

const OpdFlowSummary _activeFlow = OpdFlowSummary(
  id: 'encounter-all-active',
  publicId: 'ENC-ALL-ACTIVE',
  patientDisplayName: 'All Active Patient',
  patientIdentifier: 'PAT-ALL-ACT',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_VITALS',
);

const OpdFlowSummary _paymentFlow = OpdFlowSummary(
  id: 'encounter-all-pay',
  publicId: 'ENC-ALL-PAY',
  patientDisplayName: 'All Pay Patient',
  patientIdentifier: 'PAT-ALL-PAY',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_CONSULTATION_PAYMENT',
);

const OpdFlowSummary _doctorReviewFlow = OpdFlowSummary(
  id: 'encounter-all-review',
  publicId: 'ENC-ALL-REVIEW',
  patientDisplayName: 'All Review Patient',
  patientIdentifier: 'PAT-ALL-REV',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_DOCTOR_REVIEW',
);

const OpdFlowSummary _admissionFlow = OpdFlowSummary(
  id: 'encounter-all-admit',
  publicId: 'ENC-ALL-ADMIT',
  patientDisplayName: 'All Admit Patient',
  patientIdentifier: 'PAT-ALL-ADM',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_DISPOSITION',
  displayCode: 'ADMISSION_PENDING',
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
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[_activeFlow],
  Result<AppPage<OpdFlowSummary>>? flowsOverride,
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
    if (flowsOverride != null) {
      return flowsOverride;
    }
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
    (_) async => const Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: 1),
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

Future<GoRouter> _pumpAllTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/opd?section=all',
  List<OpdAppointment> appointments = const <OpdAppointment>[_arrival],
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[_activeFlow],
  Result<AppPage<OpdFlowSummary>>? flowsOverride,
  bool failLists = false,
}) async {
  _stubWorkspace(
    repository,
    appointments: appointments,
    flows: flows,
    flowsOverride: flowsOverride,
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

  group('OpdAllAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(OpdAllAtomPermissions.tab, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(OpdAllAtomPermissions.search, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(OpdAllAtomPermissions.empty, opdWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.startEncounter,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.nextActionVitals,
          opdVitalsActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.nextActionAssignDoctor,
          opdReceptionActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.nextActionDoctorReview,
          opdDoctorActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.nextActionDisposition,
          opdDoctorActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.nextActionAdmissionHandoff,
          opdAdmissionHandoffRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.nextActionDepartmentHandoff,
          opdReceptionActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.payConsultation,
          opdBillingActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.admissionHandoff,
          opdAdmissionHandoffRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OpdAllAtomPermissions.write,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(OpdAllAtomPermissions.routeEntry, RouteAccessCatalog.opdEntry),
        isTrue,
      );
      expect(
        identical(
          opdSectionTabRequirement(OpdWorkspaceSection.all),
          OpdAllAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        opdFocusedPanelRequirement('vitals'),
        same(opdVitalsActionRequirement),
      );
      expect(
        opdFocusedPanelRequirement('payment'),
        same(opdBillingActionRequirement),
      );
      expect(
        opdBoardNextActionRequirement(OpdBoardNextActionKind.recordVitals),
        same(opdVitalsActionRequirement),
      );
    });

    test(
      'mapping note: matrix ∩ clinical:write via clinicalWrite; source keep encounter/front-desk',
      () {
        expect(
          OpdAllAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          OpdAllAtomPermissions.startEncounter.anyRoles,
          isNotEmpty,
        );
        expect(
          OpdAllAtomPermissions.write.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
      },
    );

    test('∪ allowance: patient:read or clinical:read grants All-tab chrome', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        roles: const <String>['CUSTOM_READER'],
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['CUSTOM_READER'],
      );
      expect(OpdAllAtomPermissions.tab.isAllowed(patientOnly), isTrue);
      expect(OpdAllAtomPermissions.tab.isAllowed(clinicalOnly), isTrue);
      expect(canViewOpdAll(patientOnly), isTrue);
      expect(canReadOpd(clinicalOnly), isTrue);
    });

    test('∪ allowance: route-entry union accepts billing:read; All tab still ∪', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        roles: const <String>['BILLING'],
      );
      expect(
        OpdAllAtomPermissions.routeEntryUnion.isAllowed(billingOnly),
        isTrue,
      );
      // Shell catalog keeps unique opd:read — billing alone does not enter.
      expect(OpdAllAtomPermissions.routeEntry.isAllowed(billingOnly), isFalse);
      expect(OpdAllAtomPermissions.tab.isAllowed(billingOnly), isFalse);
    });

    test('∩ denial: clinical:write alone does not grant billing next-action', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        roles: const <String>['DOCTOR'],
      );
      expect(OpdAllAtomPermissions.tab.isAllowed(clinicalWriter), isTrue);
      expect(
        OpdAllAtomPermissions.clinicalWrite.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        OpdAllAtomPermissions.payConsultation.isAllowed(clinicalWriter),
        isFalse,
      );
      expect(
        OpdAllAtomPermissions.nextActionPay.isAllowed(clinicalWriter),
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
        OpdAllAtomPermissions.payConsultation.isAllowed(billingWriter),
        isTrue,
      );
      expect(canWriteOpdBilling(billingWriter), isTrue);
    });

    test('subscription strip: scheduling-queue required for All tab', () {
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
      expect(OpdAllAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewOpdAll(noModule), isFalse);
      expect(
        OpdAllAtomPermissions.startEncounter.isAllowed(noModule),
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
        OpdAllAtomPermissions.admissionHandoff.isAllowed(noInpatient),
        isFalse,
      );
      expect(
        OpdAllAtomPermissions.nestedAdmissionWrite.isAllowed(noInpatient),
        isFalse,
      );
    });

    test('nested cross-module matrix rows n/a except billing + admission', () {
      expect(
        OpdAllAtomPermissions.nestedRead,
        same(opdWorkspaceReadRequirement),
      );
      expect(
        OpdAllAtomPermissions.nestedWrite,
        same(opdFrontDeskActionRequirement),
      );
      expect(
        OpdAllAtomPermissions.nestedBillingWrite,
        same(opdBillingActionRequirement),
      );
      expect(
        OpdAllAtomPermissions.nestedAdmissionWrite,
        same(opdAdmissionHandoffRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows All chrome '
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
        expect(OpdAllAtomPermissions.tab.isAllowed(noFacility), isTrue);
        expect(
          OpdAllAtomPermissions.clinicalWrite.isAllowed(noFacility),
          isTrue,
        );
        expect(
          OpdAllAtomPermissions.routeEntryUnion.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'next-action column mounts for admission-only ward manager (∪ of stage gates)',
      () {
        final AppAccessPolicy wardManager = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          },
          roles: const <String>['WARD_MANAGER'],
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
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          OpdAllAtomPermissions.nextActionAdmissionHandoff.isAllowed(
            wardManager,
          ),
          isTrue,
        );
        expect(
          OpdAllAtomPermissions.frontDesk.isAllowed(wardManager),
          isFalse,
        );
        expect(
          opdBoardShowsNextActionColumn(wardManager, OpdWorkspaceSection.all),
          isTrue,
        );
      },
    );
  });

  group('Opd All tab UI gates', () {
    testWidgets('read-only: All list visible; mutation atoms absent (∩ denial)', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.textContaining('All worklist'), findsOneWidget);
      expect(find.text('All Active Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
      expect(find.text('Next action'), findsNothing);
    });

    testWidgets('writer: Start encounter + Record vitals present', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Record vitals'), findsWidgets);
      expect(find.text('Next action'), findsWidgets);
    });

    testWidgets('∪ allowance: clinical:read alone shows All worklist chrome', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['CUSTOM_READER'],
        ),
      );

      expect(find.textContaining('All worklist'), findsOneWidget);
      expect(find.text('All Active Patient'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsNothing);
    });

    testWidgets('billing-only: All tab collapsed (no patient/clinical read)', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING'],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.text('All Active Patient'), findsNothing);
    });

    testWidgets('pay next-action absent without billing:write', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
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

      expect(find.text('All Pay Patient'), findsOneWidget);
      expect(find.text('Pay consultation'), findsNothing);
    });

    testWidgets('pay next-action present with billing:write + module', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        flows: const <OpdFlowSummary>[_paymentFlow],
      );

      expect(find.text('All Pay Patient'), findsOneWidget);
      expect(find.text('Pay consultation'), findsWidgets);
    });

    testWidgets('doctor-review next-action present for writer', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        flows: const <OpdFlowSummary>[_doctorReviewFlow],
      );

      expect(find.text('All Review Patient'), findsOneWidget);
      expect(find.text('Clinical notes'), findsWidgets);
      expect(find.text('Next action'), findsWidgets);
    });

    testWidgets('doctor-review next-action absent for read-only (∩ denial)', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        flows: const <OpdFlowSummary>[_doctorReviewFlow],
      );

      expect(find.text('All Review Patient'), findsOneWidget);
      expect(find.text('Clinical notes'), findsNothing);
      expect(find.text('Next action'), findsNothing);
    });

    testWidgets(
      'admission next-action absent without inpatient module (nested strip)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
            roles: const <String>['DOCTOR'],
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
          flows: const <OpdFlowSummary>[_admissionFlow],
        );

        expect(find.text('All Admit Patient'), findsOneWidget);
        expect(find.text('Open inpatient admission'), findsNothing);
      },
    );

    testWidgets(
      'admission next-action present for ward manager with inpatient module',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.clinicalRead,
            },
            roles: const <String>['WARD_MANAGER'],
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
                code: 'inpatient-bed-management',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
          flows: const <OpdFlowSummary>[_admissionFlow],
        );

        expect(find.text('All Admit Patient'), findsOneWidget);
        expect(find.text('Open inpatient admission'), findsWidgets);
        expect(find.text('Start OPD encounter'), findsNothing);
      },
    );

    testWidgets('deep link panel=vitals blocked without vitals write', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?flowId=encounter-all-active&panel=vitals',
      );

      expect(find.text('FLOW ACTIONS'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
    });

    testWidgets(
      'deep link panel=vitals opens vitals for authorized writer (integration)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          initialLocation: '/opd?flowId=encounter-all-active&panel=vitals',
        );

        expect(find.text('FLOW ACTIONS'), findsNothing);
        expect(find.textContaining('Vitals'), findsWidgets);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        appointments: const <OpdAppointment>[],
        flows: const <OpdFlowSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppWorkspaceStatePanel), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
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
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('All Active Patient'), findsOneWidget);
      expect(find.text('Record vitals'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('desktop dark theme: writer next-action still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Record vitals'), findsWidgets);
      expect(find.text('All Active Patient'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets('post-mutation sync: vitals dialog opens for writer', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Record vitals').first);
      await tester.pumpAndSettle();

      expect(find.text('FLOW ACTIONS'), findsNothing);
      expect(find.textContaining('Vitals'), findsWidgets);
    });

    testWidgets('integration: section=all deep link selects All worklist', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/opd?section=all',
      );

      expect(router.state.uri.queryParameters['section'], 'all');
      expect(find.textContaining('All worklist'), findsOneWidget);
    });
  });
}
