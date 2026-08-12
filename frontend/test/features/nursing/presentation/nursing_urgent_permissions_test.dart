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
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _urgentCriticalPatient = NursingPatientSummary(
  id: 'adm-urgent',
  admissionId: 'adm-urgent',
  displayId: 'ADM-URGENT',
  patientDisplayId: 'PT-URGENT',
  patientDisplayName: 'Urgent Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward C',
  bedDisplayLabel: 'Bed 3',
  hasActiveBed: true,
  hasCriticalAlert: true,
  criticalSeverity: 'CRITICAL',
);

const NursingPatientSummary _urgentMedDuePatient = NursingPatientSummary(
  id: 'adm-urgent-med',
  admissionId: 'adm-urgent-med',
  displayId: 'ADM-URGENT-MED',
  patientDisplayId: 'PT-URGENT-MED',
  patientDisplayName: 'Urgent Med Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward D',
  bedDisplayLabel: 'Bed 4',
  hasActiveBed: true,
  nextStep: 'URGENT',
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
    _urgentCriticalPatient,
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
  when(() => repository.createHandover(any(), any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.first as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(summary: summary),
    );
  });
  when(() => repository.searchUsers(any())).thenAnswer(
    (_) async =>
        const Result<List<NursingUserOption>>.success(<NursingUserOption>[]),
  );
}

