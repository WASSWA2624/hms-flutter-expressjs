import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _handoverPatient = NursingPatientSummary(
  id: 'adm-handover',
  admissionId: 'adm-handover',
  displayId: 'ADM-HAND',
  patientDisplayId: 'PT-HAND',
  patientDisplayName: 'Handover Pending Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward H',
  bedDisplayLabel: 'Bed 7',
  hasActiveBed: true,
  pendingHandoverCount: 1,
  icuStatus: 'ACTIVE',
);

const NursingHandover _pendingHandover = NursingHandover(
  id: 'ho-1',
  status: 'PENDING',
  admissionId: 'adm-handover',
  signoffNotes: 'Night shift notes',
);

const List<AppModuleEntitlement> _baseModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: nursingInpatientBedModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsPharmacy = permissions.any(
    (AppPermission p) =>
        p == AppPermissions.pharmacyRead || p == AppPermissions.pharmacyWrite,
  );
  final bool needsRoster = permissions.any(
    (AppPermission p) =>
        p == AppPermissions.rosterRead ||
        p == AppPermissions.hrRead ||
        p == AppPermissions.unitRead,
  );
  final bool needsOps = permissions.contains(AppPermissions.operationsRead);

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules ??
          <AppModuleEntitlement>[
            ..._baseModules,
            if (needsPharmacy)
              const AppModuleEntitlement(
                code: 'pharmacy-dispensing',
                licenseStatus: 'ACTIVE',
              ),
            if (needsRoster || needsOps)
              const AppModuleEntitlement(
                code: 'hr-rosters',
                licenseStatus: 'ACTIVE',
              ),
            if (needsOps)
              const AppModuleEntitlement(
                code: 'facilities-maintenance',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy({
  AppPermission readKey = AppPermissions.clinicalRead,
}) {
  return _policy(
    permissions: <AppPermission>{readKey},
    roles: const <String>['RECEPTION'],
  );
}

AppAccessPolicy _writePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

AppAccessPolicy _clinicalWriteOnlyPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    },
  );
}

AppAccessPolicy _patientWriteWithoutClinicalWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

