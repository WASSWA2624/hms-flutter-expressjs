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
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_actions_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_board_next_action.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

const OpdAppointment _appointment = OpdAppointment(
  id: 'appointment-1',
  publicId: 'APT000001',
  patientDisplayName: 'Ada Appointment',
  patientIdentifier: 'PAT-ADA',
  status: 'SCHEDULED',
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
  return _policy(
    permissions: <AppPermission>{AppPermissions.patientRead},
  );
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
  List<OpdAppointment> appointments = const <OpdAppointment>[_appointment],
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
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
      ),
    );
  });
  when(() => repository.listTriageQueue(any())).thenAnswer((invocation) async {
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
      ),
    );
  });
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

Future<GoRouter> _pumpAppointmentsTab(
  WidgetTester tester, {
  required _MockOpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/reception?section=appointments',
  List<OpdAppointment> appointments = const <OpdAppointment>[_appointment],
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

  group('ReceptionAppointmentsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.tab,
          receptionSchedulingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.register,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.schedule,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.frontDesk,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.frontDesk,
          opdFrontDeskActionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.cancelAppointment,
          receptionFrontDeskWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.delete,
          receptionPatientDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionAppointmentsAtomPermissions.routeEntry,
          receptionWorkspaceRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.appointments),
          ReceptionAppointmentsAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∩ patient:write / patient:delete; source keep front-desk',
      () {
        expect(
          ReceptionAppointmentsAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionAppointmentsAtomPermissions.update.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionAppointmentsAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.patientDelete],
        );
        expect(
          ReceptionAppointmentsAtomPermissions.frontDesk.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
        expect(
          ReceptionAppointmentsAtomPermissions.cancelAppointment.anyRoles,
          opdFrontDeskActionRequirement.anyRoles,
        );
      },
    );

    test('∩ denial: patient:read alone does not grant Schedule / Register', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(ReceptionAppointmentsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ReceptionAppointmentsAtomPermissions.schedule.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionAppointmentsAtomPermissions.register.isAllowed(reader),
        isFalse,
      );
      expect(canViewReceptionAppointments(reader), isTrue);
      expect(receptionAppointmentsShowsNextActionColumn(reader), isFalse);
    });

    test('full intersection set: patient:write + modules allows create', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        ReceptionAppointmentsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionAppointmentsAtomPermissions.schedule.isAllowed(writer),
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
      );
      expect(
        ReceptionAppointmentsAtomPermissions.routeEntryUnion.isAllowed(
          patientOnly,
        ),
        isTrue,
      );
      expect(
        ReceptionAppointmentsAtomPermissions.routeEntryUnion.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
      // Appointments tab itself stays ∩ patient:read.
      expect(
        ReceptionAppointmentsAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
    });

    test('subscription strip: scheduling-queue required for Appointments tab', () {
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
      expect(ReceptionAppointmentsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewReceptionAppointments(noModule), isFalse);
      expect(
        ReceptionAppointmentsAtomPermissions.schedule.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested cross-module matrix rows _(n/a)_ reuse front-desk / read', () {
      expect(
        ReceptionAppointmentsAtomPermissions.nestedRead,
        same(receptionSchedulingReadRequirement),
      );
      expect(
        ReceptionAppointmentsAtomPermissions.nestedWrite,
        same(receptionFrontDeskWriteRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Appointments chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          ReceptionAppointmentsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          ReceptionAppointmentsAtomPermissions.routeEntryUnion.isAllowed(
            noFacility,
          ),
          isTrue,
        );
      },
    );
  });

  group('Reception Appointments tab UI gates', () {
    testWidgets(
      'read-only: list visible; mutation atoms absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpAppointmentsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.textContaining('Appointments'), findsWidgets);
        expect(find.text('Ada Appointment'), findsOneWidget);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Next action'), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Register + Schedule + next-action present', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Register patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Next action'), findsWidgets);
      expect(find.text('Start OPD encounter'), findsWidgets);
      expect(find.text('Ada Appointment'), findsOneWidget);
    });

    testWidgets(
      '∪ allowance: last_office:read enters workspace; Appointments tab collapsed',
      (WidgetTester tester) async {
        await _pumpAppointmentsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.lastOfficeRead},
            roles: const <String>['RECEPTIONIST'],
          ),
        );

        expect(find.textContaining('Appointments'), findsNothing);
        expect(find.text('Ada Appointment'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        // Forbidden only when no desk section remains.
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets('∪ allowance: patient:read alone shows Appointments list', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Ada Appointment'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets(
      'patient:write without front-desk role: Schedule present; next-action absent',
      (WidgetTester tester) async {
        await _pumpAppointmentsTab(
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
        expect(find.text('Next action'), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        appointments: const <OpdAppointment>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppStateView), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport: read-only hides Schedule / next-action', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Ada Appointment'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsNothing);
      expect(find.text('Start OPD encounter'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    });

    testWidgets('desktop dark theme: writer Schedule still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Ada Appointment'), findsOneWidget);
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Start OPD encounter'), findsWidgets);
    });

    testWidgets('post-mutation sync path: Check in opens encounter dialog', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Start OPD encounter').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.byType(OpdEncounterDialog), findsOneWidget);
      expect(find.text('APPOINTMENT ACTIONS'), findsNothing);
    });

    testWidgets('integration: section=appointments deep link selects tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/reception?section=appointments',
      );

      expect(router.state.uri.queryParameters['section'], 'appointments');
      expect(find.textContaining('Appointments'), findsWidgets);
    });

    testWidgets('row select hub: writer sees Reschedule + Cancel; no Check in', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Ada Appointment'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceptionAppointmentActionsDialog), findsOneWidget);
      final OpdAppointmentActionsDialog hub = tester
          .widget<OpdAppointmentActionsDialog>(
            find.byType(OpdAppointmentActionsDialog),
          );
      expect(
        hub.actionRequirement,
        same(ReceptionAppointmentsAtomPermissions.frontDesk),
      );
      expect(find.text('Reschedule'), findsOneWidget);
      expect(find.text('Cancel appointment'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Start OPD encounter'),
        findsNothing,
      );
    });

    testWidgets('row select hub: reader sees context; mutations absent', (
      WidgetTester tester,
    ) async {
      await _pumpAppointmentsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      await tester.tap(find.text('Ada Appointment'));
      await tester.pumpAndSettle();

      expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
      expect(find.text('Reschedule'), findsNothing);
      expect(find.text('Cancel appointment'), findsNothing);
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('next-action requirement maps to source front-desk', (
      WidgetTester tester,
    ) async {
      expect(
        opdBoardNextActionRequirement(
          OpdBoardNextActionKind.checkInAppointment,
        ),
        same(opdFrontDeskActionRequirement),
      );
      expect(
        ReceptionAppointmentsAtomPermissions.nextActionCheckIn,
        same(receptionFrontDeskWriteRequirement),
      );
    });
  });
}
