import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/subscriptions_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubscriptionsRepository extends Mock
    implements SubscriptionsRepository {}

const SubscriptionItem _invoiceItem = SubscriptionItem(
  id: 'inv-1',
  resource: SubscriptionResource.subscriptionInvoices,
  displayId: 'SINV-1',
  invoiceId: 'inv-1',
  invoiceDisplayId: 'SINV-1',
  tenantLabel: 'Acme Clinic',
  planLabel: 'Starter Plan',
  status: 'PAST_DUE',
  invoiceStatus: 'PAST_DUE',
  totalAmount: 49,
);

const List<AppModuleEntitlement> _subscriptionModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: subscriptionsControlsModule,
    licenseStatus: 'ACTIVE',
  ),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = _subscriptionModules,
  List<String> roles = const <String>['BILLING'],
  String? tenantId = 'tenant-1',
  String? facilityId,
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

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

void _stubWorkspace(
  _MockSubscriptionsRepository repository, {
  List<SubscriptionItem> items = const <SubscriptionItem>[_invoiceItem],
  bool empty = false,
  AppFailure? failure,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failure != null) {
      return Result<SubscriptionsWorkspaceData>.failure(failure);
    }
    final SubscriptionsWorkspaceQuery query =
        invocation.positionalArguments.single as SubscriptionsWorkspaceQuery;
    final List<SubscriptionItem> pageItems = empty
        ? const <SubscriptionItem>[]
        : (query.resource == SubscriptionResource.subscriptionInvoices
              ? items
              : const <SubscriptionItem>[]);
    return Result<SubscriptionsWorkspaceData>.success(
      SubscriptionsWorkspaceData(
        query: query,
        summary: const <SubscriptionSummaryMetric>[
          SubscriptionSummaryMetric(
            id: 'past_due_invoices',
            label: 'Past due invoices',
            value: 2,
          ),
        ],
        queueSummaries: const <SubscriptionQueueSummary>[
          SubscriptionQueueSummary(
            id: 'past_due_billing',
            label: 'Past due invoices',
            count: 2,
            panel: SubscriptionPanel.billing,
            resource: SubscriptionResource.subscriptionInvoices,
            queue: 'past_due',
          ),
        ],
        panelSummaries: const <SubscriptionPanelSummary>[],
        lookups: const SubscriptionLookups(
          invoiceStatuses: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'PAST_DUE', label: 'Past due'),
            SubscriptionLookupItem(id: 'PAID', label: 'Paid'),
          ],
        ),
        items: AppPage<SubscriptionItem>(
          items: pageItems,
          request: query.pageRequest,
          totalItemCount: pageItems.length,
        ),
        overview: const SubscriptionsOverview(
          activePlanTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.active,
            count: 0,
          ),
          notSubscribedTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.notSubscribed,
            count: 0,
          ),
          closedSubscriptionTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.closed,
            count: 0,
          ),
        ),
        timeline: const <SubscriptionTimelineItem>[],
      ),
    );
  });
  when(
    () => repository.getReferenceData(tenantId: any(named: 'tenantId')),
  ).thenAnswer(
    (_) async =>
        const Result<SubscriptionLookups>.success(SubscriptionLookups()),
  );
  when(() => repository.getPlanDetail(any())).thenAnswer(
    (_) async => const Result<SubscriptionPlanDetail>.success(
      SubscriptionPlanDetail(
        plan: SubscriptionItem(
          id: 'plan-1',
          resource: SubscriptionResource.subscriptionPlans,
        ),
      ),
    ),
  );
}

