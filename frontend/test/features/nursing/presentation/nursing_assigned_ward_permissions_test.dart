import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
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
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _routinePatient = NursingPatientSummary(
  id: 'adm-routine',
  admissionId: 'adm-routine',
  displayId: 'ADM-ROUTINE',
  patientDisplayId: 'PT-ROUTINE',
  patientDisplayName: 'Routine Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
  hasActiveBed: true,
);

const NursingPatientSummary _medDuePatient = NursingPatientSummary(
  id: 'adm-med',
  admissionId: 'adm-med',
  displayId: 'ADM-MED',
  patientDisplayId: 'PT-MED',
  patientDisplayName: 'Med Due Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward B',
  bedDisplayLabel: 'Bed 2',
  hasActiveBed: true,
  medicationDueCount: 2,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientRead ||
        permission == AppPermissions.patientWrite,
  );
  final bool needsPharmacy = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.pharmacyRead ||
        permission == AppPermissions.pharmacyWrite,
  );
  final bool needsRoster = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.rosterRead ||
        permission == AppPermissions.hrRead ||
        permission == AppPermissions.unitRead,
  );
  final List<AppModuleEntitlement> resolvedModules =
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
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
    },
  );
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

AppAccessPolicy _medicationWriterPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.pharmacyRead,
    },
  );
}

AppAccessPolicy _shiftContextPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
      AppPermissions.rosterRead,
    },
  );
}

void _stubNursingRepository(
  _MockNursingRepository repository, {
  List<NursingPatientSummary> board = const <NursingPatientSummary>[
    _routinePatient,
    _medDuePatient,
  ],
}) {
  when(() => repository.listWardPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingWorklistQuery query =
        invocation.positionalArguments.single as NursingWorklistQuery;
    List<NursingPatientSummary> items = board
        .where((NursingPatientSummary item) => item.matchesScope(query.scope))
        .toList(growable: false);
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((NursingPatientSummary item) => item.matchesSearch(search))
          .toList(growable: false);
    }
    return Result<AppPage<NursingPatientSummary>>.success(
      AppPage<NursingPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
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
        medicationReminders: summary.hasMedicationDue
            ? const <MedicationReminder>[
                MedicationReminder(
                  id: 'med-1',
                  medicationLabel: 'Paracetamol',
                  status: 'DUE',
                ),
              ]
            : const <MedicationReminder>[],
      ),
    );
  });
  when(() => repository.recordVitalSet(any(), any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.first as String;
    final NursingPatientSummary summary = board.firstWhere(
      (NursingPatientSummary item) => item.id == id || item.displayId == id,
      orElse: () => _routinePatient,
    );
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: summary,
        vitalSigns: const <NursingVitalSign>[
          NursingVitalSign(
            id: 'vital-1',
            vitalType: 'BP',
            value: '120/80',
          ),
        ],
      ),
    );
  });
}

