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

const SubscriptionItem _subscriptionItem = SubscriptionItem(
  id: 'sub-1',
  resource: SubscriptionResource.subscriptions,
  displayId: 'SUB-1',
  tenantId: 'tenant-1',
  tenantLabel: 'Acme Clinic',
  planId: 'plan-1',
  planLabel: 'Starter Plan',
  planCode: 'STARTER',
  status: 'ACTIVE',
);

const SubscriptionItem _cancelledSubscriptionItem = SubscriptionItem(
  id: 'sub-cancelled',
  resource: SubscriptionResource.subscriptions,
  displayId: 'SUB-C',
  tenantId: 'tenant-1',
  tenantLabel: 'Closed Clinic',
  planId: 'plan-1',
  planLabel: 'Starter Plan',
  planCode: 'STARTER',
  status: 'CANCELLED',
);

const SubscriptionItem _moduleSubscriptionItem = SubscriptionItem(
  id: 'mod-sub-1',
  resource: SubscriptionResource.moduleSubscriptions,
  displayId: 'MSUB-1',
  tenantId: 'tenant-1',
  tenantLabel: 'Acme Clinic',
  moduleId: 'mod-1',
  moduleLabel: 'Billing',
  isActive: true,
  status: 'ACTIVE',
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

Finder _toolbarPrimary(String label) => find.byTooltip(label);

void _stubWorkspace(
  _MockSubscriptionsRepository repository, {
  List<SubscriptionItem> items = const <SubscriptionItem>[_subscriptionItem],
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
    List<SubscriptionItem> pageItems;
    if (empty) {
      pageItems = const <SubscriptionItem>[];
    } else if (query.resource == SubscriptionResource.subscriptions) {
      pageItems = items
          .where(
            (SubscriptionItem item) =>
                item.resource == SubscriptionResource.subscriptions,
          )
          .toList(growable: false);
      if (pageItems.isEmpty) {
        pageItems = items;
      }
    } else if (query.resource == SubscriptionResource.moduleSubscriptions) {
      pageItems = items
          .where(
            (SubscriptionItem item) =>
                item.resource == SubscriptionResource.moduleSubscriptions,
          )
          .toList(growable: false);
      if (pageItems.isEmpty) {
        pageItems = const <SubscriptionItem>[_moduleSubscriptionItem];
      }
    } else {
      pageItems = const <SubscriptionItem>[];
    }
    return Result<SubscriptionsWorkspaceData>.success(
      SubscriptionsWorkspaceData(
        query: query,
        summary: const <SubscriptionSummaryMetric>[
          SubscriptionSummaryMetric(
            id: 'pending_changes',
            label: 'Pending changes',
            value: 1,
          ),
        ],
        queueSummaries: const <SubscriptionQueueSummary>[
          SubscriptionQueueSummary(
            id: 'pending_changes',
            label: 'Pending changes',
            count: 1,
            panel: SubscriptionPanel.operations,
            resource: SubscriptionResource.subscriptions,
            queue: 'pending_changes',
          ),
        ],
        panelSummaries: const <SubscriptionPanelSummary>[],
        lookups: const SubscriptionLookups(
          tenants: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'tenant-1', label: 'Acme Clinic'),
          ],
          plans: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'plan-1', label: 'Starter Plan'),
          ],
          modules: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'mod-1', label: 'Billing'),
          ],
          statuses: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'ACTIVE', label: 'Active'),
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

Future<void> _pumpSubscriptionsTab(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation =
      '/subscriptions?panel=operations&resource=subscriptions',
  bool selectSubscriptionsTab = true,
  List<SubscriptionItem> items = const <SubscriptionItem>[_subscriptionItem],
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

  if (selectSubscriptionsTab &&
      find.byType(AppTabStrip).evaluate().isNotEmpty) {
    await _selectPanelTab(tester, 'Subscriptions');
  }
}

