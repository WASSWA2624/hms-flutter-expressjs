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
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_custody_billing_inventory.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryBillableEvent _billableEvent = MortuaryBillableEvent(
  id: 'bill-1',
  eventType: 'STORAGE_FEE',
  description: 'Cold storage day 1',
  amountText: '50.00',
  currency: 'UGX',
  status: 'PENDING',
  billingReferenceId: 'inv-mort-1',
);

const MortuaryWorkspaceItem _custodyItem = MortuaryWorkspaceItem(
  id: 'custody-1',
  displayId: 'MOR-CUS-1',
  resource: mortuaryResourceCustodyEvents,
  status: 'TRANSFER',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  patientId: 'PAT0001',
  deceasedProfileLabel: 'Custody Patient',
  eventType: 'TRANSFER',
  actorName: 'Officer A',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  custodyEvents: <MortuaryTimelineEvent>[
    MortuaryTimelineEvent(
      id: 'evt-1',
      eventType: 'TRANSFER',
      actorName: 'Officer A',
    ),
  ],
  mortuaryCase: MortuaryCaseSummary(
    id: 'MOR0001',
    status: 'IN_STORAGE',
    identificationStatus: 'VERIFIED',
    billingStatus: 'UNSETTLED',
    patientId: 'PAT0001',
    patientLabel: 'Custody Patient',
    deceasedProfileLabel: 'Custody Patient',
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsBilling =
      permissions.contains(AppPermissions.billingRead) ||
      permissions.contains(AppPermissions.billingWrite) ||
      permissions.contains(AppPermissions.mortuaryBillingEvent);
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['MORTUARY_STAFF'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
          modules ??
          <AppModuleEntitlement>[
            const AppModuleEntitlement(
              code: mortuaryActiveModule,
              licenseStatus: 'ACTIVE',
            ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.mortuaryRead});
}

AppAccessPolicy _billingReadPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.billingRead,
    },
  );
}

AppAccessPolicy _billingPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryBillingEvent,
      AppPermissions.billingRead,
    },
  );
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_custodyItem],
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
        count: 0,
        defaultResource: mortuaryResourceStorageAssignments,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelCustody,
        count: 1,
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_custodyItem),
  );
}

Future<GoRouter> _pumpCustodyTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/mortuary?panel=custody',
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
              patientId == null
                  ? 'billing-workspace'
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

