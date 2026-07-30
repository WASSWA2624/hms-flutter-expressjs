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
import 'package:hosspi_hms/features/biomedical/data/repositories/biomedical_repository_impl.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_access.dart';
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_overview_billing_inventory.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _overviewAsset = BiomedicalAsset(
  id: 'WO-100',
  humanFriendlyId: 'WO-100',
  resource: BiomedicalResources.workOrders,
  title: 'Infusion pump repair',
  status: 'OPEN',
  priority: 'HIGH',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Infusion Pump A',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
);

const BiomedicalLookupData _overviewLookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Infusion Pump A'),
  ],
);

const AppModuleEntitlement _biomedModule = AppModuleEntitlement(
  code: biomedicalActiveModule,
  licenseStatus: 'ACTIVE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    _biomedModule,
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BIOMED_ENGINEER'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockBiomedicalRepository repository, {
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_overviewAsset],
  Result<BiomedicalWorkbench>? failure,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failure != null) {
      return failure;
    }
    final BiomedicalWorkspaceQuery query =
        invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
    return Result<BiomedicalWorkbench>.success(
      BiomedicalWorkbench(
        summary: const BiomedicalSummary(
          totalEquipment: 1,
          overduePm: 1,
          openWorkOrders: 1,
        ),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: _overviewLookups,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_overviewAsset],
  Result<BiomedicalWorkbench>? failure,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, assets: assets, failure: failure);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/biomedical?panel=overview',
    routes: <RouteBase>[
      GoRoute(
        path: '/biomedical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: BiomedicalWorkspacePage(
              initialQuery: BiomedicalRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biomedicalRepositoryProvider.overrideWithValue(repository),
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
  late _MockBiomedicalRepository repository;

  setUpAll(() {
    registerFallbackValue(const BiomedicalWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockBiomedicalRepository();
  });

  group('Biomedical Overview financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        BiomedicalOverviewBillingInventory.overviewTabHasNoBillableActions,
        isTrue,
      );
      expect(
        BiomedicalOverviewBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(BiomedicalOverviewBillingInventory.atoms, isNotEmpty);
      expect(
        BiomedicalOverviewBillingInventory.billableClasses.every(
          (BiomedicalOverviewFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(biomedicalOverviewBillingScopeNote, contains('NOT_BILLED'));

      for (final BiomedicalOverviewFinancialAtom atom
          in BiomedicalOverviewBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<BiomedicalOverviewFinancialClass>[
            BiomedicalOverviewFinancialClass.notRequired,
            BiomedicalOverviewFinancialClass.notBilled,
            BiomedicalOverviewFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('KPI risk/status columns are NOT_BILLED, not ledger balances', () {
      final BiomedicalOverviewFinancialAtom kpi =
          BiomedicalOverviewBillingInventory.atoms.singleWhere(
            (BiomedicalOverviewFinancialAtom atom) =>
                atom.id == 'kpi_risk_status_columns',
          );
      expect(
        kpi.financialClass,
        BiomedicalOverviewFinancialClass.notBilled,
      );
      expect(kpi.auditCode, 'NOT_BILLED');
    });

    test('work-order follow-up and internal maintenance stay NOT_BILLED', () {
      final BiomedicalOverviewFinancialAtom followUp =
          BiomedicalOverviewBillingInventory.atoms.singleWhere(
            (BiomedicalOverviewFinancialAtom atom) =>
                atom.id == 'next_action_work_order_follow_up',
          );
      expect(
        followUp.financialClass,
        BiomedicalOverviewFinancialClass.notBilled,
      );
      expect(followUp.auditCode, 'NOT_BILLED');

      final BiomedicalOverviewFinancialAtom writes =
          BiomedicalOverviewBillingInventory.atoms.singleWhere(
            (BiomedicalOverviewFinancialAtom atom) =>
                atom.id == 'detail_internal_maintenance_writes',
          );
      expect(
        writes.financialClass,
        BiomedicalOverviewFinancialClass.notBilled,
      );
      expect(writes.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        BiomedicalOverviewBillingInventory.atoms
            .singleWhere(
              (BiomedicalOverviewFinancialAtom atom) =>
                  atom.id == 'patient_billable_device_usage',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalOverviewBillingInventory.atoms
            .singleWhere(
              (BiomedicalOverviewFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalOverviewBillingInventory.atoms
            .singleWhere(
              (BiomedicalOverviewFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(biomedicalOverviewBillingScopeNote, contains('Billing'));
    });
  });

  group('Biomedical Overview billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.text('Infusion pump repair'), findsOneWidget);
      expect(find.text('Risk'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Update work order'), findsOneWidget);
      expect(find.text('Registry'), findsWidgets);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
      );

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'nested start-work-order mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(() => repository.startWorkOrder(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _overviewAsset),
          ),
        );

        await _pumpOverview(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
        );

        expect(find.text('Work order follow-up'), findsWidgets);
        await tester.tap(find.text('Work order follow-up').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Submit').last);
        await tester.pumpAndSettle();

        verify(() => repository.startWorkOrder(any(), any())).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('Biomedical Overview section layout (AC5)', () {
    testWidgets('desktop Overview: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Overview: flat sections', (WidgetTester tester) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mutation dialog: flat sections', (WidgetTester tester) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule maintenance'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Biomedical Overview sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.text('Overview'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpOverview(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        failure: const Result<BiomedicalWorkbench>.failure(AppFailure.network()),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary', () {
      expect(
        BiomedicalOverviewBillingInventory.atoms.any(
          (BiomedicalOverviewFinancialAtom atom) =>
              atom.financialClass ==
              BiomedicalOverviewFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        BiomedicalOverviewAtomPermissions.tab,
        biomedicalWorkspaceReadRequirement,
      );
    });
  });
}
