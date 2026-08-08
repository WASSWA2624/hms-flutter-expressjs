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

const SubscriptionItem _licenseItem = SubscriptionItem(
  id: 'lic-1',
  resource: SubscriptionResource.licenses,
  displayId: 'LIC-1',
  tenantId: 'tenant-1',
  tenantLabel: 'Acme Clinic',
  licenseType: 'ENTERPRISE',
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
  List<SubscriptionItem> items = const <SubscriptionItem>[_licenseItem],
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
        : (query.resource == SubscriptionResource.licenses
              ? items
              : const <SubscriptionItem>[]);
    return Result<SubscriptionsWorkspaceData>.success(
      SubscriptionsWorkspaceData(
        query: query,
        summary: const <SubscriptionSummaryMetric>[
          SubscriptionSummaryMetric(
            id: 'expiring_licenses',
            label: 'Expiring licenses',
            value: 2,
          ),
        ],
        queueSummaries: const <SubscriptionQueueSummary>[
          SubscriptionQueueSummary(
            id: 'renewals_due',
            label: 'Expiring licenses',
            count: 2,
            panel: SubscriptionPanel.governance,
            resource: SubscriptionResource.licenses,
            queue: 'renewals_due',
          ),
        ],
        panelSummaries: const <SubscriptionPanelSummary>[],
        lookups: const SubscriptionLookups(
          tenants: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'tenant-1', label: 'Acme Clinic'),
          ],
          licenseTypes: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'ENTERPRISE', label: 'Enterprise'),
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

Future<void> _pumpLicensesTab(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/subscriptions?panel=governance&resource=licenses',
  bool selectLicensesTab = true,
  List<SubscriptionItem> items = const <SubscriptionItem>[_licenseItem],
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

  if (selectLicensesTab && find.byType(AppTabStrip).evaluate().isNotEmpty) {
    await _selectPanelTab(tester, 'Licenses');
  }
}

void main() {
  late _MockSubscriptionsRepository repository;

  setUpAll(() {
    registerFallbackValue(const SubscriptionsWorkspaceQuery());
    registerFallbackValue(
      const LicenseDraft(
        tenantId: 'tenant-1',
        licenseType: 'ENTERPRISE',
        status: 'ACTIVE',
      ),
    );
  });

  setUp(() {
    repository = _MockSubscriptionsRepository();
  });

  group('subscriptions_access helpers (Licenses matrix)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        SubscriptionsLicensesAtomPermissions.tab,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.create,
        same(subscriptionsWorkspaceCreateRequirement),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.update,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.delete,
        same(subscriptionsWorkspaceDeleteRequirement),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.revoke,
        same(subscriptionsWorkspaceDeleteRequirement),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.routeEntry,
        same(subscriptionsWorkspaceRouteEntryRequirement),
      );
      expect(
        subscriptionsPanelTabRequirement(SubscriptionPanel.governance),
        same(SubscriptionsLicensesAtomPermissions.tab),
      );
    });

    test('∩ denial: missing subscriptions:read blocks licenses tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsWrite},
      );
      expect(
        SubscriptionsLicensesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        canViewSubscriptionsPanel(writeOnly, SubscriptionPanel.governance),
        isFalse,
      );
    });

    test('∩ presence: subscriptions:read + module allows read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      expect(
        SubscriptionsLicensesAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.listChrome.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.expiringLicensesChip.isAllowed(
          reader,
        ),
        isTrue,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.delete.isAllowed(reader),
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
        SubscriptionsLicensesAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.update.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
    });

    test('∩ delete requires subscriptions:delete', () {
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
        SubscriptionsLicensesAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
      expect(
        SubscriptionsLicensesAtomPermissions.create.isAllowed(deleter),
        isFalse,
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
        SubscriptionsLicensesAtomPermissions.routeEntry.isAllowed(systemOnly),
        isTrue,
      );
      expect(canEnterSubscriptionsWorkspace(systemOnly), isTrue);

      // Elevated-but-scoped (route ∪ without subscriptions:*): tab still denied.
      final AppAccessPolicy elevatedScoped = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['OTHER'],
      );
      expect(
        SubscriptionsLicensesAtomPermissions.tab.isAllowed(elevatedScoped),
        isFalse,
      );
    });

    test('nested cross-module _(n/a)_ reuses workspace read/write ∩', () {
      expect(
        SubscriptionsLicensesAtomPermissions.nestedRead,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsLicensesAtomPermissions.nestedWrite,
        same(subscriptionsWorkspaceWriteRequirement),
      );
    });

    test('subscription strip: role pack without module omits licenses', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
          AppPermissions.subscriptionsDelete,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        SubscriptionsLicensesAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(subscriptionsAllowedPanels(noModule), isEmpty);
    });

    test(
      'plan caps strip subscriptions:delete even when role pack includes it',
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
          SubscriptionsLicensesAtomPermissions.tab.isAllowed(basicTier),
          isTrue,
        );
        expect(
          SubscriptionsLicensesAtomPermissions.create.isAllowed(basicTier),
          isTrue,
        );
        expect(
          SubscriptionsLicensesAtomPermissions.delete.isAllowed(basicTier),
          isFalse,
        );
        expect(canDeleteSubscriptions(basicTier), isFalse);
      },
    );
  });

  group('Licenses tab widget gates', () {
    testWidgets(
      '∩ denial: read-only hides Add/Update/Revoke; list + chip remain',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Licenses'), findsWidgets);
        expect(
          find.widgetWithText(FilterChip, 'Expiring licenses (2)'),
          findsOneWidget,
        );
        expect(find.text('ENTERPRISE'), findsOneWidget);
        expect(_toolbarPrimary('Add license'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();

        expect(find.text('Update license'), findsNothing);
        expect(find.text('Revoke license'), findsNothing);
        expect(find.text('Acme Clinic'), findsWidgets);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ presence: write mounts Add/Update; Revoke needs delete',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(_toolbarPrimary('Add license'), findsOneWidget);

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();

        expect(find.text('Update license'), findsOneWidget);
        expect(find.text('Revoke license'), findsNothing);
      },
    );

    testWidgets(
      '∩ delete mounts Revoke without write create/update',
      (WidgetTester tester) async {
        final AppAccessPolicy deleter = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsDelete,
          },
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: deleter,
        );

        expect(_toolbarPrimary('Add license'), findsNothing);

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();

        expect(find.text('Update license'), findsNothing);
        expect(find.text('Revoke license'), findsOneWidget);
      },
    );

    testWidgets(
      '∪ allowance: system:admin satisfies route entry; licenses atoms still '
      'need subscriptions:read ∩ module',
      (WidgetTester tester) async {
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['OTHER'],
        );
        expect(
          SubscriptionsLicensesAtomPermissions.routeEntry.isAllowed(systemOnly),
          isTrue,
        );
        expect(
          SubscriptionsLicensesAtomPermissions.tab.isAllowed(systemOnly),
          isFalse,
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: systemOnly,
          selectLicensesTab: false,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Add license'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription/ABAC strip: module missing omits licenses strip',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
            AppPermissions.subscriptionsDelete,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('ENTERPRISE'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module UI absent without nested rights (n/a → none)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();

        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Submit claim'), findsNothing);
        expect(find.text('Open operations'), findsNothing);
      },
    );

    testWidgets(
      'authorized Revoke flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.deleteLicense(any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy deleter = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsDelete,
          },
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: deleter,
        );

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revoke license'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Revoke this license?'), findsOneWidget);
        await tester.tap(find.text('Revoke license').last);
        await tester.pumpAndSettle();

        verify(() => repository.deleteLicense('lic-1')).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
        expect(
          find.textContaining('Subscription workspace updated.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'authorized Update flow syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.updateLicense(any(), any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Update license'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        await tester.tap(find.text('Update license').last);
        await tester.pumpAndSettle();

        verify(() => repository.updateLicense('lic-1', any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets(
      'authorized Add license flow syncs workspace after create',
      (WidgetTester tester) async {
        when(
          () => repository.createLicense(any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(_toolbarPrimary('Add license'));
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

        await tester.tap(find.text('Add license').last);
        await tester.pumpAndSettle();

        verify(() => repository.createLicense(any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
        expect(
          find.textContaining('Subscription workspace updated.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'authorized Add license validation keeps dialog open',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(_toolbarPrimary('Add license'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        await tester.tap(find.text('Add license').last);
        await tester.pumpAndSettle();

        // Required tenant empty — dialog stays; no mutation.
        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.textContaining('Select a tenant.'), findsWidgets);
        verifyNever(() => repository.createLicense(any()));
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpLicensesTab(
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

      await _pumpLicensesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        loadFailure: const AppFailure.network(),
        selectLicensesTab: false,
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

      await _pumpLicensesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('ENTERPRISE'), findsOneWidget);
    });

    testWidgets(
      'authorized loading/error chrome remains on licenses path',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Licenses'), findsWidgets);
        expect(
          find.widgetWithText(FilterChip, 'Expiring licenses (2)'),
          findsOneWidget,
        );
        expect(find.text('ENTERPRISE'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'plan caps: BASIC tier hides Revoke even with delete grant string',
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

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: basicTier,
        );

        expect(_toolbarPrimary('Add license'), findsOneWidget);

        await tester.tap(find.text('ENTERPRISE'));
        await tester.pumpAndSettle();

        expect(find.text('Update license'), findsOneWidget);
        expect(find.text('Revoke license'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('mobile viewport: licenses list and detail remain usable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
          AppPermissions.subscriptionsDelete,
        },
      );

      await _pumpLicensesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.text('ENTERPRISE'), findsWidgets);
      await tester.tap(find.text('ENTERPRISE').first);
      await tester.pumpAndSettle();
      expect(find.text('Update license'), findsOneWidget);
      expect(find.text('Revoke license'), findsOneWidget);
    });

    testWidgets('desktop viewport: licenses table and mutations mount', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpLicensesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<SubscriptionItem>), findsOneWidget);
      expect(_toolbarPrimary('Add license'), findsOneWidget);
      await tester.tap(find.text('ENTERPRISE'));
      await tester.pumpAndSettle();
      expect(find.text('Update license'), findsOneWidget);
    });

    testWidgets('light theme: authorized licenses chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpLicensesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        ),
        themeMode: ThemeMode.light,
      );

      expect(_tabLabel('Licenses'), findsWidgets);
      expect(find.text('ENTERPRISE'), findsOneWidget);
    });

    testWidgets('dark theme: authorized licenses chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpLicensesTab(
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

      expect(_tabLabel('Licenses'), findsWidgets);
      await tester.tap(find.text('ENTERPRISE'));
      await tester.pumpAndSettle();
      expect(find.text('Update license'), findsOneWidget);
    });

    testWidgets(
      'integration: AppRoutes.subscriptions name + catalog entry align',
      (WidgetTester tester) async {
        expect(AppRoutes.subscriptions.name, 'subscriptions');
        expect(
          RouteAccessCatalog.subscriptionsEntry.anyPermissions,
          <AppPermission>[AppPermissions.platformOwner, AppPermissions.systemAdmin],
        );
        expect(
          RouteAccessCatalog.subscriptionsEntry.anyRoles,
          <AppRole>[AppRole.platformOwner, AppRole.superAdmin],
        );
        expect(
          SubscriptionsLicensesAtomPermissions.catalogEntry,
          same(RouteAccessCatalog.subscriptionsEntry),
        );

        await _pumpLicensesTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.subscriptionsRead},
          ),
        );

        expect(_tabLabel('Licenses'), findsWidgets);
      },
    );
  });
}
