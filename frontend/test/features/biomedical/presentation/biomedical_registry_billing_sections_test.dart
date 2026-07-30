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
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_registry_billing_inventory.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _registryAsset = BiomedicalAsset(
  id: 'EQ-001',
  humanFriendlyId: 'EQ-001',
  resource: BiomedicalResources.registries,
  title: 'Defibrillator',
  status: 'ACTIVE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'Main Ward',
  engineerLabel: 'Alex Engineer',
);

const BiomedicalAsset _createdAsset = BiomedicalAsset(
  id: 'EQ-002',
  humanFriendlyId: 'EQ-002',
  resource: BiomedicalResources.registries,
  title: 'Infusion Pump',
  status: 'ACTIVE',
  priority: 'MEDIUM',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  facilities: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'FAC-001', label: 'Main Ward'),
  ],
  categories: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'CAT-001', label: 'Life Support'),
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_registryAsset],
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
        summary: const BiomedicalSummary(totalEquipment: 1),
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

Future<void> _pumpRegistry(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_registryAsset],
  Result<BiomedicalWorkbench>? failure,
  String initialLocation = '/biomedical',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, assets: assets, failure: failure);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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

  group('Biomedical Registry financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        BiomedicalRegistryBillingInventory.registryTabHasNoBillableActions,
        isTrue,
      );
      expect(
        BiomedicalRegistryBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(BiomedicalRegistryBillingInventory.atoms, isNotEmpty);
      expect(
        BiomedicalRegistryBillingInventory.billableClasses.every(
          (BiomedicalRegistryFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(biomedicalRegistryBillingScopeNote, contains('NOT_BILLED'));

      for (final BiomedicalRegistryFinancialAtom atom
          in BiomedicalRegistryBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<BiomedicalRegistryFinancialClass>[
            BiomedicalRegistryFinancialClass.notRequired,
            BiomedicalRegistryFinancialClass.notBilled,
            BiomedicalRegistryFinancialClass.noCharge,
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

    test('Register asset primary stays NOT_BILLED', () {
      final BiomedicalRegistryFinancialAtom primary =
          BiomedicalRegistryBillingInventory.atoms.singleWhere(
            (BiomedicalRegistryFinancialAtom atom) =>
                atom.id == 'register_asset_primary',
          );
      expect(
        primary.financialClass,
        BiomedicalRegistryFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('Edit asset and complementary writes stay NOT_BILLED', () {
      final BiomedicalRegistryFinancialAtom edit =
          BiomedicalRegistryBillingInventory.atoms.singleWhere(
            (BiomedicalRegistryFinancialAtom atom) =>
                atom.id == 'detail_edit_asset',
          );
      expect(edit.financialClass, BiomedicalRegistryFinancialClass.notBilled);
      expect(edit.auditCode, 'NOT_BILLED');

      final BiomedicalRegistryFinancialAtom writes =
          BiomedicalRegistryBillingInventory.atoms.singleWhere(
            (BiomedicalRegistryFinancialAtom atom) =>
                atom.id == 'detail_internal_maintenance_writes',
          );
      expect(
        writes.financialClass,
        BiomedicalRegistryFinancialClass.notBilled,
      );
      expect(writes.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        BiomedicalRegistryBillingInventory.atoms
            .singleWhere(
              (BiomedicalRegistryFinancialAtom atom) =>
                  atom.id == 'patient_billable_device_usage',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalRegistryBillingInventory.atoms
            .singleWhere(
              (BiomedicalRegistryFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalRegistryBillingInventory.atoms
            .singleWhere(
              (BiomedicalRegistryFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(biomedicalRegistryBillingScopeNote, contains('Billing'));
    });
  });

  group('Biomedical Registry billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
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
      expect(find.text('Defibrillator'), findsOneWidget);
      expect(find.byTooltip('Register asset'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
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

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Edit asset'), findsOneWidget);
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
      await _pumpRegistry(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
      );

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();

      expect(find.text('Edit asset'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'Register asset mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(() => repository.createResource(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _createdAsset),
          ),
        );

        await _pumpRegistry(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
        );

        await tester.tap(find.byTooltip('Register asset'));
        await tester.pumpAndSettle();

        final Finder formFields = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.byType(TextFormField),
        );
        expect(formFields, findsAtLeastNWidgets(1));
        await tester.enterText(formFields.first, 'Infusion Pump');
        await tester.pump();
        await tester.tap(find.text('Create').last);
        await tester.pumpAndSettle();

        verify(
          () => repository.createResource(
            BiomedicalResources.registries,
            any(),
          ),
        ).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('Biomedical Registry section layout (AC5)', () {
    testWidgets('desktop Registry: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
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

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Registry: flat sections', (WidgetTester tester) async {
      await _pumpRegistry(
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
      await _pumpRegistry(
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
      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
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
      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mutation dialog: flat sections', (WidgetTester tester) async {
      await _pumpRegistry(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Register asset'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Biomedical Registry sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.text('Registry'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
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

    testWidgets('panel=registry deep link keeps parity without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpRegistry(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        initialLocation: '/biomedical?panel=registry',
      );

      expect(find.text('Defibrillator'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    test('inventory reuses shared financial class vocabulary', () {
      expect(
        BiomedicalRegistryBillingInventory.atoms.any(
          (BiomedicalRegistryFinancialAtom atom) =>
              atom.financialClass ==
              BiomedicalRegistryFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        BiomedicalRegistryAtomPermissions.tab,
        biomedicalWorkspaceReadRequirement,
      );
      expect(
        BiomedicalRegistryAtomPermissions.registerAsset,
        biomedicalWorkspaceWriteRequirement,
      );
    });
  });
}
