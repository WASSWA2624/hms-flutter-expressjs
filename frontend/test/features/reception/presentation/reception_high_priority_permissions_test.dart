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

const OpdQueueEntry _priorityEntry = OpdQueueEntry(
  id: 'queue-vip',
  publicId: 'QUE000VIP',
  patientId: 'patient-vip',
  patientDisplayName: 'Victor VIP',
  patientIdentifier: 'PAT-VIP',
  status: 'WAITING',
  isPrioritized: true,
  providerUserId: 'USR-DOC-1',
  providerDisplayName: 'Dr Priority',
);

const OpdQueueEntry _normalEntry = OpdQueueEntry(
  id: 'queue-normal',
  publicId: 'QUE000NOR',
  patientDisplayName: 'Nora Normal',
  patientIdentifier: 'PAT-NOR',
  status: 'WAITING',
  isPrioritized: false,
);

const OpdFlowSummary _emergencyFlow = OpdFlowSummary(
  id: 'flow-emergency',
  publicId: 'FLW-EMG',
  patientId: 'patient-vip',
  patientDisplayName: 'Victor VIP',
  patientIdentifier: 'PAT-VIP',
  visitQueueId: 'queue-vip',
  status: 'IN_PROGRESS',
  stage: 'TRIAGE',
  emergencyIndicator: true,
  encounterType: 'EMERGENCY',
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

AppAccessPolicy _exporterWriterPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
      AppPermissions.evidenceExport,
    },
    roles: const <String>['RECEPTIONIST'],
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _readerWithEmergencyPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.emergencyRead,
    },
  );
}

