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
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _medDuePatient = NursingPatientSummary(
  id: 'adm-med-due',
  admissionId: 'adm-med-due',
  displayId: 'ADM-MED-DUE',
  patientDisplayId: 'PT-MED-DUE',
  patientDisplayName: 'Med Due Tab Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward M',
  bedDisplayLabel: 'Bed 9',
  hasActiveBed: true,
  medicationDueCount: 3,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission p) =>
        p == AppPermissions.clinicalRead || p == AppPermissions.clinicalWrite,
  );
  final bool needsPatient = permissions.any(
    (AppPermission p) =>
        p == AppPermissions.patientRead || p == AppPermissions.patientWrite,
  );
  final bool needsPharmacy = permissions.any(
    (AppPermission p) =>
        p == AppPermissions.pharmacyRead || p == AppPermissions.pharmacyWrite,
  );
  final bool needsRoster =
      permissions.contains(AppPermissions.rosterRead) ||
      permissions.contains(AppPermissions.hrRead) ||
      permissions.contains(AppPermissions.operationsRead) ||
      permissions.contains(AppPermissions.unitRead);

  final List<AppModuleEntitlement> resolved =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsPatient)
          const AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        if (needsPharmacy)
          const AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
        if (needsRoster)
          const AppModuleEntitlement(
            code: 'hr-rosters',
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
      moduleEntitlements: resolved,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readerPolicy({AppPermission readKey = AppPermissions.clinicalRead}) {
  return _policy(permissions: <AppPermission>{readKey});
}

AppAccessPolicy _fullMedicationPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
      AppPermissions.pharmacyRead,
      AppPermissions.rosterRead,
    },
  );
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

void _stubNursing(
  _MockNursingRepository repository, {
  List<NursingPatientSummary> items = const <NursingPatientSummary>[
    _medDuePatient,
  ],
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
    (_) async =>
        const Result<List<NursingHandover>>.success(<NursingHandover>[]),
  );
  when(() => repository.listCurrentRosters()).thenAnswer(
    (_) async => const Result<List<NursingRosterAssignment>>.success(
      <NursingRosterAssignment>[],
    ),
  );
  when(() => repository.loadPatientDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.single as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: summary,
        medicationAdministrations: const <MedicationAdministrationRecord>[
          MedicationAdministrationRecord(
            id: 'med-admin-1',
            dose: '500',
            unit: 'mg',
            route: 'ORAL',
          ),
        ],
      ),
    );
  });
}

Future<void> _pumpMedicationDueTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/nursing?scope=medication-due',
  List<NursingPatientSummary>? items,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubNursing(
    repository,
    items: items ?? const <NursingPatientSummary>[_medDuePatient],
  );

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

