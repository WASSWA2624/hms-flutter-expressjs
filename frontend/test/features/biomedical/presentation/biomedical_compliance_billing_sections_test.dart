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
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_compliance_billing_inventory.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _calibrationAsset = BiomedicalAsset(
  id: 'CAL-100',
  humanFriendlyId: 'CAL-100',
  resource: BiomedicalResources.calibrationLogs,
  title: 'Ventilator calibration',
  status: 'DUE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
);

const BiomedicalAsset _downtimeAsset = BiomedicalAsset(
  id: 'DT-100',
  humanFriendlyId: 'DT-100',
  resource: BiomedicalResources.downtimeLogs,
  title: 'MRI downtime',
  status: 'OPEN',
  priority: 'CRITICAL',
  facilityLabel: 'Imaging',
  equipmentId: 'EQ-200',
  equipmentLabel: 'MRI Suite',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
    BiomedicalLookupOption(id: 'EQ-200', label: 'MRI Suite'),
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_calibrationAsset],
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
          criticalDowntime: 1,
          activeRecalls: 1,
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

Future<void> _pumpCompliance(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_calibrationAsset],
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
    initialLocation: '/biomedical?panel=compliance',
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

  group('Biomedical Compliance financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        BiomedicalComplianceBillingInventory.complianceTabHasNoBillableActions,
        isTrue,
      );
      expect(
        BiomedicalComplianceBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(BiomedicalComplianceBillingInventory.atoms, isNotEmpty);
      expect(
        BiomedicalComplianceBillingInventory.billableClasses.every(
          (BiomedicalComplianceFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(biomedicalComplianceBillingScopeNote, contains('NOT_BILLED'));

      for (final BiomedicalComplianceFinancialAtom atom
          in BiomedicalComplianceBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<BiomedicalComplianceFinancialClass>[
            BiomedicalComplianceFinancialClass.notRequired,
            BiomedicalComplianceFinancialClass.notBilled,
            BiomedicalComplianceFinancialClass.noCharge,
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

    test('calibration / downtime / recall writes stay NOT_BILLED', () {
      for (final String id in <String>[
        'record_calibration_primary',
        'next_action_review_compliance',
        'next_action_close_downtime',
        'next_action_acknowledge_recall',
        'detail_calibration_safety_downtime',
        'detail_close_downtime_acknowledge_recall',
        'detail_internal_maintenance_writes',
        'nested_mutation_dialogs',
      ]) {
        final BiomedicalComplianceFinancialAtom atom =
            BiomedicalComplianceBillingInventory.atoms.singleWhere(
              (BiomedicalComplianceFinancialAtom entry) => entry.id == id,
            );
        expect(
          atom.financialClass,
          BiomedicalComplianceFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
      }
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        BiomedicalComplianceBillingInventory.atoms
            .singleWhere(
              (BiomedicalComplianceFinancialAtom atom) =>
                  atom.id == 'patient_billable_device_usage',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalComplianceBillingInventory.atoms
            .singleWhere(
              (BiomedicalComplianceFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        BiomedicalComplianceBillingInventory.atoms
            .singleWhere(
              (BiomedicalComplianceFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(biomedicalComplianceBillingScopeNote, contains('Billing'));
    });
  });

  group('Biomedical Compliance billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
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
      expect(find.text('Ventilator calibration'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
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

      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Record safety test'), findsOneWidget);
      expect(find.text('Report downtime'), findsOneWidget);
      expect(find.text('Registry'), findsWidgets);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
      );

      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();

      expect(find.text('Record calibration'), findsNothing);
      expect(find.text('Report downtime'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'calibration mutation syncs without billing gate (idempotent path)',
      (WidgetTester tester) async {
        when(() => repository.createResource(any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _calibrationAsset),
          ),
        );

        await _pumpCompliance(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
        );

        await tester.tap(find.text('Review compliance').first);
        await tester.pumpAndSettle();

        expect(find.text('RECORD CALIBRATION'), findsOneWidget);

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        verify(
          () => repository.createResource(
            BiomedicalResources.calibrationLogs,
            any(),
          ),
        ).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );

    testWidgets(
      'downtime close mutation stays NOT_BILLED with no payment UX',
      (WidgetTester tester) async {
        when(() => repository.updateResource(any(), any(), any())).thenAnswer(
          (_) async => const Result<BiomedicalMutationResult>.success(
            BiomedicalMutationResult(asset: _downtimeAsset),
          ),
        );

        await _pumpCompliance(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.biomedRead,
              AppPermissions.biomedWrite,
            },
          ),
          assets: const <BiomedicalAsset>[_downtimeAsset],
        );

        await tester.tap(find.text('Return to service').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('CLOSE DOWNTIME'), findsOneWidget);
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        verify(
          () => repository.updateResource(
            BiomedicalResources.downtimeLogs,
            any(),
            any(),
          ),
        ).called(1);
        expect(find.text('Biomedical changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Balance'), findsNothing);
      },
    );
  });

  group('Biomedical Compliance section layout (AC5)', () {
    testWidgets('desktop Compliance: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
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

      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Compliance: flat sections', (WidgetTester tester) async {
      await _pumpCompliance(
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
      await _pumpCompliance(
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
      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
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
      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mutation dialog: flat sections', (WidgetTester tester) async {
      await _pumpCompliance(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Record calibration'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Biomedical Compliance sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.text('Compliance'), findsWidgets);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpCompliance(
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
        BiomedicalComplianceBillingInventory.atoms.any(
          (BiomedicalComplianceFinancialAtom atom) =>
              atom.financialClass ==
              BiomedicalComplianceFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        BiomedicalComplianceAtomPermissions.tab,
        biomedicalWorkspaceReadRequirement,
      );
      expect(
        BiomedicalComplianceAtomPermissions.recordCalibration,
        biomedicalWorkspaceWriteRequirement,
      );
    });
  });
}
