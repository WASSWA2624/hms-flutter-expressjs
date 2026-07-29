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
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _dischargePending = NursingPatientSummary(
  id: 'adm-disc',
  admissionId: 'adm-disc',
  displayId: 'ADM-DISC',
  patientDisplayId: 'PT-DISC',
  patientDisplayName: 'Discharge Pending Patient',
  stage: 'DISCHARGE_PLANNED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward D',
  bedDisplayLabel: 'Bed 4',
  hasActiveBed: true,
  dischargeStatus: 'PLANNED',
);

const NursingPatientDetail _dischargeDetail = NursingPatientDetail(
  summary: _dischargePending,
  latestDischarge: NursingDischargeSummary(
    id: 'ds-1',
    status: 'PLANNED',
    summary: 'Awaiting billing clearance.',
  ),
  medicationSuggestions: <MedicationSuggestion>[
    MedicationSuggestion(
      id: 'rx-1',
      medicationLabel: 'Amoxicillin',
      dose: '500',
      unit: 'mg',
      route: 'ORAL',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
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
  final bool needsPharmacy = permissions.contains(AppPermissions.pharmacyRead);
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final bool needsRoster = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.rosterRead ||
        permission == AppPermissions.hrRead ||
        permission == AppPermissions.unitRead,
  );
  final bool needsNursing = permissions.contains(AppPermissions.nursingRead);
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
        if (needsBilling)
          const AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        if (needsRoster)
          const AppModuleEntitlement(
            code: 'hr-rosters',
            licenseStatus: 'ACTIVE',
          ),
        if (needsNursing)
          const AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockNursingRepository repository, {
  List<NursingPatientSummary> items = const <NursingPatientSummary>[
    _dischargePending,
  ],
  NursingPatientDetail? detailOverride,
  Result<AppPage<NursingPatientSummary>>? listOverride,
}) {
  when(() => repository.listWardPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
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
    if (detailOverride != null) {
      return Result<NursingPatientDetail>.success(detailOverride);
    }
    final NursingPatientSummary summary =
        invocation.positionalArguments.single as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: summary,
        latestDischarge: _dischargeDetail.latestDischarge,
        medicationSuggestions: _dischargeDetail.medicationSuggestions,
      ),
    );
  });
  when(() => repository.addNursingNote(any(), any())).thenAnswer(
    (_) async => Result<NursingPatientDetail>.success(_dischargeDetail),
  );
}

