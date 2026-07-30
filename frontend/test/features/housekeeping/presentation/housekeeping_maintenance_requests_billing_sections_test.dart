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
import 'package:hosspi_hms/features/housekeeping/data/repositories/housekeeping_repository_impl.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_access.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_maintenance_requests_billing_inventory.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockHousekeepingRepository extends Mock
    implements HousekeepingRepository {}

const HousekeepingWorkItem _openRequest = HousekeepingWorkItem(
  id: 'HK-MR-1',
  displayId: 'MR-001',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Fix leaking tap',
  status: 'OPEN',
  roomLabel: 'Room 3A',
  facilityLabel: 'Main Campus',
  assetLabel: 'Tap-12',
);

const HousekeepingWorkspaceOverview _overview = HousekeepingWorkspaceOverview(
  summaryCards: <HousekeepingSummaryCard>[
    HousekeepingSummaryCard(
      id: 'pending_tasks',
      labelKey: 'pending_tasks',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'active_schedules',
      labelKey: 'active_schedules',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'open_requests',
      labelKey: 'open_requests',
      value: 1,
    ),
    HousekeepingSummaryCard(
      id: 'completed_today',
      labelKey: 'completed_today',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'overdue_requests',
      labelKey: 'overdue_requests',
      value: 0,
    ),
  ],
  lookups: HousekeepingLookups(
    facilities: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'FAC-1', label: 'Main Campus'),
    ],
    rooms: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'ROOM-1', label: 'Room 3A'),
    ],
    assets: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'ASSET-1', label: 'Tap-12'),
    ],
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['VIEWER'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: housekeepingFacilitiesMaintenanceModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
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

void _stubWorkspace(
  _MockHousekeepingRepository repository, {
  List<HousekeepingWorkItem> items = const <HousekeepingWorkItem>[_openRequest],
  Result<HousekeepingWorkspaceLoad>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workspaceOverride != null) {
      return workspaceOverride;
    }
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    final List<HousekeepingWorkItem> pageItems =
        query.resource == HousekeepingResource.maintenanceRequests
        ? items
        : const <HousekeepingWorkItem>[];
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: _overview,
        items: AppPage<HousekeepingWorkItem>(
          items: pageItems,
          request: query.pageRequest,
          totalItemCount: pageItems.length,
        ),
      ),
    );
  });
}

