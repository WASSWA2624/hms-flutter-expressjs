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
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[_planned],
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
          latestDischargeSummary: IpdDischargeSummary(
            id: 'ds-1',
            status: 'PLANNED',
            summary: 'Plan ready; clearances pending.',
          ),
          dischargeSummaries: <IpdDischargeSummary>[
            IpdDischargeSummary(
              id: 'ds-1',
              status: 'PLANNED',
              summary: 'Plan ready; clearances pending.',
            ),
          ],
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
}

Future<void> _pumpPlannedTab(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  DischargeAdmissionDetail? detailOverride,
  String initialLocation = '/discharge?section=planned',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubQueue(
    repository,
    items: items ?? <IpdAdmissionSummary>[_planned],
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

  group('DischargePlannedAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        DischargePlannedAtomPermissions.tab,
        same(dischargeWorkspaceReadRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.write,
        same(dischargeClinicalWriteRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.nextActionClearance,
        same(dischargeClinicalWriteRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.billingPanel,
        same(billingReadRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.medicinesPanel,
        same(dischargePharmacyClearanceReadRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.roomTurnover,
        same(dischargeOperationsClearanceReadRequirement),
      );
      expect(
        dischargeSectionTabRequirement(DischargeDeskSection.planned),
        same(dischargeWorkspaceReadRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.routeEntry,
        same(dischargeWorkspaceEntryRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.medicinesPanel,
        same(DischargeAllPatientsAtomPermissions.medicinesPanel),
      );
      expect(
        DischargePlannedAtomPermissions.write,
        same(DischargeAllPatientsAtomPermissions.write),
      );
    });

    test('∩ denial: clinical:write missing hides write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(DischargePlannedAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        DischargePlannedAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargePlannedAtomPermissions.nextActionClearance.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargePlannedAtomPermissions.requestBilling.isAllowed(reader),
        isFalse,
      );
      expect(canWriteDischarge(reader), isFalse);
    });

    test('∪ allowance: last_office:read alone satisfies Planned tab read', () {
      final AppAccessPolicy nursing = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['NURSE'],
      );
      expect(DischargePlannedAtomPermissions.tab.isAllowed(nursing), isTrue);
      expect(
        DischargePlannedAtomPermissions.listChrome.isAllowed(nursing),
        isTrue,
      );
      expect(
        DischargePlannedAtomPermissions.write.isAllowed(nursing),
        isFalse,
      );
      expect(canViewDischargePlanned(nursing), isTrue);
    });

    test('∪ allowance: clinical:read alone satisfies Planned tab read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargePlannedAtomPermissions.tab.isAllowed(clinical),
        isTrue,
      );
      expect(
        canViewDischargeSection(clinical, DischargeDeskSection.planned),
        isTrue,
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
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          DischargePlannedAtomPermissions.routeEntry.isAllowed(pharmacyOnly),
          isFalse,
        );
        expect(
          DischargePlannedAtomPermissions.tab.isAllowed(pharmacyOnly),
          isFalse,
        );
        expect(
          DischargePlannedAtomPermissions.medicinesPanel.isAllowed(
            pharmacyOnly,
          ),
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
          DischargePlannedAtomPermissions.routeEntry.isAllowed(
            withDischargeRead,
          ),
          isTrue,
        );
        expect(
          DischargePlannedAtomPermissions.tab.isAllowed(withDischargeRead),
          isFalse,
        );
      },
    );

    test('subscription strip: missing inpatient module denies Planned', () {
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
        DischargePlannedAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        DischargePlannedAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(canViewDischargePlanned(noModule), isFalse);
    });

    test('nested clearance reads ∩ per domain', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargePlannedAtomPermissions.medicinesPanel.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(
        DischargePlannedAtomPermissions.billingPanel.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(
        DischargePlannedAtomPermissions.roomTurnover.isAllowed(clinicalOnly),
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

      final AppAccessPolicy withNested = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
          AppPermissions.operationsRead,
        },
      );
      expect(
        DischargePlannedAtomPermissions.medicinesPanel.isAllowed(withNested),
        isTrue,
      );
      expect(
        DischargePlannedAtomPermissions.billingPanel.isAllowed(withNested),
        isTrue,
      );
      expect(
        DischargePlannedAtomPermissions.roomTurnover.isAllowed(withNested),
        isTrue,
      );
      expect(dischargeVisibleClearanceItems(withNested, all).length, all.length);
    });
  });

  testWidgets(
    'read-only: Planned list visible; Manage clearance absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Alice Planned'), findsOneWidget);
      expect(find.textContaining('Planned'), findsWidgets);
      expect(find.byTooltip('Manage clearance'), findsNothing);
      expect(find.byTooltip('Start discharge plan'), findsNothing);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Alice Planned'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Start discharge plan'), findsNothing);
      expect(find.text('Request final billing'), findsNothing);
      expect(find.text('Request medicines'), findsNothing);
      expect(find.text('Print discharge summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Manage clearance and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byTooltip('Manage clearance'), findsOneWidget);
      expect(find.byTooltip('Start discharge plan'), findsNothing);

      await tester.tap(find.text('Alice Planned'));
      await tester.pumpAndSettle();

      expect(find.text('Request final billing'), findsNothing);
      expect(find.text('Open billing'), findsNothing);
      expect(find.text('Request medicines'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ last_office:read shows Planned chrome without write controls',
    (WidgetTester tester) async {
      final AppAccessPolicy nursing = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['NURSE'],
      );

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: nursing,
      );

      expect(find.textContaining('Planned'), findsWidgets);
      expect(find.text('Alice Planned'), findsOneWidget);
      expect(find.byTooltip('Manage clearance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'pharmacy-only entry ∪ omits Planned tab (no clinical/last_office read)',
    (WidgetTester tester) async {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        roles: const <String>['PHARMACIST'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: pharmacyOnly,
        items: <IpdAdmissionSummary>[_planned, _pending],
      );

      expect(find.textContaining('Planned'), findsNothing);
      expect(find.text('Alice Planned'), findsNothing);
      expect(
        DischargePlannedAtomPermissions.tab.isAllowed(pharmacyOnly),
        isFalse,
      );
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

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: clinicalOnly,
      );

      await tester.tap(find.text('Alice Planned'));
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

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: withNested,
      );

      await tester.tap(find.text('Alice Planned'));
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

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.byTooltip('Manage clearance').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      verify(() => repository.getAdmissionDetail('adm-planned')).called(1);
    },
  );

  testWidgets(
    'no local invoice create: Open billing only with billing:read on Planned',
    (WidgetTester tester) async {
      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        ),
      );

      await tester.tap(find.text('Alice Planned'));
      await tester.pumpAndSettle();

      expect(find.text('Open billing'), findsWidgets);
      expect(find.text('Request final billing'), findsNothing);
      expect(find.text('Create invoice request'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    },
  );

  testWidgets('authorized empty Planned queue state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpPlannedTab(
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
    await _pumpPlannedTab(
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
          items: const <IpdAdmissionSummary>[_planned],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Planned'), findsOneWidget);
  });

  testWidgets('mobile + desktop viewports keep Planned list reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpPlannedTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
    );
    expect(find.byTooltip('Manage clearance'), findsOneWidget);
    expect(find.text('Alice Planned'), findsOneWidget);

    await _pumpPlannedTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Alice'), findsWidgets);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
  });

  testWidgets(
    'light + dark themes keep authorized Planned chrome without no-access',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        themeMode: ThemeMode.light,
      );
      expect(find.text('Alice Planned'), findsOneWidget);
      expect(find.byTooltip('Manage clearance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        themeMode: ThemeMode.dark,
      );
      expect(find.text('Alice Planned'), findsOneWidget);
      expect(find.byTooltip('Manage clearance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: missing inpatient module empties Planned chrome',
    (WidgetTester tester) async {
      await _pumpPlannedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
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
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Alice Planned'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