Future<void> _pumpDischargePendingTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  Result<AppPage<NursingPatientSummary>>? listOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, listOverride: listOverride);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/nursing?scope=discharge-pending',
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
    registerFallbackValue(_dischargePending);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('NursingDischargePendingAtomPermissions helpers', () {
    test('reuses shared nursing *Requirement helpers (no second vocabulary)', () {
      expect(
        NursingDischargePendingAtomPermissions.tab,
        same(nursingWorkspaceReadRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.write,
        same(nursingWriteRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.nextActionDischarge,
        same(nursingWriteRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.clinicalWrite,
        same(nursingClinicalWriteRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.medicationsPanel,
        same(nursingMedicationsPanelRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.administerMedication,
        same(nursingMedicationAdministerRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.administerMedication,
        same(nursingMedicationWriteRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.billingPanel,
        same(nursingBillingClearanceReadRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.shiftContext,
        same(nursingShiftContextRequirement),
      );
      expect(
        NursingDischargePendingAtomPermissions.routeEntry,
        same(RouteAccessCatalog.nursingEntry),
      );
      expect(
        NursingDischargePendingAtomPermissions.nestedRead,
        same(nursingNestedCrossModuleReadRequirement),
      );
      expect(
        nursingBoardTabRequirement(NursingQueueScope.dischargePending),
        same(NursingDischargePendingAtomPermissions.tab),
      );
      expect(
        NursingPatientDetailDialog.writeRequirement,
        same(nursingWriteRequirement),
      );
    });

    test('∪ allowance: clinical:read alone shows Discharge pending tab', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(clinical),
        isTrue,
      );
      expect(canViewNursingTab(clinical, NursingQueueScope.dischargePending), isTrue);
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(clinical),
        isFalse,
      );
    });

    test('∪ allowance: patient:read alone shows Discharge pending tab', () {
      final AppAccessPolicy patient = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(patient),
        isTrue,
      );
      expect(canReadNursing(patient), isTrue);
    });

    test('last_office:read alone must not unlock write controls', () {
      final AppAccessPolicy lastOffice = _policy(
        permissions: <AppPermission>{
          AppPermissions.lastOfficeRead,
          AppPermissions.clinicalRead,
        },
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(lastOffice),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(lastOffice),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.nestedRead.isAllowed(lastOffice),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.billingPanel.isAllowed(
          lastOffice,
        ),
        isFalse,
      );
    });

    test('∩ denial: clinical:write without pharmacy:read strips med administer', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.administerMedication.isAllowed(
          writer,
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.medicationsPanel.isAllowed(
          writer,
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
        NursingDischargePendingAtomPermissions.administerMedication.isAllowed(
          withPharmacy,
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.medicationsPanel.isAllowed(
          withPharmacy,
        ),
        isTrue,
      );
    });

    test('subscription strips write when inpatient module missing', () {
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
        NursingDischargePendingAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested billing clearance needs billing:read ∩ billing-payments', () {
      final AppAccessPolicy nurseOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        NursingDischargePendingAtomPermissions.billingPanel.isAllowed(
          nurseOnly,
        ),
        isFalse,
      );

      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.billingRead,
        },
      );
      expect(
        NursingDischargePendingAtomPermissions.billingPanel.isAllowed(
          withBilling,
        ),
        isTrue,
      );
      expect(canViewNursingBillingClearance(withBilling), isTrue);
    });
  });

  testWidgets(
    'read-only ∪: Discharge pending list chrome mounts; write next-action absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Discharge Pending Patient'), findsOneWidget);
      expect(find.textContaining('Discharge pending'), findsWidgets);
      expect(find.byTooltip('Discharge clearance'), findsNothing);
      expect(find.byTooltip('Shift context'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'full write ∪: Discharge clearance next-action mounts (desktop + light)',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        NursingDischargePendingAtomPermissions.nextActionDischarge.isAllowed(
          writer,
        ),
        isTrue,
      );

      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Discharge Pending Patient'), findsOneWidget);
      expect(find.byTooltip('Discharge clearance'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile viewport: compact next-action trailing mounts for writers',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.byTooltip('Discharge clearance'), findsWidgets);
    },
  );

  testWidgets('dark theme: authorized empty state remains observable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpDischargePendingTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
      listOverride: Result<AppPage<NursingPatientSummary>>.success(
        AppPage<NursingPatientSummary>(
          items: const <NursingPatientSummary>[],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 0,
        ),
      ),
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.nursingNoWorklistTitle), findsOneWidget);
    expect(find.text(l10n.nursingNoWorklistBody), findsOneWidget);
  });

  testWidgets(
    'authorized write: open detail shows billing when billing:read; meds when pharmacy:read',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
        },
      );
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      await tester.tap(find.text('Discharge Pending Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.text(l10n.nursingMedicationsTitle), findsOneWidget);
      expect(find.text(l10n.dischargeBillingSectionTitle), findsOneWidget);
      // Checklist still exposes discharge clearance when write is allowed;
      // Quick Actions omits the row next-action duplicate.
      expect(find.text(l10n.nursingActionDischargeClearance), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized discharge clearance mutation syncs worklist after success',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.byTooltip('Discharge clearance').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Discharge nursing clearance'), findsWidgets);
      // Complete one clearance checkbox + confirm, then submit.
      final Finder checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);
      await tester.tap(checkboxes.first);
      await tester.pump();
      await tester.tap(checkboxes.last);
      await tester.pump();

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.text('Discharge nursing clearance').first),
      );
      await tester.tap(find.text(l10n.nursingActionDischargeClearance).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(() => repository.addNursingNote(any(), any())).called(1);
      verify(() => repository.listWardPatients(any())).called(greaterThan(0));
    },
  );

  testWidgets('shift context absent without roster ∩; present with roster:read', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy withoutRoster = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpDischargePendingTab(
      tester,
      repository: repository,
      accessPolicy: withoutRoster,
    );
    expect(find.byTooltip('Shift context'), findsNothing);

    final AppAccessPolicy withRoster = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.rosterRead,
      },
    );
    await _pumpDischargePendingTab(
      tester,
      repository: repository,
      accessPolicy: withRoster,
    );
    expect(find.byTooltip('Shift context'), findsOneWidget);
  });
}
