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
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _planned = IpdAdmissionSummary(
  id: 'adm-planned',
  displayId: 'ADM-P1',
  patientDisplayName: 'Alice Planned',
  stage: 'DISCHARGE_PLANNED',
  dischargeStatus: 'PLANNED',
  wardDisplayName: 'Ward A',
  clearancePhase: 'MEDICATION_PENDING',
);

const IpdAdmissionSummary _pending = IpdAdmissionSummary(
  id: 'adm-pending',
  displayId: 'ADM-S1',
  patientDisplayName: 'Bob Pending',
  stage: 'ADMITTED',
  dischargeStatus: 'SUMMARY_PENDING',
  wardDisplayName: 'Ward B',
  clearancePhase: 'MEDICATION_PENDING',
);

const IpdAdmissionSummary _completed = IpdAdmissionSummary(
  id: 'adm-done',
  displayId: 'ADM-C1',
  patientDisplayName: 'Carol Completed',
  stage: 'DISCHARGED',
  dischargeStatus: 'COMPLETED',
  wardDisplayName: 'Ward C',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsPharmacy = permissions.contains(AppPermissions.pharmacyRead);
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final bool needsOperations = permissions.contains(
    AppPermissions.operationsRead,
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
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
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

void _stubQueue(
  _MockDischargeRepository repository, {
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[_pending],
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  DischargeAdmissionDetail? detailOverride,
}) {
  when(() => repository.listQueue(any())).thenAnswer((_) async {
    if (listOverride != null) {
      return listOverride;
    }
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
  when(() => repository.getAdmissionDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<DischargeAdmissionDetail>.success(detailOverride);
    }
    final String id = invocation.positionalArguments.first as String;
    final IpdAdmissionSummary summary = items.firstWhere(
      (IpdAdmissionSummary item) =>
          item.id == id || item.displayId == id || item.apiId == id,
      orElse: () => items.first,
    );
    return Result<DischargeAdmissionDetail>.success(
      DischargeAdmissionDetail(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        encounterId: 'encounter-1',
        ipd: IpdAdmissionDetail(
          summary: summary,
          nursingNotes: const <IpdClinicalRecord>[
            IpdClinicalRecord(id: 'note-1', kind: 'NURSING_NOTE'),
          ],
        ),
        pharmacyOrders: const <DischargeRelatedRecord>[
          DischargeRelatedRecord(
            id: 'rx-1',
            kind: 'pharmacy_order',
            title: 'Amoxicillin',
            status: 'ORDERED',
          ),
        ],
        invoices: const <DischargeRelatedRecord>[
          DischargeRelatedRecord(
            id: 'inv-1',
            kind: 'invoice',
            title: 'Final bill',
            status: 'ISSUED',
            billingStatus: 'ISSUED',
          ),
        ],
      ),
    );
  });
  when(
    () => repository.createFinalInvoice(any()),
  ).thenAnswer((_) async => const Result<void>.success(null));
}

Future<void> _pumpPendingClearanceTab(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  DischargeAdmissionDetail? detailOverride,
  String initialLocation = '/discharge?section=pending-clearance',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubQueue(
    repository,
    items: items ?? <IpdAdmissionSummary>[_pending],
    listOverride: listOverride,
    detailOverride: detailOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: DischargeWorkspacePage(
              initialQuery: DischargeWorklistQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dischargeRepositoryProvider.overrideWithValue(repository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
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
}

void main() {
  late _MockDischargeRepository repository;

  setUpAll(() {
    registerFallbackValue(const DischargeWorklistQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockDischargeRepository();
  });

  group('DischargePendingClearanceAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        DischargePendingClearanceAtomPermissions.tab,
        same(dischargePendingClearanceReadRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.write,
        same(dischargeClinicalWriteRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.nextActionPlan,
        same(dischargeClinicalWriteRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.billingPanel,
        same(billingReadRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.medicinesPanel,
        same(dischargePharmacyClearanceReadRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.roomTurnover,
        same(dischargeOperationsClearanceReadRequirement),
      );
      expect(
        dischargeSectionTabRequirement(DischargeDeskSection.pendingClearance),
        same(dischargePendingClearanceReadRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.routeEntry,
        same(dischargeWorkspaceEntryRequirement),
      );
      expect(
        DischargePendingClearanceAtomPermissions.medicinesPanel,
        same(DischargeAllPatientsAtomPermissions.medicinesPanel),
      );
      expect(
        DischargePendingClearanceAtomPermissions.write,
        same(DischargeAllPatientsAtomPermissions.write),
      );
      expect(
        DischargePendingClearanceAtomPermissions.nextActionPlan,
        same(DischargeAllPatientsAtomPermissions.nextActionPlan),
      );
      expect(
        dischargeDetailPrintRequirement(DischargeDeskSection.pendingClearance),
        same(DischargePendingClearanceAtomPermissions.printSummary),
      );
      expect(
        dischargeDetailPrintRequirement(DischargeDeskSection.all),
        same(DischargeAllPatientsAtomPermissions.printSummary),
      );
    });

    test('∩ denial: clinical:write missing hides write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargePendingClearanceAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        DischargePendingClearanceAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargePendingClearanceAtomPermissions.nextActionPlan.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        DischargePendingClearanceAtomPermissions.requestBilling.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(canWriteDischarge(reader), isFalse);
    });

    test('∪ allowance: pharmacy:read alone satisfies Pending clearance read', () {
      final AppAccessPolicy pharmacy = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        roles: const <String>['PHARMACIST'],
      );
      expect(
        DischargePendingClearanceAtomPermissions.tab.isAllowed(pharmacy),
        isTrue,
      );
      expect(
        DischargePendingClearanceAtomPermissions.listChrome.isAllowed(pharmacy),
        isTrue,
      );
      expect(
        DischargePendingClearanceAtomPermissions.write.isAllowed(pharmacy),
        isFalse,
      );
      expect(canViewDischargePendingClearance(pharmacy), isTrue);
      expect(canViewDischargeAll(pharmacy), isFalse);
      expect(canViewDischargePlanned(pharmacy), isFalse);
      expect(canViewDischargeCompleted(pharmacy), isFalse);
    });

    test('∪ allowance: billing:read alone satisfies Pending clearance read', () {
      final AppAccessPolicy billing = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        roles: const <String>['BILLING'],
      );
      expect(
        DischargePendingClearanceAtomPermissions.tab.isAllowed(billing),
        isTrue,
      );
      expect(canReadDischargePendingClearance(billing), isTrue);
    });

    test(
      '∪ allowance: operations:read alone satisfies Pending clearance read',
      () {
        final AppAccessPolicy operations = _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['OPERATIONS'],
        );
        expect(
          DischargePendingClearanceAtomPermissions.tab.isAllowed(operations),
          isTrue,
        );
      },
    );

    test('∪ allowance: clinical:read alone satisfies Pending clearance read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargePendingClearanceAtomPermissions.tab.isAllowed(clinical),
        isTrue,
      );
      expect(
        canViewDischargeSection(clinical, DischargeDeskSection.pendingClearance),
        isTrue,
      );
    });

    test('∪ allowance: last_office:read alone satisfies Pending clearance read', () {
      final AppAccessPolicy nursing = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['NURSE'],
      );
      expect(
        DischargePendingClearanceAtomPermissions.tab.isAllowed(nursing),
        isTrue,
      );
      expect(
        DischargePendingClearanceAtomPermissions.write.isAllowed(nursing),
        isFalse,
      );
    });

    test(
      'route entry keeps source discharge:read (not prompt ∪ of module reads)',
      () {
        // Source: RouteAccessCatalog.dischargeEntry = ∩ discharge:read +
        // inpatient-bed-management. Prompt lists clinical|pharmacy|billing|
        // operations ∪ — keep catalog and note the mapping here.
        final AppAccessPolicy pharmacyOnly = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
          roles: const <String>['PHARMACIST'],
        );
        expect(
          DischargePendingClearanceAtomPermissions.routeEntry.isAllowed(
            pharmacyOnly,
          ),
          isFalse,
        );
        expect(
          DischargePendingClearanceAtomPermissions.tab.isAllowed(pharmacyOnly),
          isTrue,
        );

        final AppAccessPolicy withDischargeRead = _policy(
          permissions: <AppPermission>{AppPermissions.dischargeRead},
          roles: const <String>['PHARMACIST'],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          DischargePendingClearanceAtomPermissions.routeEntry.isAllowed(
            withDischargeRead,
          ),
          isTrue,
        );
        // discharge:read alone is not in Pending tab read ∪.
        expect(
          DischargePendingClearanceAtomPermissions.tab.isAllowed(
            withDischargeRead,
          ),
          isFalse,
        );
      },
    );

    test('subscription strip: missing inpatient module denies Pending', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.pharmacyRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        DischargePendingClearanceAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        DischargePendingClearanceAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(canViewDischargePendingClearance(noModule), isFalse);
    });

    test('nested clearance reads ∩ per domain (union across sections)', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargePendingClearanceAtomPermissions.medicinesPanel.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
      expect(
        DischargePendingClearanceAtomPermissions.billingPanel.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
      expect(
        DischargePendingClearanceAtomPermissions.roomTurnover.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );

      final List<DischargeClearanceItem> all = const <DischargeClearanceItem>[
        DischargeClearanceItem(
          code: DischargeClearanceCode.doctor,
          state: DischargeClearanceState.complete,
        ),
        DischargeClearanceItem(
          code: DischargeClearanceCode.pharmacy,
          state: DischargeClearanceState.pending,
        ),
        DischargeClearanceItem(
          code: DischargeClearanceCode.billing,
          state: DischargeClearanceState.pending,
        ),
        DischargeClearanceItem(
          code: DischargeClearanceCode.bedRelease,
          state: DischargeClearanceState.pending,
        ),
      ];
      expect(
        dischargeVisibleClearanceItems(clinicalOnly, all)
            .map((DischargeClearanceItem item) => item.code),
        <DischargeClearanceCode>[DischargeClearanceCode.doctor],
      );

      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        roles: const <String>['PHARMACIST'],
      );
      expect(
        dischargeVisibleClearanceItems(pharmacyOnly, all)
            .map((DischargeClearanceItem item) => item.code),
        <DischargeClearanceCode>[DischargeClearanceCode.pharmacy],
      );

      final AppAccessPolicy withNested = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
          AppPermissions.operationsRead,
        },
      );
      expect(
        DischargePendingClearanceAtomPermissions.medicinesPanel.isAllowed(
          withNested,
        ),
        isTrue,
      );
      expect(
        DischargePendingClearanceAtomPermissions.billingPanel.isAllowed(
          withNested,
        ),
        isTrue,
      );
      expect(
        DischargePendingClearanceAtomPermissions.roomTurnover.isAllowed(
          withNested,
        ),
        isTrue,
      );
      expect(dischargeVisibleClearanceItems(withNested, all).length, all.length);
    });
  });

  testWidgets(
    'read-only: Pending list visible; Start plan absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Bob Pending'), findsOneWidget);
      expect(find.textContaining('Pending clearance'), findsWidgets);
      expect(find.byTooltip('Start discharge plan'), findsNothing);
      expect(find.byTooltip('Manage clearance'), findsNothing);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Start discharge plan'), findsNothing);
      expect(find.text('Request final billing'), findsNothing);
      expect(find.text('Request medicines'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Start plan and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byTooltip('Start discharge plan'), findsOneWidget);
      expect(find.byTooltip('Manage clearance'), findsNothing);

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Start discharge plan'), findsWidgets);
      expect(find.text('Request final billing'), findsOneWidget);
      expect(find.text('Request medicines'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ pharmacy:read shows Pending clearance chrome without All/Planned',
    (WidgetTester tester) async {
      final AppAccessPolicy pharmacy = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        roles: const <String>['PHARMACIST'],
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: pharmacy,
        items: <IpdAdmissionSummary>[_pending, _planned, _completed],
      );

      expect(find.textContaining('Pending clearance'), findsWidgets);
      expect(find.text('Bob Pending'), findsOneWidget);
      expect(find.textContaining('All patients'), findsNothing);
      expect(find.textContaining('Planned'), findsNothing);
      expect(find.textContaining('Completed'), findsNothing);
      expect(find.byTooltip('Start discharge plan'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module panels absent without pharmacy/billing rights',
    (WidgetTester tester) async {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: clinicalOnly,
      );

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Discharge medicines'), findsNothing);
      expect(find.text('Billing clearance'), findsNothing);
      expect(find.text('Amoxicillin'), findsNothing);
      expect(find.text('Final bill'), findsNothing);
      expect(find.text('Open pharmacy'), findsNothing);
      expect(find.text('Open billing'), findsNothing);
      expect(find.text('Open housekeeping'), findsNothing);
      expect(find.text('Pharmacy medicines'), findsNothing);
      expect(find.text('Final billing'), findsNothing);
      expect(find.text('Bed release'), findsNothing);
    },
  );

  testWidgets(
    '∪ pharmacy-only: meds panel present; billing/ops nested UI absent',
    (WidgetTester tester) async {
      final AppAccessPolicy pharmacy = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        roles: const <String>['PHARMACIST'],
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: pharmacy,
      );

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Discharge medicines'), findsOneWidget);
      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(find.text('Open pharmacy'), findsOneWidget);
      expect(find.text('Billing clearance'), findsNothing);
      expect(find.text('Final bill'), findsNothing);
      expect(find.text('Open billing'), findsNothing);
      expect(find.text('Open housekeeping'), findsNothing);
      expect(find.text('Doctor summary'), findsNothing);
      expect(find.text('Bed release'), findsNothing);
      expect(find.text('Start discharge plan'), findsNothing);
      expect(find.text('Request final billing'), findsNothing);
    },
  );

  testWidgets(
    '∪ pharmacy-only: detail print mounts via pending read ∪ when summary exists',
    (WidgetTester tester) async {
      final AppAccessPolicy pharmacy = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        roles: const <String>['PHARMACIST'],
      );
      final DischargeAdmissionDetail detailWithSummary = DischargeAdmissionDetail(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        encounterId: 'encounter-1',
        ipd: const IpdAdmissionDetail(
          summary: _pending,
          latestDischargeSummary: IpdDischargeSummary(
            id: 'ds-pending',
            status: 'SUMMARY_PENDING',
            summary: 'Draft clearance notes for pharmacy review.',
          ),
        ),
        pharmacyOrders: const <DischargeRelatedRecord>[
          DischargeRelatedRecord(
            id: 'rx-1',
            kind: 'pharmacy_order',
            title: 'Amoxicillin',
            status: 'ORDERED',
          ),
        ],
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: pharmacy,
        detailOverride: detailWithSummary,
      );

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Print discharge summary'), findsOneWidget);
      expect(find.text('Start discharge plan'), findsNothing);
      expect(find.text('Request final billing'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module panels mount when domain reads entitled',
    (WidgetTester tester) async {
      final AppAccessPolicy withNested = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
          AppPermissions.operationsRead,
          AppPermissions.lastOfficeRead,
        },
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: withNested,
      );

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(find.text('Final bill'), findsOneWidget);
      expect(find.text('Open pharmacy'), findsOneWidget);
      expect(find.text('Open billing'), findsOneWidget);
      expect(find.text('Open housekeeping'), findsOneWidget);
      expect(find.text('Open nursing'), findsOneWidget);
      expect(find.text('Pharmacy medicines'), findsOneWidget);
      expect(find.text('Final billing'), findsOneWidget);
      expect(find.text('Bed release'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized next-action opens planning; queue stays synchronized',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.byTooltip('Start discharge plan').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      verify(() => repository.getAdmissionDetail('adm-pending')).called(1);
    },
  );

  testWidgets(
    'post-mutation sync: request billing shows success snackbar on Pending',
    (WidgetTester tester) async {
      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request final billing'));
      await tester.pumpAndSettle();

      expect(find.text('Create invoice request'), findsOneWidget);
      final Finder amountField = find.descendant(
        of: find.byType(AppFormShell),
        matching: find.byType(TextField),
      );
      await tester.enterText(amountField.first, '1000');
      await tester.tap(find.text('Create invoice request'));
      await tester.pumpAndSettle();

      expect(find.text('Discharge workflow updated.'), findsOneWidget);
      verify(() => repository.createFinalInvoice(any())).called(1);
    },
  );

  testWidgets('authorized empty Pending queue state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpPendingClearanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
      items: const <IpdAdmissionSummary>[],
    );

    expect(find.text('No discharges in this view'), findsOneWidget);
    expect(find.text('Adjust filters to find discharge work.'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('authorized load error + Try again remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpPendingClearanceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
      listOverride: const Result<AppPage<IpdAdmissionSummary>>.failure(
        NetworkFailure(),
      ),
    );

    expect(find.text('Try again'), findsOneWidget);

    when(() => repository.listQueue(any())).thenAnswer(
      (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: const <IpdAdmissionSummary>[_pending],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Bob Pending'), findsOneWidget);
  });

  testWidgets('Pending desktop + mobile viewports keep list reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpPendingClearanceTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
    );
    expect(find.byTooltip('Start discharge plan'), findsOneWidget);
    expect(find.text('Bob Pending'), findsOneWidget);

    await _pumpPendingClearanceTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );
    expect(find.textContaining('Bob'), findsWidgets);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
  });

  testWidgets('Pending light + dark themes keep authorized chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpPendingClearanceTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.light,
    );
    expect(find.text('Bob Pending'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);

    await _pumpPendingClearanceTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Bob Pending'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'subscription strip: inpatient-bed-management missing omits Pending',
    (WidgetTester tester) async {
      await _pumpPendingClearanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.pharmacyRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Bob Pending'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
