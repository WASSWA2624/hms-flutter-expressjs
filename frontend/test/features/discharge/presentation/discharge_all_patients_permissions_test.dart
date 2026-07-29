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
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[
    _planned,
    _pending,
    _completed,
  ],
  DischargeAdmissionDetail? detailOverride,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
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
        ipd: IpdAdmissionDetail(summary: summary),
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

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/discharge?section=all',
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
}) async {
  if (items != null || listOverride != null) {
    _stubQueue(
      repository,
      items: items ?? const <IpdAdmissionSummary>[_planned, _pending, _completed],
      listOverride: listOverride,
    );
  }
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
  });

  setUp(() {
    repository = _MockDischargeRepository();
    _stubQueue(repository);
  });

  group('DischargeAllPatientsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        DischargeAllPatientsAtomPermissions.tab,
        same(dischargeWorkspaceReadRequirement),
      );
      expect(
        DischargeAllPatientsAtomPermissions.write,
        same(dischargeClinicalWriteRequirement),
      );
      expect(
        DischargeAllPatientsAtomPermissions.billingPanel,
        same(billingReadRequirement),
      );
      expect(
        DischargeAllPatientsAtomPermissions.medicinesPanel,
        same(dischargePharmacyClearanceReadRequirement),
      );
      expect(
        DischargeAllPatientsAtomPermissions.roomTurnover,
        same(dischargeOperationsClearanceReadRequirement),
      );
      expect(
        dischargeSectionTabRequirement(DischargeDeskSection.all),
        same(dischargeWorkspaceReadRequirement),
      );
      expect(
        DischargeAllPatientsAtomPermissions.routeEntry,
        same(dischargeWorkspaceEntryRequirement),
      );
    });

    test('∩ denial: clinical:write missing hides write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(DischargeAllPatientsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        DischargeAllPatientsAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargeAllPatientsAtomPermissions.nextActionPlan.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargeAllPatientsAtomPermissions.requestBilling.isAllowed(reader),
        isFalse,
      );
    });

    test('∪ allowance: last_office:read alone satisfies All tab read', () {
      final AppAccessPolicy nursing = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['NURSE'],
      );
      expect(DischargeAllPatientsAtomPermissions.tab.isAllowed(nursing), isTrue);
      expect(
        DischargeAllPatientsAtomPermissions.listChrome.isAllowed(nursing),
        isTrue,
      );
      expect(
        DischargeAllPatientsAtomPermissions.write.isAllowed(nursing),
        isFalse,
      );
    });

    test('∪ allowance: clinical:read alone satisfies All tab read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargeAllPatientsAtomPermissions.tab.isAllowed(clinical),
        isTrue,
      );
    });

    test(
      'route entry keeps catalog discharge:read (prompt ∪ maps to unique key)',
      () {
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
        // Prompt lists clinical|pharmacy|billing|operations any-of; source
        // RouteAccessCatalog uses unique discharge:read — keep source.
        expect(
          DischargeAllPatientsAtomPermissions.routeEntry.isAllowed(
            pharmacyOnly,
          ),
          isFalse,
        );
        expect(
          DischargeAllPatientsAtomPermissions.tab.isAllowed(pharmacyOnly),
          isFalse,
        );
        expect(
          DischargeAllPatientsAtomPermissions.medicinesPanel.isAllowed(
            pharmacyOnly,
          ),
          isTrue,
        );

        final AppAccessPolicy withDischargeRead = _policy(
          permissions: <AppPermission>{
            AppPermissions.dischargeRead,
            AppPermissions.pharmacyRead,
          },
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
          DischargeAllPatientsAtomPermissions.routeEntry.isAllowed(
            withDischargeRead,
          ),
          isTrue,
        );
        expect(
          DischargeAllPatientsAtomPermissions.tab.isAllowed(withDischargeRead),
          isFalse,
        );
      },
    );

    test('subscription strip: missing inpatient module denies All', () {
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
        DischargeAllPatientsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        DischargeAllPatientsAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested clearance reads ∩ per domain', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        DischargeAllPatientsAtomPermissions.medicinesPanel.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
      expect(
        DischargeAllPatientsAtomPermissions.billingPanel.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(
        DischargeAllPatientsAtomPermissions.roomTurnover.isAllowed(clinicalOnly),
        isFalse,
      );

      final AppAccessPolicy withNested = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
          AppPermissions.operationsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        DischargeAllPatientsAtomPermissions.medicinesPanel.isAllowed(
          withNested,
        ),
        isTrue,
      );
      expect(
        DischargeAllPatientsAtomPermissions.billingPanel.isAllowed(withNested),
        isTrue,
      );
      expect(
        DischargeAllPatientsAtomPermissions.roomTurnover.isAllowed(withNested),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only: All list + print visible; mutation atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Alice Planned'), findsOneWidget);
      expect(find.byTooltip('Start discharge plan'), findsNothing);
      expect(find.byTooltip('Manage clearance'), findsNothing);
      expect(find.byTooltip('Print discharge summary'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Bob Pending'));
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
    'full write ∩: plan next-action and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byTooltip('Start discharge plan'), findsOneWidget);
      expect(find.byTooltip('Manage clearance'), findsOneWidget);

      await tester.tap(find.text('Bob Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Start discharge plan'), findsWidgets);
      expect(find.text('Request final billing'), findsOneWidget);
      expect(find.text('Request medicines'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ last_office:read shows All chrome without write controls',
    (WidgetTester tester) async {
      final AppAccessPolicy nursing = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        roles: const <String>['NURSE'],
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: nursing,
      );

      expect(find.textContaining('All patients'), findsWidgets);
      expect(find.text('Alice Planned'), findsOneWidget);
      expect(find.byTooltip('Start discharge plan'), findsNothing);
      expect(find.byTooltip('Print discharge summary'), findsOneWidget);
    },
  );

  testWidgets(
    'pharmacy-only entry ∪ omits All tab (no clinical/last_office read)',
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

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: pharmacyOnly,
      );

      expect(find.textContaining('All patients'), findsNothing);
      expect(
        DischargeAllPatientsAtomPermissions.tab.isAllowed(pharmacyOnly),
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

      await _pumpAllTab(
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
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      await _pumpAllTab(
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

      await _pumpAllTab(
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

  testWidgets('mobile viewport keeps All list and next-action reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Alice'), findsWidgets);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
    expect(find.byTooltip('Start discharge plan'), findsOneWidget);
    expect(find.byTooltip('Manage clearance'), findsOneWidget);
    expect(find.byTooltip('Print discharge summary'), findsOneWidget);
  });

  testWidgets('light theme keeps authorized All chrome without no-access banners', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.light,
    );

    expect(find.text('Alice Planned'), findsOneWidget);
    expect(find.byTooltip('Start discharge plan'), findsNothing);
    expect(find.byTooltip('Print discharge summary'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('dark theme keeps authorized All chrome without no-access banners', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Alice Planned'), findsOneWidget);
    expect(find.byTooltip('Start discharge plan'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'subscription strip: missing inpatient module empties All chrome',
    (WidgetTester tester) async {
      await _pumpAllTab(
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

  testWidgets('authorized empty All queue state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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
    await _pumpAllTab(
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
}