void _stubWorkspace(
  _MockOpdRepository repository, {
  List<OpdQueueEntry> queueEntries = const <OpdQueueEntry>[
    _priorityEntry,
    _normalEntry,
  ],
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
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
  when(() => repository.getOpdFlow(any())).thenAnswer((invocation) async {
    final String id = invocation.positionalArguments.single as String;
    final OpdFlowSummary summary = flows.isEmpty
        ? _emergencyFlow
        : flows.firstWhere(
            (OpdFlowSummary flow) =>
                flow.id == id ||
                flow.publicId == id ||
                flow.apiId == id,
            orElse: () => flows.first,
          );
    return Result<OpdFlowDetail>.success(OpdFlowDetail(summary: summary));
  });
}

Future<GoRouter> _pumpHighPriorityTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/reception?section=high-priority',
  List<OpdQueueEntry> queueEntries = const <OpdQueueEntry>[
    _priorityEntry,
    _normalEntry,
  ],
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
  bool failLists = false,
}) async {
  _stubWorkspace(
    repository,
    queueEntries: queueEntries,
    flows: flows,
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

  group('ReceptionHighPriorityAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.tab,
          receptionSchedulingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.register,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.schedule,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.frontDesk,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.prioritize,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.delete,
          receptionPatientDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.nestedEmergencyRead,
          receptionHighPriorityEmergencyNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.nestedRead,
          receptionHighPriorityEmergencyNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.highPriority),
          ReceptionHighPriorityAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionHighPriorityAtomPermissions.catalogEntry,
          RouteAccessCatalog.receptionEntry,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ patient:write / patient:delete; '
      'source keep front-desk; nested ∪ emergency:read',
      () {
        expect(
          ReceptionHighPriorityAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionHighPriorityAtomPermissions.update.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionHighPriorityAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.patientDelete],
        );
        expect(
          ReceptionHighPriorityAtomPermissions.tab.allPermissions,
          <AppPermission>[AppPermissions.patientRead],
        );
        expect(
          ReceptionHighPriorityAtomPermissions.nestedEmergencyRead
              .anyPermissions,
          <AppPermission>[AppPermissions.emergencyRead],
        );
        expect(
          ReceptionHighPriorityAtomPermissions.frontDesk.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
      },
    );

    test('∩ denial: patient:read alone does not grant Schedule / Register', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(
        ReceptionHighPriorityAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.schedule.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.register.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.frontDesk.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.nestedEmergencyRead.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(canViewReceptionHighPriority(reader), isTrue);
      expect(receptionHighPriorityShowsNextActionColumn(reader), isTrue);
    });

    test('full intersection set: patient:write + modules allows create', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        ReceptionHighPriorityAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.schedule.isAllowed(writer),
        isTrue,
      );
    });

    test(
      '∪ allowance: emergency:read alone satisfies nested emergency chrome',
      () {
        final AppAccessPolicy emergencyOnly = _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        );
        expect(
          ReceptionHighPriorityAtomPermissions.nestedEmergencyRead.isAllowed(
            emergencyOnly,
          ),
          isTrue,
        );
        // Tab itself stays ∩ patient:read.
        expect(
          ReceptionHighPriorityAtomPermissions.tab.isAllowed(emergencyOnly),
          isFalse,
        );
        expect(isReceptionEmergencyFlow(_emergencyFlow), isTrue);
      },
    );

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
        ReceptionHighPriorityAtomPermissions.routeEntryUnion.isAllowed(
          patientOnly,
        ),
        isTrue,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.routeEntryUnion.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
      expect(
        ReceptionHighPriorityAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
    });

    test(
      'subscription strip: scheduling-queue required for High priority tab',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
            AppPermissions.emergencyRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          ReceptionHighPriorityAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(canViewReceptionHighPriority(noModule), isFalse);
        expect(
          ReceptionHighPriorityAtomPermissions.nestedEmergencyRead.isAllowed(
            noModule,
          ),
          isFalse,
        );
      },
    );

    test(
      'ABAC: missing facility still allows High priority chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          ReceptionHighPriorityAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
      },
    );
  });

  group('Reception High priority tab UI gates', () {
    testWidgets(
      'read-only: prioritized list visible; mutations absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.textContaining('High priority'), findsWidgets);
        expect(find.text('Victor VIP'), findsOneWidget);
        expect(find.text('Nora Normal'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.text('Export'), findsNothing);
        expect(find.text('Print'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Emergency'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Register + Schedule present', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expect(find.text('Register patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Victor VIP'), findsOneWidget);
      expect(find.text('Next action'), findsWidgets);
    });

    testWidgets('export/print omitted without evidence:export; present with it', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );
      expect(find.text('Export'), findsNothing);
      expect(find.text('Print'), findsNothing);

      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _exporterWriterPolicy(),
      );
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
    });

    testWidgets(
      'defaults five data columns; warning tone; only prioritized rows',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _exporterWriterPolicy(),
        );

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem highPriority = strip.tabs.firstWhere(
          (AppTabItem item) => item.id == 'highPriority',
        );
        expect(highPriority.count, 1);
        expect(highPriority.countTone, AppTabCountTone.warning);

        expect(find.text('Victor VIP'), findsOneWidget);
        expect(find.text('Nora Normal'), findsNothing);
        expect(find.text('Patient name'), findsWidgets);
        expect(find.text('Phone'), findsWidgets);
        expect(find.text('Queued at'), findsWidgets);
        expect(find.text('Current step'), findsWidgets);
        expect(find.text('Doctor'), findsWidgets);
        expect(find.text('Next action'), findsWidgets);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('TABLE SETTINGS'), findsOneWidget);
        expect(find.text('Queue ID'), findsOneWidget);
        expect(find.text('Payment status'), findsOneWidget);
        expect(find.text('Reason'), findsOneWidget);
      },
    );

    testWidgets(
      '∪ allowance: last_office:read enters workspace; High priority collapsed',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
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

        expect(find.text('Victor VIP'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets(
      '∪ allowance: emergency:read shows Emergency badge; absent without it',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
          flows: const <OpdFlowSummary>[_emergencyFlow],
        );
        expect(find.text('Victor VIP'), findsOneWidget);
        expect(find.text('Emergency'), findsNothing);

        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _readerWithEmergencyPolicy(),
          flows: const <OpdFlowSummary>[_emergencyFlow],
        );
        expect(find.text('Victor VIP'), findsOneWidget);
        expect(find.text('Emergency'), findsWidgets);
      },
    );

    testWidgets(
      'nested emergency denial: emergency flow opens Queue Actions, not Flow',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          flows: const <OpdFlowSummary>[_emergencyFlow],
        );

        await tester.tap(find.text('Victor VIP'));
        await tester.pumpAndSettle();

        expect(find.byType(ReceptionQueueActionsDialog), findsOneWidget);
        expect(find.byType(FlowActionsDialog), findsNothing);
        expect(find.text('QUEUE ACTIONS'), findsOneWidget);
        expect(find.text('Prioritize'), findsOneWidget);

        final QueueActionsDialog hub = tester.widget<QueueActionsDialog>(
          find.byType(QueueActionsDialog),
        );
        expect(
          hub.actionRequirement,
          same(ReceptionHighPriorityAtomPermissions.frontDesk),
        );
      },
    );

    testWidgets(
      '∪ allowance: emergency:read opens Flow Actions for emergency visit',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.emergencyRead,
            },
            roles: const <String>['RECEPTIONIST'],
          ),
          flows: const <OpdFlowSummary>[_emergencyFlow],
        );

        await tester.tap(find.text('Victor VIP'));
        await tester.pumpAndSettle();

        expect(find.byType(FlowActionsDialog), findsOneWidget);
        expect(find.byType(ReceptionQueueActionsDialog), findsNothing);
      },
    );

    testWidgets('row select without flow: Queue Actions; reader mutations absent', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      await tester.tap(find.text('Victor VIP'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceptionQueueActionsDialog), findsOneWidget);
      expect(find.text('Prioritize'), findsNothing);
      expect(find.text('Change status'), findsNothing);
      expect(find.text('Assign doctor'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        queueEntries: const <OpdQueueEntry>[_normalEntry],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppStateView), findsOneWidget);
      expect(find.textContaining('No high-priority'), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets(
      'authorized loading chrome remains observable on High priority',
      (WidgetTester tester) async {
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
          initialLocation: '/reception?section=high-priority',
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
              items: const <OpdQueueEntry>[_priorityEntry],
              request: const AppPageRequest(pageSize: 12),
              totalItemCount: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Victor VIP'), findsOneWidget);
      },
    );

    testWidgets(
      'subscription strip UI: without scheduling-queue High priority collapses',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
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

        expect(find.textContaining('High priority'), findsNothing);
        expect(find.text('Victor VIP'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
      },
    );

    testWidgets(
      'mobile light theme: read-only hides Schedule; shows prioritized',
      (WidgetTester tester) async {
        await _pumpHighPriorityTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Victor VIP'), findsOneWidget);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
      },
    );

    testWidgets('desktop dark theme: writer Schedule still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Victor VIP'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('integration: section=high-priority deep link selects tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/reception?section=high-priority',
      );

      expect(router.state.uri.queryParameters['section'], 'high-priority');
      expect(find.textContaining('High priority'), findsWidgets);
      expect(find.text('Victor VIP'), findsOneWidget);
    });

    testWidgets('post-mutation sync path: Prioritize opens nested dialog', (
      WidgetTester tester,
    ) async {
      await _pumpHighPriorityTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Victor VIP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prioritize'));
      await tester.pumpAndSettle();

      expect(find.text('PRIORITIZE QUEUE ENTRY'), findsOneWidget);
    });
  });
}