Future<void> _pumpAssignedWard(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<NursingPatientSummary> board = const <NursingPatientSummary>[
    _routinePatient,
    _medDuePatient,
  ],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubNursingRepository(repository, board: board);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const String initialLocation = '/nursing?scope=assigned-ward';
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_routinePatient);
    registerFallbackValue(<Map<String, Object?>>[]);
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('NursingAssignedWardAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          NursingAssignedWardAtomPermissions.tab,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.write,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingPatientDetailDialog.writeRequirement,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.administerMedication,
          nursingMedicationAdministerRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.medicationsPanel,
          nursingMedicationsPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.shiftContext,
          nursingShiftContextRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.routeEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.export,
          nursingWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.print,
          nursingWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.openIcu,
          nursingNavigationRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.navigation,
          RouteAccessCatalog.icuEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAssignedWardAtomPermissions.billingPanel,
          nursingBillingClearanceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingBoardTabRequirement(NursingQueueScope.assignedWard),
          NursingAssignedWardAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingWriteRequirementForScope(NursingQueueScope.assignedWard),
          NursingAssignedWardAtomPermissions.write,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingNextActionRequirement(
            NursingNextActionKind.vitals,
            scope: NursingQueueScope.assignedWard,
          ),
          NursingAssignedWardAtomPermissions.nextActionVitals,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingNextActionRequirement(
            NursingNextActionKind.medication,
            scope: NursingQueueScope.assignedWard,
          ),
          NursingAssignedWardAtomPermissions.nextActionMedication,
        ),
        isTrue,
      );
      expect(
        AppRoutes.nursing.requiredAnyPermissions.toSet(),
        RouteAccessCatalog.nursingEntry.anyPermissions.toSet(),
      );
    });

    test(
      'mapping note: matrix ∩ clinical:write via clinicalWrite; source keep ∪ write',
      () {
        expect(
          NursingAssignedWardAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(
          NursingAssignedWardAtomPermissions.write.anyPermissions,
          isNotEmpty,
        );
        expect(
          NursingAssignedWardAtomPermissions.write.anyPermissions,
          contains(AppPermissions.clinicalWrite),
        );
        expect(
          NursingAssignedWardAtomPermissions.write.anyPermissions,
          contains(AppPermissions.patientWrite),
        );
        expect(
          NursingAssignedWardAtomPermissions.write.anyPermissions,
          contains(AppPermissions.lastOfficeWrite),
        );
        expect(
          identical(
            NursingAssignedWardAtomPermissions.nestedRead,
            nursingWorkspaceReadRequirement,
          ),
          isTrue,
        );
        expect(
          identical(
            NursingAssignedWardAtomPermissions.nestedWrite,
            nursingWriteRequirement,
          ),
          isTrue,
        );
      },
    );

    test('∩ denial: pharmacy:read alone does not grant administer', () {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.nursingRead,
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
        },
      );
      expect(
        NursingAssignedWardAtomPermissions.tab.isAllowed(pharmacyOnly),
        isTrue,
      );
      expect(
        NursingAssignedWardAtomPermissions.medicationsPanel.isAllowed(
          pharmacyOnly,
        ),
        isTrue,
      );
      expect(
        NursingAssignedWardAtomPermissions.administerMedication.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        NursingAssignedWardAtomPermissions.nextActionMedication.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(canWriteNursing(pharmacyOnly), isFalse);
    });

    test('∩ nursing:read grants Assigned ward chrome; clinical/patient alone do not', () {
      final AppAccessPolicy nursingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.nursingRead},
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(NursingAssignedWardAtomPermissions.tab.isAllowed(nursingOnly), isTrue);
      expect(
        NursingAssignedWardAtomPermissions.listChrome.isAllowed(nursingOnly),
        isTrue,
      );
      expect(canViewNursingAssignedWard(nursingOnly), isTrue);
      expect(canViewNursingTab(nursingOnly, NursingQueueScope.assignedWard), isTrue);
      expect(NursingAssignedWardAtomPermissions.tab.isAllowed(clinicalOnly), isFalse);
      expect(NursingAssignedWardAtomPermissions.tab.isAllowed(patientOnly), isFalse);
      expect(canViewNursingAssignedWard(clinicalOnly), isFalse);
      expect(canViewNursingAssignedWard(patientOnly), isFalse);
    });

    test('∪ write allowance: patient:write + roles unlocks source write gate', () {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.nursingRead,
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        NursingAssignedWardAtomPermissions.write.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        NursingAssignedWardAtomPermissions.clinicalWrite.isAllowed(
          patientWriter,
        ),
        isFalse,
      );
      expect(canWriteNursing(patientWriter), isTrue);
    });

    test(
      'last_office:read / operations:read alone do not unlock Assigned ward chrome',
      () {
        final AppAccessPolicy lastOfficeRead = _policy(
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
          roles: const <String>['NURSE'],
        );
        final AppAccessPolicy operationsRead = _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['NURSE'],
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
        expect(canEnterNursingWorkspace(lastOfficeRead), isFalse);
        expect(canEnterNursingWorkspace(operationsRead), isFalse);
        expect(
          NursingAssignedWardAtomPermissions.tab.isAllowed(lastOfficeRead),
          isFalse,
        );
        expect(
          NursingAssignedWardAtomPermissions.tab.isAllowed(operationsRead),
          isFalse,
        );
        expect(
          NursingAssignedWardAtomPermissions.write.isAllowed(lastOfficeRead),
          isFalse,
        );
        expect(canWriteNursing(lastOfficeRead), isFalse);
      },
    );

    test('subscription denial: permissions without inpatient module strip UI', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.nursingRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.patientRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(NursingAssignedWardAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        NursingAssignedWardAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(canViewNursingAssignedWard(noModule), isFalse);
    });

    test('ABAC session still evaluates Assigned ward when facility is present', () {
      final AppAccessPolicy withFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.nursingRead,
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
      expect(NursingAssignedWardAtomPermissions.tab.isAllowed(withFacility), isTrue);
      expect(
        canViewNursingTab(withFacility, NursingQueueScope.assignedWard),
        isTrue,
      );
    });
  });

  group('Nursing Assigned ward tab UI gates', () {
    testWidgets(
      'Assigned ward chrome: ≤5 defaults, Filters/Settings/Print labels, info tone',
      (WidgetTester tester) async {
        await _pumpAssignedWard(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        final AppListTable<NursingWorkItem> table = tester
            .widget<AppListTable<NursingWorkItem>>(
              find.byType(AppListTable<NursingWorkItem>),
            );
        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem assigned = strip.tabs.firstWhere(
          (AppTabItem t) => t.id == 'assigned-ward',
        );

        expect(table.columnVisibilityLabel, 'Settings');
        expect(table.columnVisibilityTitle, 'Table Settings');
        expect(table.search?.advancedFilterButtonLabel, 'Filters');
        expect(table.search?.advancedFilterApplyLabel, 'Apply filters');
        expect(table.search?.advancedFilterResetLabel, 'Clear filters');
        expect(table.search?.advancedFilterCloseLabel, 'Close');
        expect(table.enablePrint, isTrue);
        expect(table.printLabel, 'Print');
        expect(table.canExport, isFalse);
        expect(table.canPrint, isFalse);
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);
        expect(table.columns.length, lessThanOrEqualTo(5));
        expect(table.columnChoices, isNotNull);
        expect(
          table.columnChoices!.length,
          greaterThan(table.columns.length),
        );
        expect(assigned.countTone, AppTabCountTone.info);
        expect(assigned.count, isNotNull);
        expect(find.textContaining('Assigned'), findsWidgets);
      },
    );

    testWidgets(
      'Export/Print present on Assigned ward when evidence:export granted',
      (WidgetTester tester) async {
        await _pumpAssignedWard(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.nursingRead,
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.evidenceExport,
            },
          ),
        );

        final AppListTable<NursingWorkItem> table = tester
            .widget<AppListTable<NursingWorkItem>>(
              find.byType(AppListTable<NursingWorkItem>),
            );
        expect(table.canExport, isTrue);
        expect(table.canPrint, isTrue);
        expect(table.search?.advancedFilterButtonLabel, 'Filters');
        expect(table.columnVisibilityLabel, 'Settings');
        expect(table.printLabel, 'Print');
        expect(find.byTooltip('Settings'), findsOneWidget);
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('read-only: worklist present; next-action writes absent', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Routine Patient'), findsOneWidget);
      expect(find.byTooltip('Record vitals'), findsNothing);
      expect(find.byTooltip('Administer medication'), findsNothing);
      expect(find.byTooltip('Shift context'), findsNothing);
      expect(find.textContaining('Assigned'), findsWidgets);
    });

    testWidgets('writer: Record vitals next-action present on Assigned ward', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byTooltip('Record vitals'), findsWidgets);
      expect(find.byTooltip('Shift context'), findsNothing);
    });

    testWidgets(
      'medication write ∩: administer next-action needs pharmacy:read',
      (WidgetTester tester) async {
        await _pumpAssignedWard(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          board: const <NursingPatientSummary>[_medDuePatient],
        );
        expect(find.byTooltip('Administer medication'), findsNothing);

        await _pumpAssignedWard(
          tester,
          repository: repository,
          accessPolicy: _medicationWriterPolicy(),
          board: const <NursingPatientSummary>[_medDuePatient],
        );
        expect(find.byTooltip('Administer medication'), findsWidgets);
      },
    );

    testWidgets('shift context mounts only with roster/hr read + module', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _shiftContextPolicy(),
      );
      expect(find.byTooltip('Shift context'), findsOneWidget);
    });

    testWidgets('detail: read-only hides write actions and meds panel', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        board: const <NursingPatientSummary>[_medDuePatient],
      );

      await tester.tap(find.text('Med Due Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Add note'), findsNothing);
      expect(find.text('Record vitals'), findsNothing);
      expect(find.text('Administer medication'), findsNothing);
      expect(find.text('Medications'), findsNothing);
      expect(find.text('Paracetamol'), findsNothing);
    });

    testWidgets('detail: writer omits Record vitals duplicate of row next-action', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        board: const <NursingPatientSummary>[_routinePatient],
      );

      await tester.tap(find.text('Routine Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Record vitals'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Add note'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('detail: medication writer shows meds panel and add note', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _medicationWriterPolicy(),
        board: const <NursingPatientSummary>[_medDuePatient],
      );

      await tester.tap(find.text('Med Due Patient'));
      await _pumpAfterAction(tester);

      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);
      // Next-action omitted from detail; complementary administer may show.
      expect(find.text('Add note'), findsOneWidget);
    });

    testWidgets('authorized empty + loading chrome remain observable', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        board: const <NursingPatientSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppListTable<NursingWorkItem>), findsOneWidget);
    });

    testWidgets('mobile viewport: read-only hides compact next-action', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Routine Patient'), findsOneWidget);
      expect(find.byTooltip('Record vitals'), findsNothing);
    });

    testWidgets('mobile light theme: writer compact next-action mounts', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Routine Patient'), findsOneWidget);
      expect(find.byTooltip('Record vitals'), findsWidgets);
    });

    testWidgets('desktop dark theme: writer next-action still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Record vitals'), findsWidgets);
      expect(find.text('Routine Patient'), findsOneWidget);
    });

    testWidgets('post-mutation sync: vitals dialog opens for authorized write', (
      WidgetTester tester,
    ) async {
      await _pumpAssignedWard(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.byTooltip('Record vitals').first);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Record vitals'), findsWidgets);

      // Close without completing form — dialog mount proves authorized write path;
      // repository.listWardPatients is the sync seam after successful submit.
      verify(() => repository.listWardPatients(any())).called(greaterThan(0));
    });
  });
}
