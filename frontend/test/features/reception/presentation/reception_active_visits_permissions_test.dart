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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

final OpdFlowSummary _activeFlow = OpdFlowSummary(
  id: 'encounter-active-1',
  publicId: 'ENC-ACTIVE-1',
  patientDisplayName: 'Alex Active',
  patientIdentifier: 'PAT-ACT-1',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_VITALS',
  startedAt: DateTime.now(),
  nextStep: 'RECORD_VITALS',
);

final OpdFlowSummary _paymentFlow = OpdFlowSummary(
  id: 'encounter-active-pay',
  publicId: 'ENC-ACTIVE-PAY',
  patientDisplayName: 'Penny Payment',
  patientIdentifier: 'PAT-ACT-PAY',
  encounterType: 'OPD',
  status: 'OPEN',
  stage: 'WAITING_CONSULTATION_PAYMENT',
  startedAt: DateTime.now(),
  consultationPaymentStatus: 'UNPAID',
  nextStep: 'PAY_CONSULTATION',
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
    permissions: <AppPermission>{AppPermissions.patientRead},
  );
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
    },
    roles: const <String>['RECEPTIONIST'],
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

void _stubWorkspace(
  _MockOpdRepository repository, {
  List<OpdFlowSummary>? flows,
  bool failLists = false,
}) {
  final List<OpdFlowSummary> resolvedFlows =
      flows ?? <OpdFlowSummary>[_activeFlow, _paymentFlow];
  when(() => repository.listAppointments(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdAppointment>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
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
      ),
    );
  });
  when(() => repository.listOpdFlows(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: resolvedFlows,
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: resolvedFlows.length,
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
      ),
    );
  });
  when(() => repository.getOpdSummaryCounts()).thenAnswer((_) async {
    if (failLists) {
      return const Result<OpdFlowAggregateCounts>.failure(AppFailure.network());
    }
    return Result<OpdFlowAggregateCounts>.success(
      OpdFlowAggregateCounts(activeOpd: resolvedFlows.length),
    );
  });
  when(() => repository.getOpdFlow(any())).thenAnswer((invocation) async {
    final String id = invocation.positionalArguments.single as String;
    final OpdFlowSummary summary = resolvedFlows.firstWhere(
      (OpdFlowSummary flow) => flow.id == id || flow.publicId == id,
      orElse: () => resolvedFlows.first,
    );
    return Result<OpdFlowDetail>.success(OpdFlowDetail(summary: summary));
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

Future<GoRouter> _pumpActiveVisitsTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/reception?section=active',
  List<OpdFlowSummary>? flows,
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
  await tester.pump(const Duration(milliseconds: 50));
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

  group('ReceptionActiveVisitsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.tab,
          receptionActiveVisitsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.register,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.scheduleAppointment,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.delete,
          receptionPatientDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.nestedWrite,
          receptionActiveVisitsNestedWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.nextActionLabel,
          receptionActiveVisitsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.nestedBillingWrite,
          opdBillingActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.nestedFrontDesk,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.routeEntry,
          receptionWorkspaceRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionActiveVisitsAtomPermissions.catalogEntry,
          RouteAccessCatalog.receptionEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.activeVisits),
          ReceptionActiveVisitsAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ patient:read maps to source ∪ OPD-readable keys',
      () {
        expect(
          ReceptionActiveVisitsAtomPermissions.tab.anyPermissions,
          containsAll(<AppPermission>[
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
            AppPermissions.operationsRead,
            AppPermissions.emergencyRead,
          ]),
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.patientDelete],
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.nestedWrite.anyPermissions,
          containsAll(<AppPermission>[
            AppPermissions.clinicalWrite,
            AppPermissions.patientWrite,
          ]),
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.catalogEntry.allPermissions,
          <AppPermission>[AppPermissions.receptionRead],
        );
      },
    );

    test('∩ denial: patient:read alone does not grant Register / Schedule', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(ReceptionActiveVisitsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ReceptionActiveVisitsAtomPermissions.register.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionActiveVisitsAtomPermissions.scheduleAppointment.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        ReceptionActiveVisitsAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
      expect(canViewReceptionActiveVisits(reader), isTrue);
    });

    test('full intersection set: patient:write + modules allows create', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        ReceptionActiveVisitsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionActiveVisitsAtomPermissions.scheduleAppointment.isAllowed(
          writer,
        ),
        isTrue,
      );
    });

    test(
      '∪ allowance: nested write accepts clinical:write or patient:write',
      () {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          roles: const <String>['DOCTOR'],
        );
        final AppAccessPolicy patientWriter = _policy(
          permissions: <AppPermission>{AppPermissions.patientWrite},
        );
        final AppAccessPolicy neither = _readerPolicy();

        expect(
          ReceptionActiveVisitsAtomPermissions.nestedWrite.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          canWriteReceptionActiveVisitsNested(clinicalWriter),
          isTrue,
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.nestedWrite.isAllowed(
            patientWriter,
          ),
          isTrue,
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.nestedWrite.isAllowed(neither),
          isFalse,
        );
        expect(canWriteReceptionActiveVisitsNested(neither), isFalse);
      },
    );

    test('next-action column helper tracks tab read ∪', () {
      final AppAccessPolicy reader = _readerPolicy();
      final AppAccessPolicy denied = _policy(
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
      expect(receptionActiveVisitsShowsNextActionColumn(reader), isTrue);
      expect(receptionActiveVisitsShowsNextActionColumn(denied), isFalse);
    });

    test(
      '∪ allowance: source tab read accepts clinical:read without patient:read',
      () {
        final AppAccessPolicy clinicalReader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['NURSE'],
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.tab.isAllowed(clinicalReader),
          isTrue,
        );
        expect(canViewReceptionActiveVisits(clinicalReader), isTrue);
      },
    );

    test('subscription strip: scheduling-queue required for Active visits', () {
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
      expect(
        ReceptionActiveVisitsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(canViewReceptionActiveVisits(noModule), isFalse);
      expect(
        ReceptionActiveVisitsAtomPermissions.register.isAllowed(noModule),
        isFalse,
      );
    });

    test(
      'ABAC: missing facility still allows Active visits chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          ReceptionActiveVisitsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          ReceptionActiveVisitsAtomPermissions.routeEntryUnion.isAllowed(
            noFacility,
          ),
          isTrue,
        );
      },
    );
  });

  group('Reception Active visits tab UI gates', () {
    testWidgets(
      'read-only: list visible; mutation atoms absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.textContaining('Active visits'), findsWidgets);
        expect(find.text('Alex Active'), findsOneWidget);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.byType(WorkflowActionButton), findsNothing);
        expect(find.widgetWithText(AppButton, 'Record vitals'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Register + Schedule present; next-action stays label', (
      WidgetTester tester,
    ) async {
      await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Register patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.text('Record vitals'), findsOneWidget);
      expect(find.byType(WorkflowActionButton), findsNothing);
      expect(find.widgetWithText(AppButton, 'Record vitals'), findsNothing);
    });

    testWidgets(
      '∪ allowance: clinical:read alone shows Active visits list',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
            roles: const <String>['NURSE'],
          ),
        );

        expect(find.textContaining('Active visits'), findsWidgets);
        expect(find.text('Alex Active'), findsOneWidget);
        expect(find.text('Register patient'), findsNothing);
        expect(find.byTooltip('Filters'), findsOneWidget);
      },
    );

    testWidgets(
      'nested cross-module: billing write absent from Flow Actions hub',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Penny Payment'));
        await tester.pumpAndSettle();

        expect(find.byType(FlowActionsDialog), findsOneWidget);
        expect(find.text('Manage consultation billing'), findsNothing);
        expect(find.text('Update consultation billing'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Pay consultation'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Record vitals'), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        flows: const <OpdFlowSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppStateView), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport: read-only hides Schedule; guidance stays text', (
      WidgetTester tester,
    ) async {
      await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.textContaining('Alex Active'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expect(find.byType(WorkflowActionButton), findsNothing);
    });

    testWidgets('desktop dark theme: writer Schedule still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Alex Active'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
    });

    testWidgets('integration: section=active deep link selects tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/reception?section=active',
      );

      expect(router.state.uri.queryParameters['section'], 'active');
      expect(find.textContaining('Active visits'), findsWidgets);
    });

    testWidgets(
      'integration: section=active-visits alias selects Active visits',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
          initialLocation: '/reception?section=active-visits',
        );

        expect(find.textContaining('Active visits'), findsWidgets);
        expect(find.text('Alex Active'), findsOneWidget);
      },
    );

    testWidgets(
      'subscription strip UI: without scheduling-queue Active visits collapses',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
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

        expect(find.textContaining('Active visits'), findsNothing);
        expect(find.text('Alex Active'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
      },
    );

    testWidgets(
      'denied Active visits deep link collapses tab; flowId does not open hub',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
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
          initialLocation:
              '/reception?section=active&flowId=encounter-active-1',
        );

        expect(find.textContaining('Active visits'), findsNothing);
        expect(find.byType(FlowActionsDialog), findsNothing);
        expect(find.text('Alex Active'), findsNothing);
      },
    );

    testWidgets('row select: authorized user opens Flow Actions hub', (
      WidgetTester tester,
    ) async {
      await _pumpActiveVisitsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Alex Active'));
      await tester.pumpAndSettle();

      expect(find.byType(FlowActionsDialog), findsOneWidget);
    });

    testWidgets(
      'post-mutation sync path: closing Flow Actions without change keeps list',
      (WidgetTester tester) async {
        await _pumpActiveVisitsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Alex Active'));
        await tester.pumpAndSettle();
        expect(find.byType(FlowActionsDialog), findsOneWidget);

        await tester.tap(find.byTooltip('Close').first);
        await tester.pumpAndSettle();

        expect(find.byType(FlowActionsDialog), findsNothing);
        expect(find.text('Alex Active'), findsOneWidget);
        expect(find.text('Penny Payment'), findsOneWidget);
      },
    );
  });
}