void main() {
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_medDuePatient);
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('NursingMedicationDueAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        NursingMedicationDueAtomPermissions.tab,
        same(nursingWorkspaceReadRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.readUnion,
        same(nursingWorkspaceReadRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.readIntersection,
        same(nursingMedicationDueReadIntersectionRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.listChrome,
        same(nursingWorkspaceReadRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.empty,
        same(nursingWorkspaceReadRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.nextActionMedication,
        same(nursingMedicationAdministerRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.administerMedication,
        same(nursingMedicationWriteRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.medicationsPanel,
        same(nursingMedicationsPanelRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.medicationDueCount,
        same(nursingMedicationsPanelRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.create,
        same(nursingClinicalWriteRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.update,
        same(nursingClinicalWriteRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.delete,
        same(nursingClinicalWriteRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.clinicalWrite,
        same(nursingClinicalWriteRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.complementaryWrite,
        same(nursingWriteRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.shiftContext,
        same(nursingShiftContextRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.panelDeepLink,
        same(nursingMedicationAdministerRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.routeEntry,
        same(nursingWorkspaceEntryRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.nursingEntry),
      );
      expect(
        nursingBoardTabRequirement(NursingQueueScope.medicationDue),
        same(NursingMedicationDueAtomPermissions.tab),
      );
      expect(
        nursingWriteRequirementForScope(NursingQueueScope.medicationDue),
        same(NursingMedicationDueAtomPermissions.write),
      );
      expect(
        nursingNextActionRequirement(NursingNextActionKind.medication),
        same(NursingMedicationDueAtomPermissions.nextActionMedication),
      );
      expect(
        nursingFocusedPanelRequirement(NursingDetailPanel.medication),
        same(NursingMedicationDueAtomPermissions.panelDeepLink),
      );
    });

    test('∪ allowance: patient:read alone satisfies tab / list chrome', () {
      final AppAccessPolicy patientReader = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(canViewNursingMedicationDue(patientReader), isTrue);
      expect(
        NursingMedicationDueAtomPermissions.tab.isAllowed(patientReader),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.listChrome.isAllowed(patientReader),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.readUnion.isAllowed(patientReader),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.medicationsPanel.isAllowed(
          patientReader,
        ),
        isFalse,
      );
      expect(
        NursingMedicationDueAtomPermissions.nextActionMedication.isAllowed(
          patientReader,
        ),
        isFalse,
      );
    });

    test('∪ allowance: clinical:read alone satisfies tab; not med panel', () {
      final AppAccessPolicy clinicalReader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewNursingMedicationDue(clinicalReader), isTrue);
      expect(
        NursingMedicationDueAtomPermissions.medicationsPanel.isAllowed(
          clinicalReader,
        ),
        isFalse,
      );
      expect(
        NursingMedicationDueAtomPermissions.readIntersection.isAllowed(
          clinicalReader,
        ),
        isFalse,
      );
    });

    test('∩ denial: missing pharmacy:read hides med panel / administer', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(canViewNursingMedicationDue(clinicalWriter), isTrue);
      expect(
        NursingMedicationDueAtomPermissions.medicationsPanel.isAllowed(
          clinicalWriter,
        ),
        isFalse,
      );
      expect(
        NursingMedicationDueAtomPermissions.nextActionMedication.isAllowed(
          clinicalWriter,
        ),
        isFalse,
      );
      expect(
        NursingMedicationDueAtomPermissions.readIntersection.isAllowed(
          clinicalWriter,
        ),
        isFalse,
      );
      expect(canAdministerNursingMedication(clinicalWriter), isFalse);
      expect(
        nursingBoardShowsNextActionColumn(
          clinicalWriter,
          NursingQueueScope.medicationDue,
        ),
        isFalse,
      );
    });

    test('∩ full set: pharmacy:read + clinical:write mounts administer', () {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.pharmacyRead,
        },
      );
      expect(
        NursingMedicationDueAtomPermissions.readIntersection.isAllowed(full),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.medicationsPanel.isAllowed(full),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.nextActionMedication.isAllowed(
          full,
        ),
        isTrue,
      );
      expect(canAdministerNursingMedication(full), isTrue);
      expect(
        nursingBoardShowsNextActionColumn(
          full,
          NursingQueueScope.medicationDue,
        ),
        isTrue,
      );
    });

    test('∪ write: pharmacy:write + pharmacy:read satisfies administer', () {
      final AppAccessPolicy pharmacyWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      );
      expect(
        NursingMedicationDueAtomPermissions.administerMedication.isAllowed(
          pharmacyWriter,
        ),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.clinicalWrite.isAllowed(
          pharmacyWriter,
        ),
        isFalse,
      );
    });

    test('last_office:read alone must not unlock write controls', () {
      final AppAccessPolicy lastOfficeReader = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(canViewNursingMedicationDue(lastOfficeReader), isFalse);
      expect(
        NursingMedicationDueAtomPermissions.write.isAllowed(lastOfficeReader),
        isFalse,
      );
      expect(
        NursingMedicationDueAtomPermissions.complementaryWrite.isAllowed(
          lastOfficeReader,
        ),
        isFalse,
      );
    });

    test('subscription strip: inpatient-bed-management required', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(NursingMedicationDueAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewNursingMedicationDue(noModule), isFalse);
      expect(
        NursingMedicationDueAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested cross-module matrix rows remain n/a (med panel only)', () {
      expect(
        NursingMedicationDueAtomPermissions.nestedRead,
        same(nursingMedicationsPanelRequirement),
      );
      expect(
        NursingMedicationDueAtomPermissions.nestedWrite,
        same(nursingMedicationAdministerRequirement),
      );
    });

    test(
      'route entry ∪ alone (last_office / operations) does not unlock tab chrome',
      () {
        final AppAccessPolicy lastOfficeReader = _policy(
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        );
        final AppAccessPolicy operationsReader = _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(canEnterNursingWorkspace(lastOfficeReader), isTrue);
        expect(canEnterNursingWorkspace(operationsReader), isTrue);
        expect(canViewNursingMedicationDue(lastOfficeReader), isFalse);
        expect(canViewNursingMedicationDue(operationsReader), isFalse);
      },
    );

    test('pharmacy:read alone does not unlock Medication due tab (∪ read)', () {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
      );
      expect(canViewNursingMedicationDue(pharmacyOnly), isFalse);
      expect(
        NursingMedicationDueAtomPermissions.medicationsPanel.isAllowed(
          pharmacyOnly,
        ),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.nextActionMedication.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
    });

    test('ABAC session still evaluates Medication due when facility present', () {
      final AppAccessPolicy withFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
      expect(
        NursingMedicationDueAtomPermissions.tab.isAllowed(withFacility),
        isTrue,
      );
      expect(
        canViewNursingTab(withFacility, NursingQueueScope.medicationDue),
        isTrue,
      );
    });

    test('matrix create/update/delete ∩ clinical:write mapping noted', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientWrite,
        },
      );
      // Stage Administer keeps pharmacy ∩; matrix CRUD ∩ is clinicalWrite.
      expect(
        NursingMedicationDueAtomPermissions.create.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.update.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.delete.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.clinicalWrite.isAllowed(
          clinicalWriter,
        ),
        isTrue,
      );
      // Complementary detail writes keep source ∪ (patient:write unlocks).
      expect(
        NursingMedicationDueAtomPermissions.complementaryWrite.isAllowed(
          patientWriter,
        ),
        isTrue,
      );
      expect(
        NursingMedicationDueAtomPermissions.clinicalWrite.isAllowed(
          patientWriter,
        ),
        isFalse,
      );
      expect(
        NursingMedicationDueAtomPermissions.nextActionMedication.isAllowed(
          clinicalWriter,
        ),
        isFalse,
      );
    });
  });

  group('Nursing Medication due tab UI gates', () {
    testWidgets(
      'read-only ∪: Medication due tab + list visible; writes / med panel absent',
      (WidgetTester tester) async {
        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.textContaining('Medication due'), findsWidgets);
        expect(find.text('Med Due Tab Patient'), findsOneWidget);
        expect(find.byTooltip('Administer medication'), findsNothing);
        expect(find.byTooltip('Shift context'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Med Due Tab Patient'));
        await _pumpAfterAction(tester);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppDialog).first),
        );
        expect(find.text(l10n.nursingMedicationsTitle), findsNothing);
        expect(find.text(l10n.nursingActionAdministerMedication), findsNothing);
        expect(find.text(l10n.nursingActionAddNote), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: patient:read alone shows Medication due tab chrome',
      (WidgetTester tester) async {
        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(readKey: AppPermissions.patientRead),
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        expect(
          find.textContaining(l10n.nursingScopeMedicationDueLabel),
          findsWidgets,
        );
        expect(find.text('Med Due Tab Patient'), findsOneWidget);
        expect(find.byTooltip('Administer medication'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ denial: clinical write without pharmacy:read hides Administer',
      (WidgetTester tester) async {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.patientWrite,
          },
        );

        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: clinicalWriter,
        );

        expect(find.text('Med Due Tab Patient'), findsOneWidget);
        expect(find.byTooltip('Administer medication'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'full ∩: Administer next-action + med due count + detail meds present',
      (WidgetTester tester) async {
        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: _fullMedicationPolicy(),
        );

        expect(find.byTooltip('Administer medication'), findsWidgets);
        expect(find.text('3'), findsWidgets);
        expect(find.byTooltip('Shift context'), findsOneWidget);

        await tester.tap(find.text('Med Due Tab Patient'));
        await _pumpAfterAction(tester);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppDialog).first),
        );
        // Row next-action is sole primary; detail omits Administer duplicate.
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAdministerMedication),
          ),
          findsNothing,
        );
        expect(find.text(l10n.nursingMedicationsTitle), findsOneWidget);
        expect(find.text(l10n.nursingActionAddNote), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('authorized empty worklist state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpMedicationDueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        items: const <NursingPatientSummary>[],
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.text(l10n.nursingNoWorklistTitle), findsOneWidget);
      expect(find.byType(AppListTable<NursingWorkItem>), findsOneWidget);
    });

    testWidgets('error / retry state remains for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.listWardPatients(any())).thenAnswer(
        (_) async => const Result<AppPage<NursingPatientSummary>>.failure(
          AppFailure.network(),
        ),
      );
      when(() => repository.listPendingHandovers()).thenAnswer(
        (_) async =>
            const Result<List<NursingHandover>>.success(<NursingHandover>[]),
      );
      when(() => repository.listCurrentRosters()).thenAnswer(
        (_) async => const Result<List<NursingRosterAssignment>>.success(
          <NursingRosterAssignment>[],
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/nursing?scope=medication-due',
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
            appAccessPolicyProvider.overrideWithValue(_readerPolicy()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await _pumpAfterAction(tester);

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('mobile viewport: compact Administer trailing when authorized', (
      WidgetTester tester,
    ) async {
      await _pumpMedicationDueTab(
        tester,
        repository: repository,
        accessPolicy: _fullMedicationPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.byTooltip('Administer medication'), findsWidgets);
    });

    testWidgets('mobile light theme: read-only hides compact Administer', (
      WidgetTester tester,
    ) async {
      await _pumpMedicationDueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Med Due Tab Patient'), findsOneWidget);
      expect(find.byTooltip('Administer medication'), findsNothing);
    });

    testWidgets('desktop dark theme: authorized Medication due chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpMedicationDueTab(
        tester,
        repository: repository,
        accessPolicy: _fullMedicationPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.textContaining('Medication due'), findsWidgets);
      expect(find.byTooltip('Administer medication'), findsWidgets);
      expect(find.text('Med Due Tab Patient'), findsOneWidget);
    });

    testWidgets('light theme: read-only chrome without write affordances', (
      WidgetTester tester,
    ) async {
      await _pumpMedicationDueTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Med Due Tab Patient'), findsOneWidget);
      expect(find.byTooltip('Administer medication'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'panel=medication deep link opens Administer when ∩ allowed',
      (WidgetTester tester) async {
        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: _fullMedicationPolicy(),
          initialLocation:
              '/nursing?scope=medication-due&id=ADM-MED-DUE&panel=medication',
        );

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        verify(() => repository.loadPatientDetail(any())).called(greaterThan(0));
      },
    );

    testWidgets(
      'panel=medication deep link falls back when pharmacy:read missing',
      (WidgetTester tester) async {
        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
          ),
          initialLocation:
              '/nursing?scope=medication-due&id=ADM-MED-DUE&panel=medication',
        );

        // Restricted deep link → patient detail (no Administer dialog).
        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppDialog).first),
        );
        expect(find.text(l10n.nursingActionAdministerMedication), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'post-mutation sync: Administer dialog mounts for full ∩ policy',
      (WidgetTester tester) async {
        await _pumpMedicationDueTab(
          tester,
          repository: repository,
          accessPolicy: _fullMedicationPolicy(),
        );

        await tester.tap(find.byTooltip('Administer medication').first);
        await _pumpAfterAction(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        // Dialog mount proves authorized write path; listWardPatients is the
        // sync seam after successful submit (validation / success chrome).
        verify(() => repository.listWardPatients(any())).called(greaterThan(0));
        verify(() => repository.loadPatientDetail(any())).called(greaterThan(0));
      },
    );
  });
}