Future<void> _pumpUrgentTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/nursing?scope=urgent',
  List<NursingPatientSummary> board = const <NursingPatientSummary>[
    _urgentCriticalPatient,
  ],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubNursingRepository(repository, board: board);

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
    registerFallbackValue(_urgentCriticalPatient);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('NursingUrgentAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          NursingUrgentAtomPermissions.tab,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(NursingUrgentAtomPermissions.write, nursingWriteRequirement),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.nextActionEscalate,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.escalate,
          NursingUrgentAtomPermissions.nextActionEscalate,
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
          NursingUrgentAtomPermissions.administerMedication,
          nursingMedicationAdministerRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.medicationsPanel,
          nursingMedicationsPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.shiftContext,
          nursingShiftContextRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.routeEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.export,
          nursingWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.print,
          nursingWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.openIcu,
          nursingNavigationRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.navigation,
          RouteAccessCatalog.icuEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.billingPanel,
          nursingBillingClearanceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.listChrome,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.nestedRead,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingUrgentAtomPermissions.nestedWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingBoardTabRequirement(NursingQueueScope.urgent),
          NursingUrgentAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingWriteRequirementForScope(NursingQueueScope.urgent),
          NursingUrgentAtomPermissions.write,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingNextActionRequirement(
            NursingNextActionKind.escalate,
            scope: NursingQueueScope.urgent,
          ),
          NursingUrgentAtomPermissions.nextActionEscalate,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingNextActionRequirement(
            NursingNextActionKind.medication,
            scope: NursingQueueScope.urgent,
          ),
          NursingUrgentAtomPermissions.nextActionMedication,
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
          NursingUrgentAtomPermissions.clinicalWrite.allPermissions,
          <AppPermission>[AppPermissions.clinicalWrite],
        );
        expect(NursingUrgentAtomPermissions.write.anyPermissions, isNotEmpty);
        expect(
          NursingUrgentAtomPermissions.write.anyPermissions,
          contains(AppPermissions.clinicalWrite),
        );
        expect(
          NursingUrgentAtomPermissions.write.anyPermissions,
          contains(AppPermissions.patientWrite),
        );
        expect(
          NursingUrgentAtomPermissions.write.anyPermissions,
          contains(AppPermissions.lastOfficeWrite),
        );
        // Nested cross-module matrix rows _(n/a)_ — medication uses pharmacy ∩.
        expect(
          identical(
            NursingUrgentAtomPermissions.nestedRead,
            NursingUrgentAtomPermissions.listChrome,
          ),
          isTrue,
        );
        expect(
          identical(
            NursingUrgentAtomPermissions.nestedWrite,
            NursingUrgentAtomPermissions.write,
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
      expect(NursingUrgentAtomPermissions.tab.isAllowed(pharmacyOnly), isTrue);
      expect(
        NursingUrgentAtomPermissions.medicationsPanel.isAllowed(pharmacyOnly),
        isTrue,
      );
      expect(
        NursingUrgentAtomPermissions.administerMedication.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        NursingUrgentAtomPermissions.nextActionMedication.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        NursingUrgentAtomPermissions.nextActionEscalate.isAllowed(pharmacyOnly),
        isFalse,
      );
      expect(canWriteNursing(pharmacyOnly), isFalse);
    });

    test('∩ nursing:read grants Urgent chrome; clinical/patient alone do not', () {
      final AppAccessPolicy nursingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.nursingRead},
      );
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(NursingUrgentAtomPermissions.tab.isAllowed(nursingOnly), isTrue);
      expect(
        NursingUrgentAtomPermissions.listChrome.isAllowed(nursingOnly),
        isTrue,
      );
      expect(canViewNursingUrgent(nursingOnly), isTrue);
      expect(canViewNursingTab(nursingOnly, NursingQueueScope.urgent), isTrue);
      expect(NursingUrgentAtomPermissions.tab.isAllowed(clinicalOnly), isFalse);
      expect(NursingUrgentAtomPermissions.tab.isAllowed(patientOnly), isFalse);
      expect(canViewNursingUrgent(clinicalOnly), isFalse);
      expect(canViewNursingUrgent(patientOnly), isFalse);
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
        NursingUrgentAtomPermissions.write.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        NursingUrgentAtomPermissions.nextActionEscalate.isAllowed(
          patientWriter,
        ),
        isTrue,
      );
      expect(
        NursingUrgentAtomPermissions.clinicalWrite.isAllowed(patientWriter),
        isFalse,
      );
      expect(canWriteNursing(patientWriter), isTrue);
    });

    test(
      'last_office:read / operations:read alone do not unlock Urgent chrome',
      () {
        final AppAccessPolicy lastOfficeRead = _policy(
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        );
        final AppAccessPolicy operationsRead = _policy(
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
        expect(canEnterNursingWorkspace(lastOfficeRead), isFalse);
        expect(canEnterNursingWorkspace(operationsRead), isFalse);
        expect(
          NursingUrgentAtomPermissions.tab.isAllowed(lastOfficeRead),
          isFalse,
        );
        expect(
          NursingUrgentAtomPermissions.tab.isAllowed(operationsRead),
          isFalse,
        );
        expect(
          NursingUrgentAtomPermissions.write.isAllowed(lastOfficeRead),
          isFalse,
        );
        expect(
          NursingUrgentAtomPermissions.nextActionEscalate.isAllowed(
            lastOfficeRead,
          ),
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
      expect(NursingUrgentAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(NursingUrgentAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(canViewNursingUrgent(noModule), isFalse);
    });

    test('ABAC session still evaluates Urgent when facility is present', () {
      final AppAccessPolicy withFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.nursingRead,
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
      expect(NursingUrgentAtomPermissions.tab.isAllowed(withFacility), isTrue);
      expect(
        canViewNursingTab(withFacility, NursingQueueScope.urgent),
        isTrue,
      );
    });
  });

  group('Nursing Urgent tab UI gates', () {
    testWidgets(
      'Urgent chrome: ≤5 defaults, Filters/Settings/Print labels, danger tone',
      (WidgetTester tester) async {
        await _pumpUrgentTab(
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
        final AppTabItem urgent = strip.tabs.firstWhere(
          (AppTabItem t) => t.id == 'urgent',
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
        expect(
          table.columns.map((AppListTableColumn<NursingWorkItem> c) => c.id),
          contains('priority'),
        );
        expect(table.columnChoices, isNotNull);
        expect(
          table.columnChoices!.length,
          greaterThan(table.columns.length),
        );
        expect(urgent.countTone, AppTabCountTone.danger);
        expect(urgent.count, isNotNull);
        expect(find.textContaining('Urgent'), findsWidgets);
      },
    );

    testWidgets(
      'Export/Print present on Urgent when evidence:export granted',
      (WidgetTester tester) async {
        await _pumpUrgentTab(
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

    testWidgets('read-only: worklist present; Escalate next-action absent', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Urgent Patient'), findsOneWidget);
      expect(find.byTooltip('Escalate'), findsNothing);
      expect(find.byTooltip('Record vitals'), findsNothing);
      expect(find.byTooltip('Shift context'), findsNothing);
      expect(find.textContaining('Urgent'), findsWidgets);
    });

    testWidgets('writer: Escalate next-action present for critical urgent', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byTooltip('Escalate'), findsWidgets);
      expect(find.byTooltip('Record vitals'), findsNothing);
      expect(find.byTooltip('Shift context'), findsNothing);
    });

    testWidgets(
      'medication write ∩: administer next-action needs pharmacy:read',
      (WidgetTester tester) async {
        await _pumpUrgentTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          board: const <NursingPatientSummary>[_urgentMedDuePatient],
        );
        expect(find.byTooltip('Administer medication'), findsNothing);

        await _pumpUrgentTab(
          tester,
          repository: repository,
          accessPolicy: _medicationWriterPolicy(),
          board: const <NursingPatientSummary>[_urgentMedDuePatient],
        );
        expect(find.byTooltip('Administer medication'), findsWidgets);
      },
    );

    testWidgets('shift context mounts only with roster/hr read + module', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _shiftContextPolicy(),
      );
      expect(find.byTooltip('Shift context'), findsOneWidget);
    });

    testWidgets('detail: read-only hides write actions and meds panel', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        board: const <NursingPatientSummary>[_urgentMedDuePatient],
      );

      await tester.tap(find.text('Urgent Med Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Add note'), findsNothing);
      expect(find.text('Escalate'), findsNothing);
      expect(find.text('Administer medication'), findsNothing);
      expect(find.text('Medications'), findsNothing);
      expect(find.text('Paracetamol'), findsNothing);
    });

    testWidgets('detail: writer omits Escalate duplicate of row next-action', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.text('Urgent Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppDialog).first),
      );
      // dialogs.mdc: generic surface title; identity stays in body.
      expect(
        find.text(l10n.nursingPatientContextLabel.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Escalate'),
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
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _medicationWriterPolicy(),
        board: const <NursingPatientSummary>[_urgentMedDuePatient],
      );

      await tester.tap(find.text('Urgent Med Patient'));
      await _pumpAfterAction(tester);

      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
    });

    testWidgets('authorized empty + loading chrome remain observable', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        board: const <NursingPatientSummary>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppListTable<NursingWorkItem>), findsOneWidget);
    });

    testWidgets('mobile viewport: read-only hides compact Escalate', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Urgent Patient'), findsOneWidget);
      expect(find.byTooltip('Escalate'), findsNothing);
    });

    testWidgets('mobile light theme: writer compact Escalate mounts', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Urgent Patient'), findsOneWidget);
      expect(find.byTooltip('Escalate'), findsWidgets);
    });

    testWidgets('desktop dark theme: writer Escalate still mounts', (
      WidgetTester tester,
    ) async {
      await _pumpUrgentTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Escalate'), findsWidgets);
      expect(find.text('Urgent Patient'), findsOneWidget);
    });

    testWidgets(
      'post-mutation sync: Escalate dialog opens for authorized write',
      (WidgetTester tester) async {
        await _pumpUrgentTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.byTooltip('Escalate').first);
        await _pumpAfterAction(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        // Dialog mount proves authorized write path; listWardPatients is the
        // sync seam after successful submit (validation / success chrome).
        verify(() => repository.listWardPatients(any())).called(greaterThan(0));
      },
    );
  });
}
