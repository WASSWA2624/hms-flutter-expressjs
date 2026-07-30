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
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_support_billing_inventory.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _vendorAsset = BiomedicalAsset(
  id: 'SP-100',
  humanFriendlyId: 'SP-100',
  resource: BiomedicalResources.serviceProviders,
  title: 'Acme Biomedical Support',
  status: 'ACTIVE',
  priority: 'MEDIUM',
  categoryLabel: 'Vendor',
  facilityLabel: 'Main Campus',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
  ],
  facilities: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'FAC-1', label: 'Main Campus'),
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_vendorAsset],
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

Future<void> _pumpSupport(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_vendorAsset],
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
    initialLocation: '/biomedical?panel=support',
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

  group('Biomedical Support financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        BiomedicalSupportBillingInventory.supportTabHasNoBillableActions,
        isTrue,
      );
      expect(
        BiomedicalSupportBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(BiomedicalSupportBillingInventory.atoms, isNotEmpty);
      expect(
        BiomedicalSupportBillingInventory.billableClasses.every(
          (BiomedicalSupportFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(biomedicalSupportBillingScopeNote, contains('NOT_BILLED'));

      for (final BiomedicalSupportFinancialAtom atom
          in BiomedicalSupportBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<BiomedicalSupportFinancialClass>[
            BiomedicalSupportFinancialClass.notRequired,
            BiomedicalSupportFinancialClass.notBilled,
            BiomedicalSupportFinancialClass.noCharge,
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

    test('vendor ticket columns and report fault stay NOT_BILLED', () {
      final BiomedicalSupportFinancialAtom vendor =
          BiomedicalSupportBillingInventory.atoms.singleWhere(
            (BiomedicalSupportFinancialAtom atom) =>
                atom.id == 'vendor_ticket_list_columns',
          );
      expect(
        vendor.financialClass,
        BiomedicalSupportFinancialClass.notBilled,
      );
      expect(vendor.auditCode, 'NOT_BILLED');

      final BiomedicalSupportFinancialAtom fault =
          BiomedicalSupportBillingInventory.atoms.singleWhere(
            (BiomedicalSupportFinancialAtom atom) =>
                atom.id == 'report_fault_primary',
          );
      expect(
        fault.financialClass,
        BiomedicalSupportFinancialClass.notBilled,
      );
      expect(fault.auditCode, 'NOT_BILLED');
    });

    test('log incident and nested fault dialog stay NOT_BILLED', () {
      final BiomedicalSupportFinancialAtom incident =
          BiomedicalSupportBillingInventory.atoms.singleWhere(
            (BiomedicalSupportFinancialAtom atom) =>
                atom.id == 'detail_log_incident',
          );
      expect(
        incident.financialClass,
        BiomedicalSupportFinancialClass.notBilled,
      );
      expect(incident.auditCode, 'NOT_BILLED');

      final BiomedicalSupportFinancialAtom nestedFault =
          BiomedicalSupportBillingInventory.atoms.singleWhere(
            (BiomedicalSupportFinancialAtom atom) =>
                atom.id == 'nested_fault_report_dialog',
          );
      expect(
        nestedFault.financialClass,
        BiomedicalSupportFinancialClass.notBilled,
      );
      expect(nestedFault.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        BiomedicalSupportBillingInventory.atoms
            .singleWhere(
              (BiomedicalSupportFinancialAtom atom) =>
                  atom.id == 'patient_billable_device_usage',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalSupportBillingInventory.atoms
            .singleWhere(
              (BiomedicalSupportFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalSupportBillingInventory.atoms
            .singleWhere(
              (BiomedicalSupportFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(biomedicalSupportBillingScopeNote, contains('Billing'));
    });
  });

  group('Biomedical Support billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
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
      expect(find.text('Acme Biomedical Support'), findsOneWidget);
      expect(find.byTooltip('Report fault'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
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

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Log incident'), findsOneWidget);
      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Registry'), findsWidgets);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
      );

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();

      expect(find.text('Log incident'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.byTooltip('Report fault'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'nested log-incident mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(() => repository.createResource(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _vendorAsset),
          ),
        );

        await _pumpSupport(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
        );

        await tester.tap(find.text('Acme Biomedical Support'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log incident'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Submit').last);
        await tester.pumpAndSettle();

        verify(
          () => repository.createResource(
            BiomedicalResources.incidentReports,
            any(),
          ),
        ).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('Biomedical Support section layout (AC5)', () {
    testWidgets('desktop Support: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
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

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Support: flat sections', (WidgetTester tester) async {
      await _pumpSupport(
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
      await _pumpSupport(
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
      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
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
      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('fault-report dialog: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Report fault'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Biomedical Support sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.text('Support'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpSupport(
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
        BiomedicalSupportBillingInventory.atoms.any(
          (BiomedicalSupportFinancialAtom atom) =>
              atom.financialClass ==
              BiomedicalSupportFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        BiomedicalSupportAtomPermissions.tab,
        biomedicalWorkspaceReadRequirement,
      );
      expect(
        BiomedicalSupportAtomPermissions.reportFault,
        biomedicalWorkspaceWriteRequirement,
      );
    });
  });
}