void main() {
  late _MockSubscriptionsRepository repository;

  setUpAll(() {
    registerFallbackValue(const SubscriptionsWorkspaceQuery());
    registerFallbackValue(
      const SubscriptionDraft(
        tenantId: 'tenant-1',
        planId: 'plan-1',
        status: 'ACTIVE',
      ),
    );
  });

  setUp(() {
    repository = _MockSubscriptionsRepository();
  });

  group('subscriptions_access helpers (Subscriptions matrix)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        SubscriptionsAtomPermissions.tab,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.create,
        same(subscriptionsWorkspaceCreateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.newSubscription,
        same(subscriptionsWorkspaceCreateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.assignModule,
        same(subscriptionsWorkspaceCreateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.update,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.edit,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.renew,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.changePlan,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.activate,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.cancel,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.toggleModule,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.delete,
        same(subscriptionsWorkspaceDeleteRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.nestedRead,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.nestedWrite,
        same(subscriptionsWorkspaceWriteRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        SubscriptionsAtomPermissions.routeEntry,
        same(subscriptionsWorkspaceRouteEntryRequirement),
      );
      expect(
        subscriptionsPanelTabRequirement(SubscriptionPanel.operations),
        same(SubscriptionsAtomPermissions.tab),
      );
    });

    test('∩ denial: missing subscriptions:read blocks subscriptions tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsWrite},
      );
      expect(
        SubscriptionsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        canViewSubscriptionsPanel(writeOnly, SubscriptionPanel.operations),
        isFalse,
      );
    });

    test('∩ presence: subscriptions:read + module allows read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      expect(SubscriptionsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        SubscriptionsAtomPermissions.listChrome.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsAtomPermissions.pendingChangesChip.isAllowed(reader),
        isTrue,
      );
      expect(SubscriptionsAtomPermissions.create.isAllowed(reader), isFalse);
      expect(SubscriptionsAtomPermissions.cancel.isAllowed(reader), isFalse);
      expect(SubscriptionsAtomPermissions.delete.isAllowed(reader), isFalse);
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
      expect(SubscriptionsAtomPermissions.create.isAllowed(writer), isTrue);
      expect(SubscriptionsAtomPermissions.update.isAllowed(writer), isTrue);
      expect(SubscriptionsAtomPermissions.cancel.isAllowed(writer), isTrue);
      expect(SubscriptionsAtomPermissions.delete.isAllowed(writer), isFalse);
    });

    test('∩ delete requires subscriptions:delete (HTTP delete not mounted)', () {
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
      expect(SubscriptionsAtomPermissions.delete.isAllowed(writer), isFalse);
      expect(SubscriptionsAtomPermissions.delete.isAllowed(deleter), isTrue);
      // Soft cancel remains write ∩ — delete alone does not grant cancel.
      expect(SubscriptionsAtomPermissions.cancel.isAllowed(deleter), isFalse);
      expect(SubscriptionsAtomPermissions.create.isAllowed(deleter), isFalse);
    });

    test('∪ route entry: system:admin alone satisfies AppRoutes entry', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
        modules: const <AppModuleEntitlement>[],
        tenantId: null,
      );
      expect(
        SubscriptionsAtomPermissions.routeEntry.isAllowed(systemOnly),
        isTrue,
      );
      expect(canEnterSubscriptionsWorkspace(systemOnly), isTrue);

      // Elevated-but-scoped (route ∪ without subscriptions:*): tab still denied.
      final AppAccessPolicy elevatedScoped = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['OTHER'],
      );
      expect(
        SubscriptionsAtomPermissions.tab.isAllowed(elevatedScoped),
        isFalse,
      );
    });

    test('nested cross-module _(n/a)_ reuses workspace read/write ∩', () {
      expect(
        SubscriptionsAtomPermissions.nestedRead,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsAtomPermissions.nestedWrite,
        same(subscriptionsWorkspaceWriteRequirement),
      );
    });

    test('subscription strip: role pack without module omits subscriptions', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
          AppPermissions.subscriptionsDelete,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(SubscriptionsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(subscriptionsAllowedPanels(noModule), isEmpty);
    });
  });

  group('Subscriptions tab widget gates', () {
    testWidgets(
      '∩ denial: read-only hides New/Edit/Cancel; list + pending chip remain',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Subscriptions'), findsWidgets);
        expect(
          find.widgetWithText(FilterChip, 'Pending changes (1)'),
          findsOneWidget,
        );
        expect(find.text('Acme Clinic'), findsOneWidget);
        expect(_toolbarPrimary('New subscription'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Edit subscription'), findsNothing);
        expect(find.text('Change plan'), findsNothing);
        expect(find.text('Cancel subscription'), findsNothing);
        expect(find.text('Acme Clinic'), findsWidgets);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ presence: write mounts New/Edit/Cancel/Renew; HTTP delete not mounted',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(_toolbarPrimary('New subscription'), findsOneWidget);

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Edit subscription'), findsOneWidget);
        expect(find.text('Change plan'), findsOneWidget);
        expect(find.text('Renew'), findsOneWidget);
        expect(find.text('Cancel subscription'), findsOneWidget);
        expect(find.text('Activate'), findsNothing);
        expect(find.text('Delete subscription'), findsNothing);
        expect(find.text('Revoke license'), findsNothing);
      },
    );

    testWidgets(
      '∩ presence: Activate mounts for cancelled subscription when write ∩',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
          items: const <SubscriptionItem>[_cancelledSubscriptionItem],
        );

        await tester.tap(find.text('Closed Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Activate'), findsOneWidget);
        expect(find.text('Cancel subscription'), findsNothing);
        expect(find.text('Edit subscription'), findsOneWidget);
      },
    );

    testWidgets(
      'subscription detail: read hides Assign module and module toggles',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_toolbarPrimary('Assign module'), findsNothing);
        expect(find.text('Module subscriptions'), findsNothing);

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Module access'), findsOneWidget);
        expect(find.text('Assign module'), findsNothing);
        expect(find.text('Disable module'), findsNothing);
        expect(find.text('Enable module'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription detail: write mounts Assign module and Disable',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(_toolbarPrimary('Assign module'), findsNothing);
        expect(_toolbarPrimary('New subscription'), findsOneWidget);

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Module access'), findsOneWidget);
        expect(find.text('Assign module'), findsWidgets);
        expect(find.text('Billing'), findsWidgets);
        expect(find.text('Disable module'), findsOneWidget);
      },
    );

    testWidgets(
      'legacy module-subscriptions deep link opens subscriptions worklist',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
          initialLocation:
              '/subscriptions?panel=operations&resource=module-subscriptions',
          selectSubscriptionsTab: false,
        );

        expect(_toolbarPrimary('New subscription'), findsOneWidget);
        expect(_toolbarPrimary('Assign module'), findsNothing);
        expect(find.text('Acme Clinic'), findsOneWidget);
        expect(
          tester
              .widgetList<AppTabStrip>(find.byType(AppTabStrip))
              .where(
                (AppTabStrip strip) =>
                    strip.variant == AppTabStripVariant.nested,
              ),
          isEmpty,
        );
      },
    );

    testWidgets(
      '∩ delete alone does not mount write atoms or HTTP delete control',
      (WidgetTester tester) async {
        final AppAccessPolicy deleter = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsDelete,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: deleter,
        );

        expect(_toolbarPrimary('New subscription'), findsNothing);

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Edit subscription'), findsNothing);
        expect(find.text('Cancel subscription'), findsNothing);
        expect(find.text('Renew'), findsNothing);
        expect(find.text('Delete subscription'), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: system:admin satisfies route entry; subscriptions atoms '
      'still need subscriptions:read ∩ module',
      (WidgetTester tester) async {
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['OTHER'],
        );
        expect(
          SubscriptionsAtomPermissions.routeEntry.isAllowed(systemOnly),
          isTrue,
        );
        expect(
          SubscriptionsAtomPermissions.tab.isAllowed(systemOnly),
          isFalse,
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: systemOnly,
          selectSubscriptionsTab: false,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('New subscription'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription/ABAC strip: module missing omits subscriptions strip',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
            AppPermissions.subscriptionsDelete,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Acme Clinic'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module UI absent without nested rights (n/a → none)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();

        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Submit claim'), findsNothing);
        expect(find.text('Open operations'), findsNothing);
        expect(find.text('Manage modules'), findsNothing);
      },
    );

    testWidgets(
      'authorized Cancel flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.cancelSubscription(any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel subscription'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Cancel this subscription?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel subscription').last);
        await tester.pumpAndSettle();

        verify(() => repository.cancelSubscription('sub-1')).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets(
      'authorized Edit flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.updateSubscription(any(), any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Acme Clinic'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit subscription'));
        await tester.pumpAndSettle();

        expect(find.text('Save subscription'), findsOneWidget);
        await tester.tap(find.text('Save subscription'));
        await tester.pumpAndSettle();

        verify(() => repository.updateSubscription('sub-1', any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpSubscriptionsTab(
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

      await _pumpSubscriptionsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        loadFailure: const AppFailure.network(),
        selectSubscriptionsTab: false,
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(AppFailureStateView), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'authorized New subscription flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.createSubscription(any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(_toolbarPrimary('New subscription'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        final Finder tenantField = find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppSelectField<String> && widget.labelText == 'Tenant',
        );
        expect(tenantField, findsOneWidget);
        tester
            .widget<AppSelectField<String>>(tenantField)
            .onChanged
            ?.call('tenant-1');
        await tester.pumpAndSettle();

        final Finder planField = find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppSelectField<String> && widget.labelText == 'Plan',
        );
        expect(planField, findsOneWidget);
        tester
            .widget<AppSelectField<String>>(planField)
            .onChanged
            ?.call('plan-1');
        await tester.pumpAndSettle();

        await tester.tap(find.text('New subscription').last);
        await tester.pumpAndSettle();

        verify(() => repository.createSubscription(any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets('authorized list chrome remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpSubscriptionsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Acme Clinic'), findsOneWidget);
      expect(
        find.widgetWithText(FilterChip, 'Pending changes (1)'),
        findsOneWidget,
      );
    });

    testWidgets('mobile viewport: subscriptions list and detail remain usable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpSubscriptionsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Acme Clinic'), findsWidgets);
      await tester.tap(find.text('Acme Clinic').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit subscription'), findsOneWidget);
      expect(find.text('Cancel subscription'), findsOneWidget);
    });

    testWidgets('desktop viewport: subscriptions table and mutations mount', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpSubscriptionsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<SubscriptionItem>), findsOneWidget);
      expect(_toolbarPrimary('New subscription'), findsOneWidget);
      await tester.tap(find.text('Acme Clinic'));
      await tester.pumpAndSettle();
      expect(find.text('Edit subscription'), findsOneWidget);
    });

    testWidgets('light theme: authorized subscriptions chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpSubscriptionsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        ),
        themeMode: ThemeMode.light,
      );

      expect(_tabLabel('Subscriptions'), findsWidgets);
      expect(find.text('Acme Clinic'), findsOneWidget);
    });

    testWidgets('dark theme: authorized subscriptions chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpSubscriptionsTab(
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

      expect(_tabLabel('Subscriptions'), findsWidgets);
      await tester.tap(find.text('Acme Clinic'));
      await tester.pumpAndSettle();
      expect(find.text('Edit subscription'), findsOneWidget);
    });

    testWidgets(
      'integration: AppRoutes.subscriptions name + catalog entry align',
      (WidgetTester tester) async {
        expect(AppRoutes.subscriptions.name, 'subscriptions');
        expect(
          RouteAccessCatalog.subscriptionsEntry.allPermissions,
          <AppPermission>[AppPermissions.subscriptionsRead],
        );
        expect(
          SubscriptionsAtomPermissions.catalogEntry,
          same(RouteAccessCatalog.subscriptionsEntry),
        );

        await _pumpSubscriptionsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.subscriptionsRead},
          ),
        );

        expect(_tabLabel('Subscriptions'), findsWidgets);
        expect(find.text('Acme Clinic'), findsOneWidget);
      },
    );
  });
}
