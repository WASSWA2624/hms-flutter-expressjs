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
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_storage_billing_inventory.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const MortuaryBillableEvent _billableEvent = MortuaryBillableEvent(
  id: 'bill-1',
  eventType: 'STORAGE_FEE',
  description: 'Cold storage day 1',
  amountText: '50.00',
  currency: 'UGX',
  status: 'OPEN',
  billingReferenceId: 'inv-mort-1',
);

const MortuaryWorkspaceItem _storageItem = MortuaryWorkspaceItem(
  id: 'storage-1',
  displayId: 'MOR-STO-1',
  resource: mortuaryResourceStorageAssignments,
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  patientId: 'PAT-STO-1',
  deceasedProfileLabel: 'Storage Patient',
  storageUnitLabel: 'Cold Unit A',
  storageSlotLabel: 'Slot 12',
  storageSlotStatus: 'OCCUPIED',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  storageAssignment: MortuaryStorageAssignment(
    id: 'assign-1',
    status: 'ACTIVE',
    storageUnitLabel: 'Cold Unit A',
    storageSlotLabel: 'Slot 12',
    storageSlotStatus: 'OCCUPIED',
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: mortuaryActiveModule, licenseStatus: 'ACTIVE'),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['MORTUARY_STAFF'],
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.mortuaryRead});
}

AppAccessPolicy _openBillingPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: mortuaryActiveModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _billingPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryBillingEvent,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: mortuaryActiveModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_storageItem],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelIntake,
        count: 0,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelStorage,
        count: 1,
        defaultResource: mortuaryResourceStorageAssignments,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelCustody,
        count: 0,
        defaultResource: mortuaryResourceCustodyEvents,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelRelease,
        count: 0,
        defaultResource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelReporting,
        count: 0,
        defaultResource: mortuaryResourcePostMortemRequests,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
  );
}

void _stubWorkspace(_MockMortuaryRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    return Result<MortuaryWorkspacePayload>.success(_payload(query));
  });
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer(
    (_) async => const Result<MortuaryWorkspaceItem>.success(_storageItem),
  );
}