Future<void> _openCustodyDetail(WidgetTester tester) async {
  final AppListTable<MortuaryWorkspaceItem> table = tester
      .widget<AppListTable<MortuaryWorkspaceItem>>(
        find.byType(AppListTable<MortuaryWorkspaceItem>),
      );
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_custodyItem);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  group('Mortuary Custody billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(MortuaryCustodyBillingInventory.all, isNotEmpty);
      expect(
        MortuaryCustodyBillingInventory.all.map(
          (MortuaryCustodyFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'record_custody',
          'post_mortem_request',
          'storage_fee',
          'embalming_fee',
          'viewing_fee',
          'release_fee',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      for (final MortuaryCustodyFinancialAtom atom
          in MortuaryCustodyBillingInventory.all) {
        final bool notBillable =
            atom.financialClass == MortuaryCustodyFinancialClass.notBilled ||
            atom.financialClass == MortuaryCustodyFinancialClass.notRequired ||
            atom.financialClass == MortuaryCustodyFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(
        mortuaryCustodyBillingScopeNote,
        contains('persistMortuaryBillableEventBilling'),
      );
      expect(
        MortuaryCustodyBillingInventory.recordCustody.financialClass,
        MortuaryCustodyFinancialClass.notRequired,
      );
      expect(
        MortuaryCustodyBillingInventory.printDocuments.auditCode,
        'NO_CHARGE',
      );
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        MortuaryCustodyBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final MortuaryCustodyFinancialAtom atom
          in MortuaryCustodyBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('approutes'),
            contains('invoice'),
          ),
          reason: atom.id,
        );
      }
      expect(
        MortuaryCustodyBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        MortuaryCustodyBillingInventory.storageFee.billingPath,
        contains('persistMortuaryBillableEventBilling'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Custody', () {
      expect(MortuaryCustodyBillingInventory.collectPayment.mounted, isFalse);
      expect(MortuaryCustodyBillingInventory.adjustRefund.mounted, isFalse);
      expect(MortuaryCustodyBillingInventory.recordCustody.mounted, isFalse);
      expect(
        MortuaryCustodyBillingInventory.forbidsInlineCashier(
          MortuaryCustodyFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        MortuaryCustodyAtomPermissions.openBilling,
        same(MortuaryCustodyBillingInventory.openBilling.requirement),
      );
    });
  });

  group('Mortuary Custody billing wiring (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.mortuary,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'Open billing navigates with patient_id; no cashier — desktop light',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
          tester,
          repository: repository,
          accessPolicy: _billingReadPolicy(),
        );

        await _openCustodyDetail(tester);

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Record custody'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=PAT0001'),
          findsOneWidget,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'unauthorized cannot Open billing or collect — mobile dark',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _readPolicy();
        expect(
          MortuaryCustodyAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );

        await _pumpCustodyTab(
          tester,
          repository: repository,
          accessPolicy: reader,
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await _openCustodyDetail(tester);

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing events panel mounts with billing_event ∩ billing:read',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
          tester,
          repository: repository,
          accessPolicy: _billingPanelPolicy(),
        );

        await _openCustodyDetail(tester);

        expect(find.text('Billing'), findsWidgets);
        expect(find.textContaining('Cold storage day 1'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.text('Issue invoice'), findsNothing);
      },
    );
  });

  group('Mortuary Custody flat sections (AC5)', () {
    testWidgets('detail panels are siblings — desktop light', (
      WidgetTester tester,
    ) async {
      await _pumpCustodyTab(
        tester,
        repository: repository,
        accessPolicy: _billingPanelPolicy(),
      );

      await _openCustodyDetail(tester);

      expect(find.byType(AppCollapsibleSection), findsWidgets);
      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Custody detail desktop light',
      );
    });

    testWidgets('detail panels are siblings — mobile dark', (
      WidgetTester tester,
    ) async {
      await _pumpCustodyTab(
        tester,
        repository: repository,
        accessPolicy: _billingReadPolicy(),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      await _openCustodyDetail(tester);

      expect(find.byType(AppCollapsibleSection), findsWidgets);
      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Custody detail mobile dark',
      );
    });
  });

  group('Mortuary Custody sync / UI states (AC3, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer((
        Invocation invocation,
      ) async {
        final MortuaryWorkspaceQuery query =
            invocation.positionalArguments.single as MortuaryWorkspaceQuery;
        return Result<MortuaryWorkspacePayload>.success(
          MortuaryWorkspacePayload(
            items: AppPage<MortuaryWorkspaceItem>(
              items: const <MortuaryWorkspaceItem>[],
              request: query.pageRequest,
              totalItemCount: 0,
            ),
            lookups: const MortuaryLookupData(),
            summary: const <MortuarySummaryItem>[],
            queues: const <MortuaryQueueSummary>[],
            panels: const <MortuaryPanelSummary>[
              MortuaryPanelSummary(
                id: mortuaryPanelCustody,
                count: 0,
                defaultResource: mortuaryResourceCustodyEvents,
              ),
            ],
            filters: query,
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        );
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final GoRouter router = GoRouter(
        initialLocation: '/mortuary?panel=custody',
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
            appAccessPolicyProvider.overrideWithValue(_readPolicy()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error list state has no cashier; flat sections', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<MortuaryWorkspacePayload>.failure(
          AppFailure.network(),
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final GoRouter router = GoRouter(
        initialLocation: '/mortuary?panel=custody',
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
            appAccessPolicyProvider.overrideWithValue(_billingReadPolicy()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.text('Open billing'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
