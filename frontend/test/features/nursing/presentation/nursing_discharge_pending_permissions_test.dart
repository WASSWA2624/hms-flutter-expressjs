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
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
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
  icuStatus: 'ACTIVE',
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

const List<AppModuleEntitlement> _nursingModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: nursingInpatientBedModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['NURSE'],
  List<AppModuleEntitlement> modules = _nursingModules,
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        id: 'nurse-1',
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy({
  AppPermission readKey = AppPermissions.nursingRead,
}) {
  return _policy(permissions: <AppPermission>{readKey});
}

AppAccessPolicy _readWritePolicy() {
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

AppAccessPolicy _clinicalWriteOnlyPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    },
  );
}

AppAccessPolicy _patientWriteWithoutClinicalWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

AppAccessPolicy _lastOfficeReadOnlyPolicy() {
  return _policy(
    roles: const <String>['RECEPTION'],
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.lastOfficeRead,
      AppPermissions.clinicalRead,
    },
  );
}

AppAccessPolicy _shiftContextPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.rosterRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _medicationsPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.pharmacyRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _billingPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _fullNestedPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.nursingRead,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.pharmacyRead,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
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

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpDischargePendingTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  Result<AppPage<NursingPatientSummary>>? listOverride,
  String initialLocation = '/nursing?scope=discharge-pending',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, listOverride: listOverride);

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
  await _pumpAfterAction(tester);
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

  group('NursingDischargePendingAtomPermissions inventory (AC1)', () {
    test('reuses feature *Requirement vocabulary (no second map)', () {
      expect(
        identical(
          NursingDischargePendingAtomPermissions.tab,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.write,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.nextAction,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.nextActionDischarge,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.create,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.update,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.delete,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.panelDeepLink,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.complementaryWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.checklistWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.medicationsPanel,
          nursingMedicationsPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.administerMedication,
          nursingMedicationAdministerRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.billingPanel,
          nursingBillingClearanceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.nestedRead,
          nursingNestedCrossModuleReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.shiftContext,
          nursingShiftContextRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.routeEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.export,
          nursingWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.print,
          nursingWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.openIcu,
          nursingNavigationRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.navigation,
          RouteAccessCatalog.icuEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.catalogEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        NursingPatientDetailDialog.writeRequirement,
        same(nursingWriteRequirement),
      );
      expect(
        nursingNextActionRequirement(NursingNextActionKind.discharge),
        NursingDischargePendingAtomPermissions.nextActionDischarge,
      );
      expect(
        nursingNextActionRequirement(
          NursingNextActionKind.discharge,
          scope: NursingQueueScope.dischargePending,
        ),
        NursingDischargePendingAtomPermissions.nextActionDischarge,
      );
      expect(
        nursingBoardTabRequirement(NursingQueueScope.dischargePending),
        NursingDischargePendingAtomPermissions.tab,
      );
      expect(
        nursingWriteRequirementForScope(NursingQueueScope.dischargePending),
        NursingDischargePendingAtomPermissions.write,
      );
      expect(
        nursingFocusedPanelRequirement(NursingDetailPanel.discharge),
        NursingDischargePendingAtomPermissions.panelDeepLink,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          _readPolicy(),
          NursingQueueScope.dischargePending,
        ),
        isFalse,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          _clinicalWriteOnlyPolicy(),
          NursingQueueScope.dischargePending,
        ),
        isTrue,
      );
    });

    test('∩ denial: clinical:write required for discharge write', () {
      final AppAccessPolicy patientWriteOnly =
          _patientWriteWithoutClinicalWritePolicy();
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(_readPolicy()),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(
          patientWriteOnly,
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.nextActionDischarge.isAllowed(
          patientWriteOnly,
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(
          _clinicalWriteOnlyPolicy(),
        ),
        isTrue,
      );
    });

    test('∩ nursing:read grants tab read; clinical/patient alone do not', () {
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(
          _readPolicy(readKey: AppPermissions.nursingRead),
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(
          _readPolicy(readKey: AppPermissions.clinicalRead),
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(
          _readPolicy(readKey: AppPermissions.patientRead),
        ),
        isFalse,
      );
      expect(canViewNursingDischargePending(_readPolicy()), isTrue);
      expect(
        NursingDischargePendingAtomPermissions.listChrome.isAllowed(
          _readPolicy(),
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.create.isAllowed(_readPolicy()),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.success.isAllowed(_readPolicy()),
        isFalse,
      );
    });

    test('last_office:read alone does not unlock discharge writes', () {
      final AppAccessPolicy lastOfficeWithClinical =
          _lastOfficeReadOnlyPolicy();
      expect(
        NursingDischargePendingAtomPermissions.routeEntry.isAllowed(
          lastOfficeWithClinical,
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(
          lastOfficeWithClinical,
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.write.isAllowed(
          lastOfficeWithClinical,
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.nestedRead.isAllowed(
          lastOfficeWithClinical,
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.billingPanel.isAllowed(
          lastOfficeWithClinical,
        ),
        isFalse,
      );
      expect(canWriteNursing(lastOfficeWithClinical), isFalse);

      final AppAccessPolicy lastOfficeOnly = _policy(
        roles: const <String>['RECEPTION'],
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
      );
      expect(
        NursingDischargePendingAtomPermissions.routeEntry.isAllowed(
          lastOfficeOnly,
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(canViewNursingDischargePending(lastOfficeOnly), isFalse);
    });

    test(
      'source ∪ complementaryWrite allows patient:write without clinical:write',
      () {
        final AppAccessPolicy patientWriter =
            _patientWriteWithoutClinicalWritePolicy();
        expect(
          NursingDischargePendingAtomPermissions.write.isAllowed(
            patientWriter,
          ),
          isFalse,
        );
        expect(
          NursingDischargePendingAtomPermissions.complementaryWrite.isAllowed(
            patientWriter,
          ),
          isTrue,
        );
        expect(
          NursingDischargePendingAtomPermissions.addNote.isAllowed(
            patientWriter,
          ),
          isTrue,
        );
      },
    );

    test('subscription / module strip without inpatient-bed-management', () {
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

    test('∩ denial: pharmacy:read required for meds panel / administer', () {
      final AppAccessPolicy writer = _clinicalWriteOnlyPolicy();
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
        modules: const <AppModuleEntitlement>[
          ..._nursingModules,
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
        ],
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

    test('nested billing clearance needs billing:read ∩ billing-payments', () {
      expect(
        NursingDischargePendingAtomPermissions.billingPanel.isAllowed(
          _clinicalWriteOnlyPolicy(),
        ),
        isFalse,
      );
      expect(
        NursingDischargePendingAtomPermissions.billingPanel.isAllowed(
          _billingPanelPolicy(),
        ),
        isTrue,
      );
      expect(canViewNursingBillingClearance(_billingPanelPolicy()), isTrue);
    });

    test('nested ∪: billing:read OR last_office:read for nestedRead', () {
      expect(
        NursingDischargePendingAtomPermissions.nestedRead.isAllowed(
          _billingPanelPolicy(),
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.nestedRead.isAllowed(
          _lastOfficeReadOnlyPolicy(),
        ),
        isTrue,
      );
      expect(
        NursingDischargePendingAtomPermissions.nestedRead.isAllowed(
          _readPolicy(),
        ),
        isFalse,
      );
    });
  });

  group('Discharge pending UI authorization (AC2-AC5)', () {
    testWidgets(
      'read-only ∪: Discharge pending list chrome mounts; write next-action absent',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _readPolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(find.text('Discharge Pending Patient'), findsOneWidget);
        expect(
          find.textContaining(l10n.nursingScopeDischargePendingLabel),
          findsWidgets,
        );
        expect(
          find.byTooltip(l10n.nursingActionDischargeClearance),
          findsNothing,
        );
        expect(find.byTooltip(l10n.nursingShiftContextTitle), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expect(find.text(l10n.nursingNextActionColumnLabel), findsNothing);
      },
    );

    testWidgets(
      'full write ∩: Discharge clearance next-action mounts (desktop + light)',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _readWritePolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(find.text('Discharge Pending Patient'), findsOneWidget);
        expect(
          find.byTooltip(l10n.nursingActionDischargeClearance),
          findsWidgets,
        );
        expect(find.text(l10n.nursingNextActionColumnLabel), findsWidgets);
      },
    );

    testWidgets(
      '∩ denial: patient:write without clinical:write hides discharge CTA',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _patientWriteWithoutClinicalWritePolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(find.text('Discharge Pending Patient'), findsOneWidget);
        expect(
          find.byTooltip(l10n.nursingActionDischargeClearance),
          findsNothing,
        );
        expect(find.text(l10n.nursingNextActionColumnLabel), findsNothing);

        await tester.tap(find.text('Discharge Pending Patient'));
        await _pumpAfterAction(tester);

        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAddNote),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionDischargeClearance),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'mobile viewport: compact next-action trailing mounts for writers',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _clinicalWriteOnlyPolicy(),
          physicalSize: const Size(390, 844),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(find.byType(AppListTableMobileItem), findsWidgets);
        expect(
          find.byTooltip(l10n.nursingActionDischargeClearance),
          findsWidgets,
        );
      },
    );

    testWidgets('dark theme: authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _clinicalWriteOnlyPolicy(),
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

    testWidgets('light theme: read-only chrome without write affordances', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _readPolicy(),
        themeMode: ThemeMode.light,
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(find.text('Discharge Pending Patient'), findsOneWidget);
      expect(
        find.byTooltip(l10n.nursingActionDischargeClearance),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
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
            appAccessPolicyProvider.overrideWithValue(_readPolicy()),
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

    testWidgets('∩ nursing:read shows discharge-pending tab', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _readPolicy(readKey: AppPermissions.nursingRead),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(
        find.textContaining(l10n.nursingScopeDischargePendingLabel),
        findsWidgets,
      );
      expect(find.text('Discharge Pending Patient'), findsOneWidget);
      expect(
        find.byTooltip(l10n.nursingActionDischargeClearance),
        findsNothing,
      );
    });

    testWidgets('shift context mounts only with roster/ops + hr-rosters', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _shiftContextPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.byTooltip(l10n.nursingShiftContextTitle), findsOneWidget);
    });

    testWidgets(
      'authorized writer detail: complementary writes; discharge omitted as next-action',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _fullNestedPolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        await tester.tap(find.text('Discharge Pending Patient'));
        await _pumpAfterAction(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionDischargeClearance),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAddNote),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.nursingMedicationsTitle), findsOneWidget);
        expect(find.text(l10n.dischargeBillingSectionTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionOpenIcu),
          ),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('detail: billing panel absent without billing:read', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _clinicalWriteOnlyPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      await tester.tap(find.text('Discharge Pending Patient'));
      await _pumpAfterAction(tester);

      expect(find.text(l10n.dischargeBillingSectionTitle), findsNothing);
      expect(find.text(l10n.nursingMedicationsTitle), findsNothing);
    });

    testWidgets('detail: medications panel requires pharmacy:read', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _medicationsPanelPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      await tester.tap(find.text('Discharge Pending Patient'));
      await _pumpAfterAction(tester);

      expect(find.text(l10n.nursingMedicationsTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text(l10n.nursingActionDischargeClearance),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'authorized discharge clearance next-action opens dialog and syncs',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _readWritePolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        await tester
            .tap(find.byTooltip(l10n.nursingActionDischargeClearance).first);
        await _pumpAfterAction(tester);

        expect(find.byType(NursingDischargeClearanceDialog), findsOneWidget);

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(AppTabStrip)),
        );
        final NursingWorkspaceController controller = container.read(
          nursingWorkspaceControllerProvider.notifier,
        );
        final AppFailure? selectFailure = await controller.selectPatient(
          _dischargePending,
        );
        expect(selectFailure, isNull);
        verify(
          () => repository.loadPatientDetail(any()),
        ).called(greaterThan(0));
        verify(() => repository.listWardPatients(any())).called(greaterThan(0));
      },
    );
  });
}