Future<GoRouter> _pumpStorageTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  Result<MortuaryWorkspacePayload>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (workspaceOverride != null) {
    when(() => repository.getWorkspace(any())).thenAnswer(
      (_) async => workspaceOverride,
    );
  } else {
    _stubWorkspace(repository);
  }

  final GoRouter router = GoRouter(
    initialLocation: '/mortuary?panel=storage',
    routes: <RouteBase>[
      GoRoute(
        path: '/mortuary',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: MortuaryWorkspacePage(
              initialQuery: MortuaryRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          final String? patientId = state.uri.queryParameters['patient_id'];
          return Scaffold(
            body: Text(
              patientId == null || patientId.isEmpty
                  ? 'Billing workspace'
                  : 'Billing workspace patient=$patientId',
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mortuaryRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _readPolicy()),
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
  return router;
}

AppListTable<MortuaryWorkspaceItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<MortuaryWorkspaceItem>>(
    find.byType(AppListTable<MortuaryWorkspaceItem>),
  );
}

Future<void> _openDetail(WidgetTester tester) async {
  final AppListTable<MortuaryWorkspaceItem> table = _table(tester);
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_storageItem);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  group('Mortuary Storage financial inventory (AC1)', () {
    test('every mounted billable atom wires through Billing', () {
      expect(MortuaryStorageBillingInventory.all, isNotEmpty);
      expect(
        MortuaryStorageBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        MortuaryStorageBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        MortuaryStorageBillingInventory.storageFee.billingPath,
        contains('persistMortuaryBillableEventBilling'),
      );
      expect(
        MortuaryStorageBillingInventory.assignStorage.auditCode,
        'NOT_REQUIRED',
      );
      expect(MortuaryStorageBillingInventory.assignStorage.mounted, isFalse);
      expect(mortuaryStorageBillingScopeNote, contains('NOT_REQUIRED'));
      expect(mortuaryStorageBillingScopeNote, contains('Open billing'));
    });

    test('inline cashier classes are forbidden on this tab', () {
      expect(
        MortuaryStorageBillingInventory.forbidsInlineCashier(
          MortuaryStorageFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        MortuaryStorageBillingInventory.forbidsInlineCashier(
          MortuaryStorageFinancialClass.adjust,
        ),
        isTrue,
      );
      expect(
        MortuaryStorageBillingInventory.forbidsInlineCashier(
          MortuaryStorageFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        MortuaryStorageBillingInventory.collectPayment.mounted,
        isFalse,
      );
      expect(MortuaryStorageBillingInventory.adjustRefund.mounted, isFalse);
    });

    test('Open billing gate reuses billing:read', () {
      expect(
        identical(
          MortuaryStorageAtomPermissions.openBilling,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelOpenBillingRequirement(mortuaryPanelStorage),
          MortuaryStorageAtomPermissions.openBilling,
        ),
        isTrue,
      );
    });
  });

  group('Storage billing UX (AC2-AC4)', () {
    testWidgets(
      'reader has no collect/adjust; Open billing requires billing:read',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Assign storage'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing (patient-scoped) without cashier',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _openBillingPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Open billing'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Open billing'));
        await tester.pumpAndSettle();
        expect(
          find.text('Billing workspace patient=PAT-STO-1'),
          findsOneWidget,
        );
        expect(router.state.uri.path, '/billing');
        expect(router.state.uri.queryParameters['patient_id'], 'PAT-STO-1');
      },
    );

    testWidgets(
      'billing panel shows ledger mirror; unauthorized omit panel',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);
        expect(find.text('Billing'), findsNothing);
        expect(find.text('Cold storage day 1'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _billingPanelPolicy(),
        );
        await _openDetail(tester);
        expect(find.text('Billing'), findsOneWidget);
        expect(find.textContaining('Cold storage day 1'), findsOneWidget);
        expect(find.text('Open billing'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets('authorized empty / error states remain observable', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        workspaceOverride: Result<MortuaryWorkspacePayload>.success(
          MortuaryWorkspacePayload(
            items: AppPage<MortuaryWorkspaceItem>(
              items: const <MortuaryWorkspaceItem>[],
              request: const AppPageRequest(pageSize: 12),
              totalItemCount: 0,
            ),
            lookups: const MortuaryLookupData(),
            summary: const <MortuarySummaryItem>[],
            queues: const <MortuaryQueueSummary>[],
            panels: const <MortuaryPanelSummary>[
              MortuaryPanelSummary(
                id: mortuaryPanelStorage,
                count: 0,
                defaultResource: mortuaryResourceStorageAssignments,
              ),
            ],
            filters: const MortuaryWorkspaceQuery(panel: mortuaryPanelStorage),
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        ),
      );
      expect(_tab('Storage'), findsOneWidget);
      expectFlatSections(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        workspaceOverride: const Result<MortuaryWorkspacePayload>.failure(
          AppFailure.network(),
        ),
      );
      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'post-mutation sync: detail reload uses repository after row select',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _billingPanelPolicy(),
        );
        await _openDetail(tester);

        verify(
          () => repository.getItem(
            resource: any(named: 'resource'),
            id: any(named: 'id'),
            baseQuery: any(named: 'baseQuery'),
          ),
        ).called(1);
        expect(find.textContaining('Cold storage day 1'), findsOneWidget);
      },
    );
  });

  group('Storage flat sections (AC5-AC6)', () {
    testWidgets('desktop light: no nested sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _billingPanelPolicy(),
        viewport: const Size(1440, 900),
      );
      expectFlatSections(tester);
      await _openDetail(tester);
      expectFlatSections(tester);
    });

    testWidgets('mobile: flat sections', (WidgetTester tester) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _openBillingPolicy(),
        viewport: const Size(390, 844),
      );
      expectFlatSections(tester);
      await _openDetail(tester);
      expectFlatSections(tester);
      expect(find.text('Open billing'), findsOneWidget);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _billingPanelPolicy(),
        themeMode: ThemeMode.dark,
      );
      await _openDetail(tester);
      expectFlatSections(tester);
      expect(
        Theme.of(tester.element(find.text('Storage').first)).brightness,
        Brightness.dark,
      );
    });
  });
}
