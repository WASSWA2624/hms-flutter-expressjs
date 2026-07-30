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
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_work_orders_billing_inventory.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _openWorkOrder = BiomedicalAsset(
  id: 'WO-100',
  humanFriendlyId: 'WO-100',
  resource: BiomedicalResources.workOrders,
  title: 'Pump repair',
  status: 'OPEN',
  priority: 'HIGH',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Infusion Pump A',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Infusion Pump A'),
  ],
);

const AppModuleEntitlement _biomedModule = AppModuleEntitlement(
  code: biomedicalEngineeringSuiteModule,
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_openWorkOrder],
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
          openWorkOrders: 1,
        ),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: _lookups,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpWorkOrders(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_openWorkOrder],
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
    initialLocation: '/biomedical?panel=work-orders',
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

  group('Biomedical Work orders financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        BiomedicalWorkOrdersBillingInventory.workOrdersTabHasNoBillableActions,
        isTrue,
      );
      expect(
        BiomedicalWorkOrdersBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(BiomedicalWorkOrdersBillingInventory.atoms, isNotEmpty);
      expect(
        BiomedicalWorkOrdersBillingInventory.billableClasses.every(
          (BiomedicalWorkOrdersFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(biomedicalWorkOrdersBillingScopeNote, contains('NOT_BILLED'));

      for (final BiomedicalWorkOrdersFinancialAtom atom
          in BiomedicalWorkOrdersBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<BiomedicalWorkOrdersFinancialClass>[
            BiomedicalWorkOrdersFinancialClass.notRequired,
            BiomedicalWorkOrdersFinancialClass.notBilled,
            BiomedicalWorkOrdersFinancialClass.noCharge,
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

    test('Create work order primary stays NOT_BILLED', () {
      final BiomedicalWorkOrdersFinancialAtom primary =
          BiomedicalWorkOrdersBillingInventory.atoms.singleWhere(
            (BiomedicalWorkOrdersFinancialAtom atom) =>
                atom.id == 'create_work_order_primary',
          );
      expect(
        primary.financialClass,
        BiomedicalWorkOrdersFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('Start and Return next-actions stay NOT_BILLED', () {
      final BiomedicalWorkOrdersFinancialAtom start =
          BiomedicalWorkOrdersBillingInventory.atoms.singleWhere(
            (BiomedicalWorkOrdersFinancialAtom atom) =>
                atom.id == 'next_action_start_work_order',
          );
      expect(
        start.financialClass,
        BiomedicalWorkOrdersFinancialClass.notBilled,
      );
      expect(start.auditCode, 'NOT_BILLED');

      final BiomedicalWorkOrdersFinancialAtom returnAction =
          BiomedicalWorkOrdersBillingInventory.atoms.singleWhere(
            (BiomedicalWorkOrdersFinancialAtom atom) =>
                atom.id == 'next_action_return_to_service',
          );
      expect(
        returnAction.financialClass,
        BiomedicalWorkOrdersFinancialClass.notBilled,
      );
      expect(returnAction.auditCode, 'NOT_BILLED');
    });

    test('detail Update WO and complementary writes stay NOT_BILLED', () {
      final BiomedicalWorkOrdersFinancialAtom update =
          BiomedicalWorkOrdersBillingInventory.atoms.singleWhere(
            (BiomedicalWorkOrdersFinancialAtom atom) =>
                atom.id == 'detail_update_work_order',
          );
      expect(
        update.financialClass,
        BiomedicalWorkOrdersFinancialClass.notBilled,
      );
      expect(update.auditCode, 'NOT_BILLED');

      final BiomedicalWorkOrdersFinancialAtom writes =
          BiomedicalWorkOrdersBillingInventory.atoms.singleWhere(
            (BiomedicalWorkOrdersFinancialAtom atom) =>
                atom.id == 'detail_internal_maintenance_writes',
          );
      expect(
        writes.financialClass,
        BiomedicalWorkOrdersFinancialClass.notBilled,
      );
      expect(writes.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        BiomedicalWorkOrdersBillingInventory.atoms
            .singleWhere(
              (BiomedicalWorkOrdersFinancialAtom atom) =>
                  atom.id == 'patient_billable_device_usage',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalWorkOrdersBillingInventory.atoms
            .singleWhere(
              (BiomedicalWorkOrdersFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalWorkOrdersBillingInventory.atoms
            .singleWhere(
              (BiomedicalWorkOrdersFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(biomedicalWorkOrdersBillingScopeNote, contains('Billing'));
    });
  });

  group('Biomedical Work orders billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
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
      expect(find.text('Pump repair'), findsOneWidget);
      expect(find.byTooltip('Create work order'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
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

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Update work order'), findsOneWidget);
      expect(find.text('Transfer location'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      expect(find.text('Registry'), findsWidgets);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
      );

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Update work order'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'Start work order mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(() => repository.startWorkOrder(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _openWorkOrder),
          ),
        );

        await _pumpWorkOrders(
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

    testWidgets(
      'Create work order primary mutation stays NOT_BILLED',
      (WidgetTester tester) async {
        when(() => repository.createResource(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _openWorkOrder),
          ),
        );

        await _pumpWorkOrders(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
        );

        await tester.tap(find.byTooltip('Create work order'));
        await tester.pumpAndSettle();

        final Finder formFields = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.byType(TextFormField),
        );
        for (int i = 0; i < formFields.evaluate().length; i++) {
          await tester.enterText(formFields.at(i), 'New WO title');
        }
        await tester.pump();
        await tester.tap(find.text('Submit').last);
        await tester.pumpAndSettle();

        verify(
          () => repository.createResource(
            BiomedicalResources.workOrders,
            any(),
          ),
        ).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('Biomedical Work orders section layout (AC5)', () {
    testWidgets('desktop Work orders: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
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

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Work orders: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
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
      await _pumpWorkOrders(
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
      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
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
      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('Create work order dialog: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create work order'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Biomedical Work orders sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.text('Work orders'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpWorkOrders(
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
        BiomedicalWorkOrdersBillingInventory.atoms.any(
          (BiomedicalWorkOrdersFinancialAtom atom) =>
              atom.financialClass ==
              BiomedicalWorkOrdersFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.tab,
        biomedicalWorkspaceReadRequirement,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.createWorkOrder,
        biomedicalWorkspaceWriteRequirement,
      );
    });
  });
}
