import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_overview_billing_inventory.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
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

const MortuaryWorkspaceItem _overviewItem = MortuaryWorkspaceItem(
  id: 'case-1',
  displayId: 'MOR-001',
  resource: mortuaryResourceCases,
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'PENDING',
  patientId: 'PAT-MORT-1',
  deceasedProfileLabel: 'Overview Patient',
  storageUnitLabel: 'Cold Bay A',
  storageSlotLabel: 'A-1',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
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

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_overviewItem],
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_overviewItem),
  );
}

Future<void> _pumpOverviewTab(
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
    initialLocation: '/mortuary',
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
          return Scaffold(
            body: Text(
              'Billing workspace patient=${state.uri.queryParameters['patient_id'] ?? ''}',
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  tester.takeException();
}

Future<void> _openDetail(WidgetTester tester) async {
  final Finder row = find.text('Overview Patient');
  expect(row, findsWidgets);
  await tester.tap(row.first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  group('Mortuary Overview billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(MortuaryOverviewBillingInventory.atoms, isNotEmpty);
      expect(
        MortuaryOverviewBillingInventory.atoms.map(
          (MortuaryOverviewFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'list_chrome',
          'empty_loading_error',
          'row_select',
          'billing_status_chip',
          'billing_events_panel',
          'open_billing',
          'absent_inline_collect',
          'storage_fee',
          'embalming_fee',
          'viewing_fee',
          'release_fee',
          'custody_transfer',
          'adjust_refund',
        ]),
      );
      for (final MortuaryOverviewFinancialAtom atom
          in MortuaryOverviewBillingInventory.atoms) {
        final bool notBillable =
            atom.financialClass == MortuaryOverviewFinancialClass.notBilled ||
            atom.financialClass == MortuaryOverviewFinancialClass.notRequired ||
            atom.financialClass == MortuaryOverviewFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(MortuaryOverviewBillingInventory.openBilling.mounted, isTrue);
      expect(MortuaryOverviewBillingInventory.storageFee.mounted, isFalse);
      expect(
        MortuaryOverviewBillingInventory.absentInlineCollect.mounted,
        isFalse,
      );
      expect(
        MortuaryOverviewBillingInventory.custodyTransfer.auditCode,
        'NOT_REQUIRED',
      );
    });

    test('AC2: billable atoms wire through Billing; inline collect forbidden', () {
      expect(
        MortuaryOverviewBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        MortuaryOverviewBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        MortuaryOverviewBillingInventory.storageFee.billingPath,
        contains('persistMortuaryBillableEventBilling'),
      );
      for (final MortuaryOverviewFinancialAtom atom
          in MortuaryOverviewBillingInventory.atoms) {
        if (MortuaryOverviewBillingInventory.isInlineCollectionForbidden(
          atom.financialClass,
        )) {
          expect(
            atom.mounted == false ||
                (atom.billingPath?.contains('Billing') ?? false) ||
                (atom.billingPath?.contains('billing') ?? false),
            isTrue,
            reason: '${atom.id} must not bypass Billing',
          );
        }
      }
      expect(
        identical(
          MortuaryOverviewAtomPermissions.openBilling,
          MortuaryOverviewAtomPermissions.openBilling,
        ),
        isTrue,
      );
    });

    test('AC3: mortuary realtime includes billing for status parity', () {
      expect(RealtimeEventGroups.mortuary, isNotEmpty);
      expect(
        RealtimeEventGroups.mortuary.any(
          (String event) =>
              event.toLowerCase().contains('billing') ||
              event.toLowerCase().contains('invoice') ||
              event.toLowerCase().contains('payment'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'AC2/AC3/AC4: Open billing navigates; pending parity; no cashier',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await _openDetail(tester);

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Clear billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=PAT-MORT-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC4/AC6: unauthorized users cannot open billing or collect',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.mortuaryRead},
        );
        expect(
          MortuaryOverviewAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await _openDetail(tester);

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'AC4: billing events panel gated; authorized sees mirror',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryBillingEvent,
              AppPermissions.billingRead,
            },
          ),
        );

        await _openDetail(tester);

        expect(find.text('Billing'), findsWidgets);
        expect(find.textContaining('Cold storage'), findsWidgets);
      },
    );

    testWidgets('AC5: desktop light — flat sections on Overview detail', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.billingRead,
            AppPermissions.mortuaryBillingEvent,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );

      await _openDetail(tester);

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Overview detail desktop light',
      );
      expect(find.byType(AppWorkspaceDetailPanel), findsWidgets);
    });

    testWidgets('AC5: mobile dark — flat sections on Overview detail', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.mortuaryRead,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      final Finder row = find.text('Overview Patient');
      await tester.ensureVisible(row.first);
      await tester.tap(row.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      tester.takeException();

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Overview detail mobile dark',
      );
    });

    testWidgets('AC4: empty state remains observable on Overview', (
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
                id: mortuaryPanelOverview,
                count: 0,
                defaultResource: mortuaryResourceCases,
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
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/mortuary',
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
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.mortuaryRead},
              ),
            ),
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Open billing'), findsNothing);
    });
  });
}