Future<void> _selectPanelTab(WidgetTester tester, String label) async {
  final Finder visible = find.text(label);
  if (visible.evaluate().isNotEmpty) {
    await tester.tap(visible.first);
    await tester.pumpAndSettle();
    return;
  }

  final Finder more = find.byKey(const ValueKey<String>('tabOverflowMore'));
  expect(more, findsOneWidget);
  await tester.tap(more);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpInvoicesTab(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation =
      '/subscriptions?panel=billing&resource=subscription-invoices',
  bool selectInvoicesTab = true,
  List<SubscriptionItem> items = const <SubscriptionItem>[_invoiceItem],
  bool empty = false,
  AppFailure? loadFailure,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    items: items,
    empty: empty,
    failure: loadFailure,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/subscriptions',
        name: AppRoutes.subscriptions.name,
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: SubscriptionsWorkspacePage(
              initialQuery: SubscriptionsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionsRepositoryProvider.overrideWithValue(repository),
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
  await tester.pumpAndSettle();

  if (selectInvoicesTab && find.byType(AppTabStrip).evaluate().isNotEmpty) {
    await _selectPanelTab(tester, 'Invoices');
  }
}

void main() {
  late _MockSubscriptionsRepository repository;

  setUpAll(() {
    registerFallbackValue(const SubscriptionsWorkspaceQuery());
    registerFallbackValue(const SubscriptionActionDraft());
  });

  setUp(() {
    repository = _MockSubscriptionsRepository();
  });

  group('subscriptions_access helpers (Invoices matrix)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        SubscriptionsInvoicesAtomPermissions.tab,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.collect,
        same(subscriptionsWorkspaceWriteRequirement),
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.retry,
        same(subscriptionsWorkspaceWriteRequirement),
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.delete,
        same(subscriptionsWorkspaceDeleteRequirement),
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.routeEntry,
        same(subscriptionsWorkspaceRouteEntryRequirement),
      );
    });

    test('∩ denial: missing subscriptions:read blocks invoices tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsWrite},
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canViewSubscriptionsPanel(writeOnly, SubscriptionPanel.billing),
          isFalse);
    });

    test('∩ presence: subscriptions:read + module allows read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.listChrome.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.pastDueChip.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.collect.isAllowed(reader),
        isFalse,
      );
    });

    test('∩ write requires subscriptions:write', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );
      expect(canWriteSubscriptions(reader), isFalse);
      expect(canWriteSubscriptions(writer), isTrue);
      expect(
        SubscriptionsInvoicesAtomPermissions.collect.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.retry.isAllowed(writer),
        isTrue,
      );
    });

    test('∩ delete requires subscriptions:delete (not mounted on tab)', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsDelete,
        },
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
    });

    test('∪ route entry: system:admin alone satisfies AppRoutes entry', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
        modules: const <AppModuleEntitlement>[],
        tenantId: null,
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.routeEntry.isAllowed(systemOnly),
        isTrue,
      );
      expect(canEnterSubscriptionsWorkspace(systemOnly), isTrue);
    });

    test('nested cross-module _(n/a)_ reuses workspace read/write ∩', () {
      expect(
        SubscriptionsInvoicesAtomPermissions.nestedRead,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.nestedWrite,
        same(subscriptionsWorkspaceWriteRequirement),
      );
    });

    test('subscription strip: role pack without module omits invoices', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        SubscriptionsInvoicesAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        subscriptionsAllowedPanels(noModule),
        isEmpty,
      );
    });

    test(
      'plan caps strip subscriptions:write on FREE even when role pack includes it',
      () {
        // FREE tier mirrors backend PLAN_PERMISSION_CAPS (no subscriptions:*).
        final AppAccessPolicy freeTier = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
            AppPermissions.subscriptionsDelete,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: subscriptionsControlsModule,
              licenseStatus: 'ACTIVE',
              planTierCode: 'FREE',
            ),
          ],
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.tab.isAllowed(freeTier),
          isFalse,
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.collect.isAllowed(freeTier),
          isFalse,
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.retry.isAllowed(freeTier),
          isFalse,
        );
        expect(canWriteSubscriptions(freeTier), isFalse);
      },
    );

    test(
      'plan caps strip subscriptions:delete on BASIC even when role pack includes it',
      () {
        // BASIC tier mirrors backend PLAN_PERMISSION_CAPS (read+write only).
        final AppAccessPolicy basicTier = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
            AppPermissions.subscriptionsDelete,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: subscriptionsControlsModule,
              licenseStatus: 'ACTIVE',
              planTierCode: 'BASIC',
            ),
          ],
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.tab.isAllowed(basicTier),
          isTrue,
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.collect.isAllowed(basicTier),
          isTrue,
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.delete.isAllowed(basicTier),
          isFalse,
        );
        expect(canDeleteSubscriptions(basicTier), isFalse);
      },
    );
  });

  group('Invoices tab widget gates', () {
    testWidgets(
      '∩ denial: read-only hides Collect/Retry; list + past-due chip remain',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Invoices'), findsWidgets);
        expect(
          find.widgetWithText(FilterChip, 'Past due invoices (2)'),
          findsOneWidget,
        );
        expect(find.text('SINV-1'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('SINV-1'));
        await tester.pumpAndSettle();

        expect(find.text('Collect invoice'), findsNothing);
        expect(find.text('Retry invoice'), findsNothing);
        expect(find.text('Acme Clinic'), findsWidgets);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ presence: write mounts Collect/Retry; create primary absent',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(
          find.descendant(
            of: find.byType(AppTabStrip).first,
            matching: find.byType(AppTabToolbarPrimary),
          ),
          findsNothing,
        );
        expect(find.text('Create plan'), findsNothing);
        expect(find.text('New subscription'), findsNothing);

        await tester.tap(find.text('SINV-1'));
        await tester.pumpAndSettle();

        expect(find.text('Collect invoice'), findsOneWidget);
        expect(find.text('Retry invoice'), findsOneWidget);
      },
    );

    testWidgets(
      '∪ allowance: system:admin satisfies route entry; invoices atoms still '
      'need subscriptions:read ∩ module',
      (WidgetTester tester) async {
        // Non-elevated holder of system:admin (route ∪) without subscriptions:*.
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['OTHER'],
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.routeEntry.isAllowed(systemOnly),
          isTrue,
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.tab.isAllowed(systemOnly),
          isFalse,
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: systemOnly,
          selectInvoicesTab: false,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Collect invoice'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription/ABAC strip: module missing omits invoices strip',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
          selectInvoicesTab: false,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('SINV-1'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module UI absent without nested rights (n/a → none)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('SINV-1'));
        await tester.pumpAndSettle();

        // No billing/claims/operations nested write affordances on invoices.
        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Submit claim'), findsNothing);
        expect(find.text('Open operations'), findsNothing);
      },
    );

    testWidgets(
      'authorized Collect flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.collectInvoice(any(), any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('SINV-1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Collect invoice'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        await tester.tap(find.text('Collect invoice').last);
        await tester.pumpAndSettle();

        verify(() => repository.collectInvoice('inv-1', any())).called(1);
        // Initial load + post-mutation refresh.
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets(
      'authorized Retry flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.retryInvoice(any(), any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('SINV-1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retry invoice'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        await tester.tap(find.text('Retry invoice').last);
        await tester.pumpAndSettle();

        verify(() => repository.retryInvoice('inv-1', any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        empty: true,
      );

      expect(find.textContaining('No subscription records'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        loadFailure: const AppFailure.network(),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(AppFailureStateView), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized list chrome remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('SINV-1'), findsOneWidget);
      expect(
        find.widgetWithText(FilterChip, 'Past due invoices (2)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'plan caps: FREE tier strips Collect/Retry even with write grant string',
      (WidgetTester tester) async {
        final AppAccessPolicy freeTier = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: subscriptionsControlsModule,
              licenseStatus: 'ACTIVE',
              planTierCode: 'FREE',
            ),
          ],
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: freeTier,
          selectInvoicesTab: false,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Collect invoice'), findsNothing);
        expect(find.text('Retry invoice'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'plan caps: BASIC tier mounts Collect/Retry; delete still not mounted',
      (WidgetTester tester) async {
        final AppAccessPolicy basicTier = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
            AppPermissions.subscriptionsDelete,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: subscriptionsControlsModule,
              licenseStatus: 'ACTIVE',
              planTierCode: 'BASIC',
            ),
          ],
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: basicTier,
        );

        await tester.tap(find.text('SINV-1'));
        await tester.pumpAndSettle();

        expect(find.text('Collect invoice'), findsOneWidget);
        expect(find.text('Retry invoice'), findsOneWidget);
        expect(find.text('Revoke'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('mobile viewport: invoices list and detail remain usable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.text('SINV-1'), findsWidgets);
      await tester.tap(find.text('SINV-1').first);
      await tester.pumpAndSettle();
      expect(find.text('Collect invoice'), findsOneWidget);
      expect(find.text('Retry invoice'), findsOneWidget);
    });

    testWidgets('desktop viewport: invoices table and mutations mount', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<SubscriptionItem>), findsOneWidget);
      await tester.tap(find.text('SINV-1'));
      await tester.pumpAndSettle();
      expect(find.text('Collect invoice'), findsOneWidget);
    });

    testWidgets('light theme: authorized invoices chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        ),
        themeMode: ThemeMode.light,
      );

      expect(_tabLabel('Invoices'), findsWidgets);
      expect(find.text('SINV-1'), findsOneWidget);
    });

    testWidgets('dark theme: authorized invoices chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpInvoicesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expect(_tabLabel('Invoices'), findsWidgets);
      await tester.tap(find.text('SINV-1'));
      await tester.pumpAndSettle();
      expect(find.text('Collect invoice'), findsOneWidget);
    });

    testWidgets(
      'integration: AppRoutes.subscriptions name + catalog entry align',
      (WidgetTester tester) async {
        expect(AppRoutes.subscriptions.name, 'subscriptions');
        expect(
          RouteAccessCatalog.subscriptionsEntry.anyPermissions,
          <AppPermission>[AppPermissions.systemAdmin],
        );
        expect(
          RouteAccessCatalog.subscriptionsEntry.anyRoles,
          <AppRole>[AppRole.superAdmin],
        );
        expect(
          SubscriptionsInvoicesAtomPermissions.catalogEntry,
          same(RouteAccessCatalog.subscriptionsEntry),
        );

        await _pumpInvoicesTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.subscriptionsRead},
          ),
        );

        expect(_tabLabel('Invoices'), findsWidgets);
      },
    );
  });
}
