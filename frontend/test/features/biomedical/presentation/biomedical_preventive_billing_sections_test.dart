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
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_preventive_billing_inventory.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _maintenanceAsset = BiomedicalAsset(
  id: 'PM-100',
  humanFriendlyId: 'PM-100',
  resource: BiomedicalResources.maintenancePlans,
  title: 'Ventilator PM plan',
  status: 'DUE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
  nextDueAt: null,
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_maintenanceAsset],
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
          openWorkOrders: 0,
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

Future<void> _pumpPreventive(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_maintenanceAsset],
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
    initialLocation: '/biomedical?panel=preventive',
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

  group('Biomedical Preventive financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        BiomedicalPreventiveBillingInventory.preventiveTabHasNoBillableActions,
        isTrue,
      );
      expect(
        BiomedicalPreventiveBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(BiomedicalPreventiveBillingInventory.atoms, isNotEmpty);
      expect(
        BiomedicalPreventiveBillingInventory.billableClasses.every(
          (BiomedicalPreventiveFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(biomedicalPreventiveBillingScopeNote, contains('NOT_BILLED'));

      for (final BiomedicalPreventiveFinancialAtom atom
          in BiomedicalPreventiveBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<BiomedicalPreventiveFinancialClass>[
            BiomedicalPreventiveFinancialClass.notRequired,
            BiomedicalPreventiveFinancialClass.notBilled,
            BiomedicalPreventiveFinancialClass.noCharge,
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

    test('Schedule maintenance primary stays NOT_BILLED', () {
      final BiomedicalPreventiveFinancialAtom primary =
          BiomedicalPreventiveBillingInventory.atoms.singleWhere(
            (BiomedicalPreventiveFinancialAtom atom) =>
                atom.id == 'schedule_maintenance_primary',
          );
      expect(
        primary.financialClass,
        BiomedicalPreventiveFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('Perform maintenance next-action stays NOT_BILLED', () {
      final BiomedicalPreventiveFinancialAtom perform =
          BiomedicalPreventiveBillingInventory.atoms.singleWhere(
            (BiomedicalPreventiveFinancialAtom atom) =>
                atom.id == 'next_action_perform_maintenance',
          );
      expect(
        perform.financialClass,
        BiomedicalPreventiveFinancialClass.notBilled,
      );
      expect(perform.auditCode, 'NOT_BILLED');
    });

    test('internal complementary writes stay NOT_BILLED', () {
      final BiomedicalPreventiveFinancialAtom writes =
          BiomedicalPreventiveBillingInventory.atoms.singleWhere(
            (BiomedicalPreventiveFinancialAtom atom) =>
                atom.id == 'detail_internal_maintenance_writes',
          );
      expect(
        writes.financialClass,
        BiomedicalPreventiveFinancialClass.notBilled,
      );
      expect(writes.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        BiomedicalPreventiveBillingInventory.atoms
            .singleWhere(
              (BiomedicalPreventiveFinancialAtom atom) =>
                  atom.id == 'patient_billable_device_usage',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalPreventiveBillingInventory.atoms
            .singleWhere(
              (BiomedicalPreventiveFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalPreventiveBillingInventory.atoms
            .singleWhere(
              (BiomedicalPreventiveFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(biomedicalPreventiveBillingScopeNote, contains('Billing'));
    });
  });

  group('Biomedical Preventive billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpPreventive(
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
      expect(find.text('Ventilator PM plan'), findsOneWidget);
      expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpPreventive(
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

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Create work order'), findsOneWidget);
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
      await _pumpPreventive(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
      );

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();

      expect(find.text('Create work order'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'Schedule maintenance mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(() => repository.createResource(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _maintenanceAsset),
          ),
        );

        await _pumpPreventive(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
        );

        await tester.tap(find.text('Perform maintenance').first);
        await tester.pumpAndSettle();

        final Finder formFields = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.byType(TextFormField),
        );
        for (int i = 0; i < formFields.evaluate().length; i++) {
          await tester.enterText(formFields.at(i), 'Quarterly PM');
        }
        await tester.pump();
        await tester.tap(find.text('Submit').last);
        await tester.pumpAndSettle();

        verify(
          () => repository.createResource(
            BiomedicalResources.maintenancePlans,
            any(),
          ),
        ).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('Biomedical Preventive section layout (AC5)', () {
    testWidgets('desktop Preventive: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpPreventive(
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

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Preventive: flat sections', (WidgetTester tester) async {
      await _pumpPreventive(
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
      await _pumpPreventive(
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
      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpPreventive(
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
      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mutation dialog: flat sections', (WidgetTester tester) async {
      await _pumpPreventive(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Schedule maintenance'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Biomedical Preventive sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpPreventive(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.text('Preventive'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpPreventive(
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
        BiomedicalPreventiveBillingInventory.atoms.any(
          (BiomedicalPreventiveFinancialAtom atom) =>
              atom.financialClass ==
              BiomedicalPreventiveFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.tab,
        biomedicalWorkspaceReadRequirement,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.scheduleMaintenance,
        biomedicalWorkspaceWriteRequirement,
      );
    });
  });
}