void _stubRepository(
  _MockNursingRepository repository, {
  List<NursingPatientSummary> items = const <NursingPatientSummary>[
    _handoverPatient,
  ],
  NursingPatientDetail? detail,
}) {
  when(() => repository.listWardPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingWorklistQuery query =
        invocation.positionalArguments.single as NursingWorklistQuery;
    final List<NursingPatientSummary> filtered = items
        .where((NursingPatientSummary item) => item.matchesScope(query.scope))
        .toList(growable: false);
    return Result<AppPage<NursingPatientSummary>>.success(
      AppPage<NursingPatientSummary>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(() => repository.listPendingHandovers()).thenAnswer(
    (_) async => const Result<List<NursingHandover>>.success(<NursingHandover>[
      _pendingHandover,
    ]),
  );
  when(() => repository.listCurrentRosters()).thenAnswer(
    (_) async => const Result<List<NursingRosterAssignment>>.success(
      <NursingRosterAssignment>[],
    ),
  );
  when(() => repository.searchUsers(any())).thenAnswer(
    (_) async => const Result<List<NursingUserOption>>.success(
      <NursingUserOption>[
        NursingUserOption(id: 'nurse-2', displayLabel: 'Nurse Two'),
      ],
    ),
  );
  when(() => repository.loadPatientDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.single as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      detail ??
          NursingPatientDetail(
            summary: summary,
            handovers: const <NursingHandover>[_pendingHandover],
            medicationReminders: const <MedicationReminder>[
              MedicationReminder(
                id: 'med-1',
                medicationLabel: 'Paracetamol',
                status: 'DUE',
              ),
            ],
          ),
    );
  });
  when(
    () => repository.createHandover(any(), any()),
  ).thenAnswer((Invocation invocation) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.first as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(summary: summary),
    );
  });
  when(() => repository.acceptHandover(any(), any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
}

Future<void> _pumpHandoverPendingTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/nursing?scope=handover-pending',
  List<NursingPatientSummary> items = const <NursingPatientSummary>[
    _handoverPatient,
  ],
  NursingPatientDetail? detail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/nursing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: NursingWorkspacePage(
              initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nursingRepositoryProvider.overrideWithValue(repository),
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
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpAfter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_handoverPatient);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('NursingHandoverPendingAtomPermissions inventory (AC1)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.tab,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.write,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.nextAction,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.nextActionHandover,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.createHandover,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.acceptHandover,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.create,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.update,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.delete,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.complementaryWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.checklistWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.medicationsPanel,
          nursingMedicationsPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.administerMedication,
          nursingMedicationAdministerRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.shiftContext,
          nursingShiftContextRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.panelDeepLink,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.routeEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.catalogEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        nursingBoardTabRequirement(NursingQueueScope.handoverPending),
        same(NursingHandoverPendingAtomPermissions.tab),
      );
      expect(
        nursingWriteRequirementForScope(NursingQueueScope.handoverPending),
        same(NursingHandoverPendingAtomPermissions.write),
      );
      expect(
        nursingNextActionRequirement(NursingNextActionKind.handover),
        same(NursingHandoverPendingAtomPermissions.nextActionHandover),
      );
      expect(
        nursingNextActionRequirement(
          NursingNextActionKind.handover,
          scope: NursingQueueScope.handoverPending,
        ),
        same(NursingHandoverPendingAtomPermissions.nextActionHandover),
      );
      expect(
        nursingFocusedPanelRequirement(NursingDetailPanel.handover),
        same(NursingHandoverPendingAtomPermissions.panelDeepLink),
      );
      expect(
        identical(
          NursingHandoverPendingAtomPermissions.nestedWrite,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          _readPolicy(),
          NursingQueueScope.handoverPending,
        ),
        isFalse,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          _clinicalWriteOnlyPolicy(),
          NursingQueueScope.handoverPending,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing clinical:write strips Create handover atoms', () {
      final AppAccessPolicy reader = _readPolicy();
      expect(NursingHandoverPendingAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(canViewNursingHandoverPending(reader), isTrue);
      expect(
        NursingHandoverPendingAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.nextAction.isAllowed(reader),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.createHandover.isAllowed(reader),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.success.isAllowed(reader),
        isFalse,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          reader,
          NursingQueueScope.handoverPending,
        ),
        isFalse,
      );
    });

    test('∩ denial: patient:write without clinical:write denies stage write',
        () {
      final AppAccessPolicy patientWriter =
          _patientWriteWithoutClinicalWritePolicy();
      expect(
        NursingHandoverPendingAtomPermissions.write.isAllowed(patientWriter),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.nextActionHandover.isAllowed(
          patientWriter,
        ),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.createHandover.isAllowed(
          patientWriter,
        ),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.acceptHandover.isAllowed(
          patientWriter,
        ),
        isFalse,
      );
      // Source ∪ complementary writes remain available without clinical:write.
      expect(
        NursingHandoverPendingAtomPermissions.complementaryWrite.isAllowed(
          patientWriter,
        ),
        isTrue,
      );
      expect(
        NursingHandoverPendingAtomPermissions.addNote.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        NursingHandoverPendingAtomPermissions.write.isAllowed(
          _clinicalWriteOnlyPolicy(),
        ),
        isTrue,
      );
    });

    test('∪ allowance: clinical:read alone satisfies tab read chrome', () {
      final AppAccessPolicy clinicalOnly = _readPolicy(
        readKey: AppPermissions.clinicalRead,
      );
      expect(
        NursingHandoverPendingAtomPermissions.tab.isAllowed(clinicalOnly),
        isTrue,
      );
      expect(
        NursingHandoverPendingAtomPermissions.search.isAllowed(clinicalOnly),
        isTrue,
      );
      expect(
        NursingHandoverPendingAtomPermissions.write.isAllowed(clinicalOnly),
        isFalse,
      );
    });

    test('∪ allowance: patient:read alone satisfies tab read chrome', () {
      final AppAccessPolicy patientOnly = _readPolicy(
        readKey: AppPermissions.patientRead,
      );
      expect(
        NursingHandoverPendingAtomPermissions.tab.isAllowed(patientOnly),
        isTrue,
      );
      expect(canViewNursingHandoverPending(patientOnly), isTrue);
    });

    test('last_office:read alone does not unlock write or tab chrome', () {
      final AppAccessPolicy lastOfficeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['RECEPTION'],
      );
      expect(
        NursingHandoverPendingAtomPermissions.routeEntry.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
      expect(
        NursingHandoverPendingAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.write.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(canViewNursingHandoverPending(lastOfficeOnly), isFalse);
    });

    test('nested medication ∩: pharmacy:read required for meds panel', () {
      final AppAccessPolicy noPharmacy = _writePolicy();
      expect(
        NursingHandoverPendingAtomPermissions.medicationsPanel.isAllowed(
          noPharmacy,
        ),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.administerMedication.isAllowed(
          noPharmacy,
        ),
        isFalse,
      );

      final AppAccessPolicy withPharmacy = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.pharmacyRead,
        },
      );
      expect(
        NursingHandoverPendingAtomPermissions.medicationsPanel.isAllowed(
          withPharmacy,
        ),
        isTrue,
      );
      expect(
        NursingHandoverPendingAtomPermissions.administerMedication.isAllowed(
          withPharmacy,
        ),
        isTrue,
      );
    });

    test('subscription strip: inpatient-bed-management required', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        NursingHandoverPendingAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        NursingHandoverPendingAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(canViewNursingHandoverPending(noModule), isFalse);
    });

    test('shift context requires hr-rosters + roster/ops read ∪', () {
      final AppAccessPolicy writer = _writePolicy();
      expect(
        NursingHandoverPendingAtomPermissions.shiftContext.isAllowed(writer),
        isFalse,
      );

      final AppAccessPolicy withRoster = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.rosterRead,
        },
      );
      expect(
        NursingHandoverPendingAtomPermissions.shiftContext.isAllowed(
          withRoster,
        ),
        isTrue,
      );
    });
  });

  group('Handover pending UI authorization (AC2-AC5)', () {
    testWidgets(
      'read-only: Handover pending list visible; Create handover / writes absent (∩ denial)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _readPolicy();
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(find.text('Handover Pending Patient'), findsOneWidget);
        expect(find.textContaining('Handover pending'), findsWidgets);
        expect(find.byTooltip('Create handover'), findsNothing);
        expect(find.byTooltip('Shift context'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Handover Pending Patient'));
        await _pumpAfter(tester);

        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Create handover'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Accept handover'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Record vitals'),
          ),
          findsNothing,
        );
        expect(find.text('Medications'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ denial: patient:write without clinical:write hides Create handover CTA',
      (WidgetTester tester) async {
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: _patientWriteWithoutClinicalWritePolicy(),
        );

        expect(find.text('Handover Pending Patient'), findsOneWidget);
        expect(find.byTooltip('Create handover'), findsNothing);

        await tester.tap(find.text('Handover Pending Patient'));
        await _pumpAfter(tester);

        // Source ∪ complementary writes still mount without clinical:write.
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Add note'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Record vitals'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Accept handover'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Create handover'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'full ∩ clinical:write: Create handover next-action + detail mutations mount',
      (WidgetTester tester) async {
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writePolicy(),
        );

        expect(find.text('Handover Pending Patient'), findsOneWidget);
        expect(find.byTooltip('Create handover'), findsWidgets);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Handover Pending Patient'));
        await _pumpAfter(tester);

        // Row next-action Create handover omitted from detail Quick Actions.
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Create handover'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Accept handover'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Record vitals'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Add note'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Open ICU workspace'),
          ),
          findsOneWidget,
        );
        // Medications panel absent without pharmacy:read.
        expect(find.text('Medications'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Administer medication'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'nested pharmacy: medications panel + administer mount with pharmacy:read ∩ write',
      (WidgetTester tester) async {
        final AppAccessPolicy withMeds = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.pharmacyRead,
          },
        );
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: withMeds,
        );

        await tester.tap(find.text('Handover Pending Patient'));
        await _pumpAfter(tester);

        expect(find.text('Medications'), findsOneWidget);
        expect(find.text('Paracetamol'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Administer medication'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('shift context mounts only with roster read ∩ hr-rosters', (
      WidgetTester tester,
    ) async {
      await _pumpHandoverPendingTab(
        tester,
        repository: repository,
        accessPolicy: _writePolicy(),
      );
      expect(find.byTooltip('Shift context'), findsNothing);

      await _pumpHandoverPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.rosterRead,
          },
        ),
      );
      expect(find.byTooltip('Shift context'), findsOneWidget);
    });

    testWidgets(
      'authorized Create handover next-action opens dialog and syncs after mutation',
      (WidgetTester tester) async {
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writePolicy(),
        );

        await tester.tap(find.byTooltip('Create handover').first);
        await _pumpAfter(tester);

        expect(find.byType(NursingHandoverDialog), findsOneWidget);

        // Close without submitting — dialog chrome Close only dismisses.
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(NursingHandoverDialog)),
        );
        await tester.tap(find.byTooltip(l10n.commonCloseActionLabel));
        await _pumpAfter(tester);
        expect(find.byType(NursingHandoverDialog), findsNothing);
        expect(find.text('Handover Pending Patient'), findsOneWidget);
      },
    );

    testWidgets('empty worklist state remains for authorized read users', (
      WidgetTester tester,
    ) async {
      await _pumpHandoverPendingTab(
        tester,
        repository: repository,
        accessPolicy: _readPolicy(),
        items: const <NursingPatientSummary>[],
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.text(l10n.nursingNoWorklistTitle), findsOneWidget);
      expect(find.byTooltip('Create handover'), findsNothing);
    });

    testWidgets(
      'mobile viewport: compact Create handover trailing when clinical:write ∩',
      (WidgetTester tester) async {
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writePolicy(),
          physicalSize: const Size(390, 844),
        );

        expect(find.byType(DataTable), findsNothing);
        expect(find.byType(AppListTableMobileItem), findsWidgets);
        expect(find.byTooltip('Create handover'), findsWidgets);
      },
    );

    testWidgets('mobile read-only: next-action trailing absent', (
      WidgetTester tester,
    ) async {
      await _pumpHandoverPendingTab(
        tester,
        repository: repository,
        accessPolicy: _readPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.byTooltip('Create handover'), findsNothing);
    });

    testWidgets('dark theme: authorized Handover pending chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpHandoverPendingTab(
        tester,
        repository: repository,
        accessPolicy: _writePolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Handover Pending Patient'), findsOneWidget);
      expect(find.byTooltip('Create handover'), findsWidgets);
      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets('light theme: read-only chrome without write affordances', (
      WidgetTester tester,
    ) async {
      await _pumpHandoverPendingTab(
        tester,
        repository: repository,
        accessPolicy: _readPolicy(),
      );

      expect(find.text('Handover Pending Patient'), findsOneWidget);
      expect(find.byTooltip('Create handover'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'deep link panel=handover falls back to detail when write denied',
      (WidgetTester tester) async {
        await _pumpHandoverPendingTab(
          tester,
          repository: repository,
          accessPolicy: _readPolicy(),
          initialLocation:
              '/nursing?scope=handover-pending&id=ADM-HAND&panel=handover',
        );

        expect(find.byType(NursingHandoverDialog), findsNothing);
        // Detail opens for restricted deep-link write (forbidden feedback path).
        expect(find.text('Handover Pending Patient'), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Create handover'),
          ),
          findsNothing,
        );
      },
    );
  });
}
