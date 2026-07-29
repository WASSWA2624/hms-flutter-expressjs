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
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/pages/reception_workspace_page.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_follow_up_detail_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_follow_up_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-rx-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-RX1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Reception callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

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

void _stubOpd(_MockOpdRepository repository, {bool failLists = false}) {
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

void _stubFollowUps(
  _MockFollowUpRepository repository, {
  List<ReceptionFollowUpEntry>? entries,
  bool failList = false,
}) {
  final List<ReceptionFollowUpEntry> list =
      entries ?? <ReceptionFollowUpEntry>[_followUp];

  when(
    () => repository.listScheduledFollowUps(
      encounterType: any(named: 'encounterType'),
    ),
  ).thenAnswer((_) async {
    if (failList) {
      return const Result<List<ReceptionFollowUpEntry>>.failure(
        AppFailure.network(),
      );
    }
    return Result<List<ReceptionFollowUpEntry>>.success(list);
  });
}

Future<GoRouter> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockOpdRepository opdRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/reception?section=follow-ups',
  List<ReceptionFollowUpEntry>? followUps,
  bool failFollowUps = false,
  bool failOpdLists = false,
}) async {
  _stubOpd(opdRepository, failLists: failOpdLists);
  _stubFollowUps(
    followUpRepository,
    entries: followUps ?? <ReceptionFollowUpEntry>[_followUp],
    failList: failFollowUps,
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
        opdRepositoryProvider.overrideWithValue(opdRepository),
        receptionFollowUpRepositoryProvider.overrideWithValue(
          followUpRepository,
        ),
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
  late _MockOpdRepository opdRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    opdRepository = _MockOpdRepository();
    followUpRepository = _MockFollowUpRepository();
  });

  group('ReceptionFollowUpsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.tab,
          receptionFollowUpsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.write,
          receptionFollowUpsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.write,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.register,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.schedule,
          receptionPatientWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.delete,
          receptionPatientDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.routeEntry,
          receptionWorkspaceRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ReceptionFollowUpsAtomPermissions.catalogEntry,
          RouteAccessCatalog.receptionEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          receptionDeskSectionRequirement(ReceptionDeskSection.followUps),
          ReceptionFollowUpsAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test(
      'mapping note: matrix ∪ last_office → source ∪ patient|clinical; '
      'write keeps ∩ patient:write',
      () {
        expect(
          ReceptionFollowUpsAtomPermissions.tab.anyPermissions,
          <AppPermission>[
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          ],
        );
        expect(
          ReceptionFollowUpsAtomPermissions.create.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionFollowUpsAtomPermissions.update.allPermissions,
          <AppPermission>[AppPermissions.patientWrite],
        );
        expect(
          ReceptionFollowUpsAtomPermissions.delete.allPermissions,
          <AppPermission>[AppPermissions.patientDelete],
        );
        expect(
          ReceptionFollowUpsAtomPermissions.markCompleted,
          same(receptionFollowUpsWriteRequirement),
        );
        expect(
          ReceptionFollowUpsAtomPermissions.reschedule,
          same(receptionFollowUpsWriteRequirement),
        );
      },
    );

    test('∩ denial: patient:read alone does not grant write atoms', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(ReceptionFollowUpsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(ReceptionFollowUpsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        ReceptionFollowUpsAtomPermissions.markCompleted.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionFollowUpsAtomPermissions.reschedule.isAllowed(reader),
        isFalse,
      );
      expect(
        ReceptionFollowUpsAtomPermissions.schedule.isAllowed(reader),
        isFalse,
      );
      expect(canViewReceptionFollowUps(reader), isTrue);
      expect(canWriteReceptionFollowUps(reader), isFalse);
    });

    test('full intersection set: patient:write + modules allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        ReceptionFollowUpsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionFollowUpsAtomPermissions.complete.isAllowed(writer),
        isTrue,
      );
      expect(
        ReceptionFollowUpsAtomPermissions.saveFollowUp.isAllowed(writer),
        isTrue,
      );
    });

    test('∪ allowance: patient:read or clinical:read mounts Follow-ups tab', () {
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final AppAccessPolicy lastOfficeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['RECEPTIONIST'],
      );
      expect(
        ReceptionFollowUpsAtomPermissions.tab.isAllowed(patientOnly),
        isTrue,
      );
      expect(
        ReceptionFollowUpsAtomPermissions.tab.isAllowed(clinicalOnly),
        isTrue,
      );
      // Matrix last_office alone → source deny (backend list auth).
      expect(
        ReceptionFollowUpsAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(
        ReceptionFollowUpsAtomPermissions.routeEntryUnion.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
    });

    test('subscription strip: modules required for Follow-ups tab', () {
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
      expect(ReceptionFollowUpsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewReceptionFollowUps(noModule), isFalse);
      expect(
        ReceptionFollowUpsAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested cross-module matrix rows _(n/a)_ reuse read ∪ / write ∩', () {
      expect(
        ReceptionFollowUpsAtomPermissions.nestedRead,
        same(receptionFollowUpsRequirement),
      );
      expect(
        ReceptionFollowUpsAtomPermissions.nestedWrite,
        same(receptionFollowUpsWriteRequirement),
      );
    });

    test(
      'ABAC: missing facility still allows Follow-ups chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          ReceptionFollowUpsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          ReceptionFollowUpsAtomPermissions.routeEntryUnion.isAllowed(
            noFacility,
          ),
          isTrue,
        );
      },
    );
  });

  group('Reception Follow-ups tab UI gates', () {
    testWidgets(
      'read-only: list visible; mutation atoms absent (∩ denial)',
      (WidgetTester tester) async {
        await _pumpFollowUpsTab(
          tester,
          opdRepository: opdRepository,
          followUpRepository: followUpRepository,
          accessPolicy: _readerPolicy(),
        );

        expect(_tab('Follow-ups'), findsOneWidget);
        expect(find.text('Follow Up Patient'), findsOneWidget);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Mark completed'), findsNothing);
        expect(find.text('Reschedule follow-up'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('writer: Register + Schedule present; detail writes mount', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(find.text('Register patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceptionFollowUpDetailDialog), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsOneWidget);
      expect(find.text('Mark completed'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
    });

    testWidgets(
      '∪ allowance: clinical:read shows Follow-ups; write absent',
      (WidgetTester tester) async {
        await _pumpFollowUpsTab(
          tester,
          opdRepository: opdRepository,
          followUpRepository: followUpRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
            roles: const <String>['DOCTOR'],
          ),
        );

        expect(_tab('Follow-ups'), findsOneWidget);
        expect(find.text('Follow Up Patient'), findsOneWidget);
        expect(find.text('Register patient'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);

        await tester.tap(find.text('Follow Up Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Reschedule follow-up'), findsNothing);
        expect(find.text('Mark completed'), findsNothing);
        expect(find.text('Close'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ denial: last_office:read enters shell; Follow-ups tab collapsed',
      (WidgetTester tester) async {
        await _pumpFollowUpsTab(
          tester,
          opdRepository: opdRepository,
          followUpRepository: followUpRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.lastOfficeRead},
            roles: const <String>['RECEPTIONIST'],
          ),
        );

        expect(_tab('Follow-ups'), findsNothing);
        expect(find.text('Follow Up Patient'), findsNothing);
        expect(find.text('Register patient'), findsNothing);
        // No authorized desk sections → forbidden deep-link feedback.
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _readerPolicy(),
        followUps: const <ReceptionFollowUpEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(AppStateView), findsOneWidget);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _readerPolicy(),
        failFollowUps: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport: read-only hides write + Schedule', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.text('Schedule appointment'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('desktop dark theme: writer mutations still mount', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Schedule appointment'), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Mark completed'), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsOneWidget);
    });

    testWidgets('post-mutation sync: Mark completed refreshes list', (
      WidgetTester tester,
    ) async {
      when(
        () => followUpRepository.completeFollowUp(
          any(),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => const Result<void>.success(null));

      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<ReceptionFollowUpEntry>>.success(
          <ReceptionFollowUpEntry>[],
        ),
      );

      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();

      verify(
        () => followUpRepository.completeFollowUp(
          'fu-rx-1',
          notes: any(named: 'notes'),
        ),
      ).called(1);
      expect(find.text('Follow Up Patient'), findsNothing);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
    });

    testWidgets('reschedule entry opens nested save dialog when write ∩', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reschedule follow-up'));
      await tester.pumpAndSettle();

      expect(find.byType(ClinicalFollowUpActionDialog), findsOneWidget);
    });

    testWidgets('integration: section=follow-ups deep link selects tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpFollowUpsTab(
        tester,
        opdRepository: opdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _readerPolicy(),
        initialLocation: '/reception?section=follow-ups',
      );

      expect(router.state.uri.queryParameters['section'], 'follow-ups');
      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.text('Follow Up Patient'), findsOneWidget);
    });

    testWidgets(
      'row detail writeRequirement maps to Follow-ups write ∩',
      (WidgetTester tester) async {
        await _pumpFollowUpsTab(
          tester,
          opdRepository: opdRepository,
          followUpRepository: followUpRepository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Follow Up Patient'));
        await tester.pumpAndSettle();

        final ReceptionFollowUpDetailDialog dialog = tester
            .widget<ReceptionFollowUpDetailDialog>(
              find.byType(ReceptionFollowUpDetailDialog),
            );
        expect(
          dialog.writeRequirement,
          same(ReceptionFollowUpsAtomPermissions.write),
        );
      },
    );
  });
}