Future<void> _pumpMaintenanceTab(
  WidgetTester tester, {
  required _MockHousekeepingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HousekeepingWorkItem> items = const <HousekeepingWorkItem>[_openRequest],
  Result<HousekeepingWorkspaceLoad>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    items: items,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/housekeeping?section=maintenance',
    routes: <RouteBase>[
      GoRoute(
        path: '/housekeeping',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: HousekeepingWorkspacePage(
              initialSection: HousekeepingSection.maintenance,
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        housekeepingRepositoryProvider.overrideWithValue(repository),
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
  late _MockHousekeepingRepository repository;

  setUpAll(() {
    registerFallbackValue(const HousekeepingWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(
      const HousekeepingMaintenanceRequestDraft(
        status: 'OPEN',
        description: 'leak',
      ),
    );
    registerFallbackValue(
      const HousekeepingMaintenanceTriageDraft(status: 'IN_PROGRESS'),
    );
  });

  setUp(() {
    repository = _MockHousekeepingRepository();
  });

  group('Housekeeping Maintenance requests financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        HousekeepingMaintenanceRequestsBillingInventory
            .maintenanceRequestsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        HousekeepingMaintenanceRequestsBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HousekeepingMaintenanceRequestsBillingInventory.atoms, isNotEmpty);
      expect(
        HousekeepingMaintenanceRequestsBillingInventory.billableClasses.every(
          (HousekeepingMaintenanceRequestsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(
        housekeepingMaintenanceRequestsBillingScopeNote,
        contains('NOT_BILLED'),
      );

      for (final HousekeepingMaintenanceRequestsFinancialAtom atom
          in HousekeepingMaintenanceRequestsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HousekeepingMaintenanceRequestsFinancialClass>[
            HousekeepingMaintenanceRequestsFinancialClass.notRequired,
            HousekeepingMaintenanceRequestsFinancialClass.notBilled,
            HousekeepingMaintenanceRequestsFinancialClass.noCharge,
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

    test('Request maintenance primary stays NOT_BILLED', () {
      final HousekeepingMaintenanceRequestsFinancialAtom primary =
          HousekeepingMaintenanceRequestsBillingInventory.atoms.singleWhere(
            (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
                atom.id == 'request_maintenance_primary',
          );
      expect(
        primary.financialClass,
        HousekeepingMaintenanceRequestsFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('Triage, Complete, and Cancel stay NOT_BILLED', () {
      for (final String id in <String>[
        'next_action_triage',
        'detail_complete_request',
        'detail_cancel_request',
        'detail_triage_complementary',
        'nested_mutation_dialogs',
      ]) {
        final HousekeepingMaintenanceRequestsFinancialAtom atom =
            HousekeepingMaintenanceRequestsBillingInventory.atoms.singleWhere(
              (HousekeepingMaintenanceRequestsFinancialAtom entry) =>
                  entry.id == id,
            );
        expect(
          atom.financialClass,
          HousekeepingMaintenanceRequestsFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
      }
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        HousekeepingMaintenanceRequestsBillingInventory.atoms
            .singleWhere(
              (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
                  atom.id == 'patient_billable_room_turnover_surcharge',
            )
            .mounted,
        isFalse,
      );
      expect(
        HousekeepingMaintenanceRequestsBillingInventory.atoms
            .singleWhere(
              (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        HousekeepingMaintenanceRequestsBillingInventory.atoms
            .singleWhere(
              (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(
        housekeepingMaintenanceRequestsBillingScopeNote,
        contains('Billing'),
      );
    });
  });

  group('Housekeeping Maintenance requests billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
            AppPermissions.reportsRead,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.text('Fix leaking tap'), findsOneWidget);
      expect(find.byTooltip('Request maintenance'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
            AppPermissions.reportsRead,
          },
        ),
      );

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Complete request'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Housekeeping detail'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
      );

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      expect(find.text('Complete request'), findsNothing);
      expect(find.text('Cancel request'), findsNothing);
      expect(find.byTooltip('Request maintenance'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'Complete request mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(
          () => repository.updateMaintenanceRequest(any(), any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        await _pumpMaintenanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            roles: const <String>['HOUSEKEEPING_MANAGER'],
            permissions: <AppPermission>{
              AppPermissions.operationsRead,
              AppPermissions.operationsWrite,
            },
          ),
        );

        await tester.tap(find.text('Fix leaking tap'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Complete request'));
        await tester.pumpAndSettle();

        verify(
          () => repository.updateMaintenanceRequest(any(), any()),
        ).called(1);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );

    testWidgets(
      'Request maintenance primary dialog has no billing affordances',
      (WidgetTester tester) async {
        await _pumpMaintenanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            roles: const <String>['HOUSEKEEPING_MANAGER'],
            permissions: <AppPermission>{
              AppPermissions.operationsRead,
              AppPermissions.operationsWrite,
            },
          ),
        );

        await tester.tap(find.byTooltip('Request maintenance'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Balance due'), findsNothing);
        expectFlatSections(tester);
        verifyNever(() => repository.createMaintenanceRequest(any()));
      },
    );

    testWidgets(
      'Triage next-action mutation syncs without billing gate',
      (WidgetTester tester) async {
        when(
          () => repository.triageMaintenanceRequest(any(), any()),
        ).thenAnswer(
          (_) async => const Result<HousekeepingWorkItem>.success(_openRequest),
        );

        await _pumpMaintenanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            roles: const <String>['HOUSEKEEPING_MANAGER'],
            permissions: <AppPermission>{
              AppPermissions.operationsRead,
              AppPermissions.operationsWrite,
            },
          ),
        );

        expect(find.text('Triage handoff'), findsWidgets);
        await tester.tap(find.text('Triage handoff').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Submit').last);
        await tester.pumpAndSettle();

        verify(
          () => repository.triageMaintenanceRequest(any(), any()),
        ).called(1);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
      },
    );
  });

  group('Housekeeping Maintenance requests section layout (AC5)', () {
    testWidgets('desktop Maintenance: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Maintenance: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('Request maintenance dialog: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Request maintenance'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Housekeeping Maintenance requests sync / UI states (AC3–AC4, AC6)', () {
    testWidgets(
      'authorized empty state remains observable without billing UX',
      (WidgetTester tester) async {
        await _pumpMaintenanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.operationsRead},
          ),
          items: const <HousekeepingWorkItem>[],
        );

        expect(find.text('Maintenance requests'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        workspaceOverride: const Result<HousekeepingWorkspaceLoad>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary', () {
      expect(
        HousekeepingMaintenanceRequestsBillingInventory.atoms.any(
          (HousekeepingMaintenanceRequestsFinancialAtom atom) =>
              atom.financialClass ==
              HousekeepingMaintenanceRequestsFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.tab,
        housekeepingWorkspaceReadRequirement,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.requestMaintenance,
        housekeepingWorkspaceManageRequirement,
      );
    });
  });
}
