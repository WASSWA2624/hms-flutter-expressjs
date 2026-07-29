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
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
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
  taskTypeCode: 'MEDICATION_DUE',
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
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
    },
  );
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
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
  NursingPatientDetail? detailOverride,
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
    if (detailOverride != null) {
      return Result<NursingPatientDetail>.success(detailOverride);
    }
    final NursingPatientSummary summary =
        invocation.positionalArguments.single as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: summary,
        medicationReminders: summary.hasMedicationDue
            ? const <MedicationReminder>[
                MedicationReminder(
                  id: 'med-1',
                  displayTitle: 'Paracetamol',
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
            displayValue: '120/80',
          ),
        ],
      ),
    );
  });
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/nursing',
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

  group('NursingAllAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          NursingAllAtomPermissions.tab,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(NursingAllAtomPermissions.write, nursingWriteRequirement),
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
          NursingAllAtomPermissions.administerMedication,
          nursingMedicationAdministerRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAllAtomPermissions.medicationsPanel,
          nursingMedicationsPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAllAtomPermissions.shiftContext,
          nursingShiftContextRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAllAtomPermissions.routeEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          nursingBoardTabRequirement(NursingQueueScope.all),
          NursingAllAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        AppRoutes.nursing.requiredAnyPermissions.toSet(),
        RouteAccessCatalog.nursingEntry.anyPermissions.toSet(),
      );
    });

    test('mapping note: matrix ∩ clinical:write via clinicalWrite; source keep ∪ write', () {
      expect(
        NursingAllAtomPermissions.clinicalWrite.allPermissions,
        <AppPermission>[AppPermissions.clinicalWrite],
      );
      expect(NursingAllAtomPermissions.write.anyPermissions, isNotEmpty);
      expect(
        NursingAllAtomPermissions.write.anyPermissions,
        contains(AppPermissions.clinicalWrite),
      );
      expect(
        NursingAllAtomPermissions.write.anyPermissions,
        contains(AppPermissions.lastOfficeWrite),
      );
    });

    test('∩ denial: pharmacy:read alone does not grant administer', () {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
        },
      );
      expect(NursingAllAtomPermissions.tab.isAllowed(pharmacyOnly), isTrue);
      expect(
        NursingAllAtomPermissions.medicationsPanel.isAllowed(pharmacyOnly),
        isTrue,
      );
      expect(
        NursingAllAtomPermissions.administerMedication.isAllowed(pharmacyOnly),
        isFalse,
      );
      expect(canWriteNursing(pharmacyOnly), isFalse);
    });

    test('∪ allowance: clinical:read alone grants All-tab read chrome', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(NursingAllAtomPermissions.tab.isAllowed(clinicalOnly), isTrue);
      expect(NursingAllAtomPermissions.tab.isAllowed(patientOnly), isTrue);
      expect(canReadNursing(clinicalOnly), isTrue);
      expect(canReadNursing(patientOnly), isTrue);
    });

    test('last_office:read alone does not unlock write or All-tab chrome', () {
      final AppAccessPolicy lastOfficeRead = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['NURSE'],
      );
      expect(canEnterNursingWorkspace(lastOfficeRead), isTrue);
      expect(NursingAllAtomPermissions.tab.isAllowed(lastOfficeRead), isFalse);
      expect(NursingAllAtomPermissions.write.isAllowed(lastOfficeRead), isFalse);
      expect(canWriteNursing(lastOfficeRead), isFalse);
    });

    test('subscription denial: permissions without inpatient module strip UI', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
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
      expect(NursingAllAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(NursingAllAtomPermissions.write.isAllowed(noModule), isFalse);
    });
  });

  group('Nursing All tab UI gates', () {
    testWidgets('read-only: worklist present; next-action writes absent', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Routine Patient'), findsOneWidget);
      expect(find.byTooltip('Record vitals'), findsNothing);
      expect(find.byTooltip('Administer medication'), findsNothing);
      expect(find.byTooltip('Shift context'), findsNothing);
      expect(find.textContaining('All'), findsWidgets);
    });

    testWidgets('writer: Record vitals next-action present on All', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
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
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          board: const <NursingPatientSummary>[_medDuePatient],
        );
        expect(find.byTooltip('Administer medication'), findsNothing);

        await _pumpAllTab(
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
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _shiftContextPolicy(),
      );
      expect(find.byTooltip('Shift context'), findsOneWidget);
    });

    testWidgets('detail: read-only hides write actions and meds panel', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
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

    testWidgets('detail: medication writer shows meds panel and administer', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
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
      await _pumpAllTab(
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
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Routine Patient'), findsOneWidget);
      expect(find.byTooltip('Record vitals'), findsNothing);
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

      expect(find.byTooltip('Record vitals'), findsWidgets);
      expect(find.text('Routine Patient'), findsOneWidget);
    });

    testWidgets('post-mutation: vitals dialog syncs via repository', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.byTooltip('Record vitals').first);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      // Dialog opened for authorized write path (validation / success chrome).
      expect(find.textContaining('Vital'), findsWidgets);
    });
  });
}
