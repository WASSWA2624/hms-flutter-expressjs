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
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_billing_inventory.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/role_dashboard_scaffold.dart';

import '../../../support/section_layout_assertions.dart';

const List<AppModuleEntitlement> _billingModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home billing & sections scan', () {
    test('billing KPI inventory covers facility and portal cards', () {
      expect(
        HomeDashboardBillingInventory.statusCards.containsKey(
          'collections_today',
        ),
        isTrue,
      );
      expect(
        HomeDashboardBillingInventory.statusCards.containsKey(
          'billing_exceptions',
        ),
        isTrue,
      );
      expect(
        HomeDashboardBillingInventory.statusCards.containsKey('my_open_bills'),
        isTrue,
      );
    });

    test('facility admin revenue KPI navigates to Billing', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.facilityAdmin,
      );
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.billingRead,
          AppPermissions.patientRead,
        ],
        roles: <String>['FACILITY_ADMIN'],
      );

      final HomeMetricNavigation? revenue = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'collections_today',
          label: 'Revenue',
          value: 5000,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(revenue?.route.path, AppRoutes.billing.path);
    });

    test('billing collections KPI does not deep-link to pendingPayment queue', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.billing);
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.billingRead,
        ],
      );

      final HomeMetricNavigation? collections = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'collections_today',
          label: 'Collected today',
          value: 1200,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(collections?.route.path, AppRoutes.billing.path);
      expect(collections?.queryParameters['queue'], isNull);
    });

    test('patient open bills KPI navigates to Billing pending queue', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.patient);
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.billingRead,
        ],
        roles: <String>['PATIENT'],
      );

      final HomeMetricNavigation? bills = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'my_open_bills',
          label: 'Bills',
          value: 2,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(bills?.route.path, AppRoutes.billing.path);
      expect(bills?.queryParameters['queue'], 'pendingPayment');
    });

    test('billing quick actions route to Billing module (no bypass)', () {
      for (final String id in <String>[
        'create_invoice',
        'receive_payment',
        'process_refund',
        'close_shift',
      ]) {
        final HomeActionDefinition action = homeActionLibrary[id]!;
        expect(action.route.path, AppRoutes.billing.path);
        expect(
          HomeDashboardBillingInventory.quickActionUsesBillingModule(id),
          isTrue,
        );
      }
    });

    test('home dashboard subscribes to billing realtime event group', () {
      expect(RealtimeEventGroups.billing, isNotEmpty);
      expect(
        RealtimeEventGroups.billing.any(
          (String event) => event.toLowerCase().contains('billing') ||
              event.toLowerCase().contains('invoice') ||
              event.toLowerCase().contains('payment'),
        ),
        isTrue,
      );
    });

    test('idempotent inventory: settle actions only navigate to Billing', () {
      // Replaying home receive_payment / refund never posts locally — Billing owns collection.
      for (final String id in <String>[
        'receive_payment',
        'process_refund',
        'close_shift',
      ]) {
        final HomeDashboardBillingAtom atom =
            HomeDashboardBillingInventory.quickActions[id]!;
        expect(
          HomeDashboardBillingInventory.isInlineCollectionForbidden(
            atom.actionClass,
          ),
          isTrue,
        );
        expect(atom.billingRoute.path, AppRoutes.billing.path);
        expect(homeActionLibrary[id]!.route.path, AppRoutes.billing.path);
      }
    });

    testWidgets(
      'billing role: financial write controls hidden without billing:write',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.billingRead,
          ],
          dashboard: _billingDashboard(includeWriteActions: false),
          size: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(find.text('Create invoice'), findsNothing);
        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Refunds today'), findsNothing);
        expect(find.text('Collections today'), findsOneWidget);
      },
    );

    testWidgets(
      'billing role desktop: authorized write actions and flat sections',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.reportsRead,
          ],
          dashboard: _billingDashboard(includeWriteActions: true),
          size: const Size(1280, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.byType(RoleDashboardScaffold), findsOneWidget);
        expect(find.text('Create invoice'), findsOneWidget);
        expect(find.text('Receive payment'), findsOneWidget);
        expect(find.text('Collections today'), findsOneWidget);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'facility admin mobile: billing KPIs visible with flat section tree',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.billingRead,
            AppPermissions.patientRead,
            AppPermissions.reportsRead,
          ],
          roles: <String>['FACILITY_ADMIN'],
          dashboard: _facilityAdminDashboard(),
          size: const Size(390, 844),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Revenue'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets('error state shows retry feedback', (WidgetTester tester) async {
      final _RecordingHomeRepository repo = _RecordingHomeRepository(
        dashboardResult: const Result<HomeDashboard>.failure(
          AppFailure.network(),
        ),
      );

      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.billingRead,
        ],
        repository: repo,
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Try again'), findsOneWidget);
      repo.dashboardResult = Result<HomeDashboard>.success(
        _billingDashboard(includeWriteActions: false),
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Collections today'), findsOneWidget);
      expect(repo.loadCount, greaterThan(1));
    });
  });
}

AppAccessPolicy _policy({
  required List<AppPermission> permissions,
  List<String> roles = const <String>['BILLING'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      permissions: permissions,
      moduleEntitlements: _billingModules,
      isAuthorizationHydrated: true,
      user: AuthUserProfile(roles: roles),
    ),
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  HomeDashboard? dashboard,
  _RecordingHomeRepository? repository,
  List<String> roles = const <String>['BILLING'],
  Size size = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  final AuthSession session = AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    moduleEntitlements: _billingModules,
    isAuthorizationHydrated: true,
    user: AuthUserProfile(
      id: 'user-1',
      roles: roles,
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    ),
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(session);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final _RecordingHomeRepository repo =
      repository ??
      _RecordingHomeRepository(
        dashboardResult: Result<HomeDashboard>.success(
          dashboard ?? _billingDashboard(includeWriteActions: true),
        ),
      );

  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home.path,
        builder: (BuildContext context, GoRouterState state) {
          return const HomePage();
        },
      ),
    ],
    initialLocation: AppRoutes.home.path,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
        secureSessionStorageProvider.overrideWithValue(
          _TestSecureSessionStorage(),
        ),
        homeRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }
}

HomeDashboard _billingDashboard({required bool includeWriteActions}) {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.billing);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: <HomeStatusCard>[
      const HomeStatusCard(
        id: 'collections_today',
        label: 'Collections today',
        value: 1200,
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      if (includeWriteActions)
        const HomeStatusCard(
          id: 'refunds_today',
          label: 'Refunds today',
          value: 1,
          requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
        ),
    ],
    trend: const HomeDashboardTrend(
      title: 'Collections trend',
      subtitle: '',
      points: <HomeTrendPoint>[HomeTrendPoint(id: 'd1', date: null, value: 2)],
      requiredPermissions: <AppPermission>[AppPermissions.reportsRead],
    ),
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: includeWriteActions
        ? profile.quickActionIds
        : const <String>[],
    shortcutIds: profile.shortcutIds,
    queuePreview: const <HomeQueueItem>[
      HomeQueueItem(
        id: 'guided_billing_follow_up',
        label: 'Billing follow-up queue',
        moduleSlug: 'billing',
        status: 'OPEN',
        severity: 'HIGH',
        target: HomeRouteTarget(moduleSlug: 'billing', resource: 'invoices'),
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
    ],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

HomeDashboard _facilityAdminDashboard() {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.facilityAdmin);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: const <HomeStatusCard>[
      HomeStatusCard(
        id: 'collections_today',
        label: 'Revenue',
        value: 8000,
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCard(
        id: 'patient_flow_today',
        label: 'Flow today',
        value: 12,
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
    ],
    trend: HomeDashboardTrend.empty,
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: profile.quickActionIds,
    shortcutIds: profile.shortcutIds,
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

final class _RecordingHomeRepository implements HomeRepository {
  _RecordingHomeRepository({required this.dashboardResult});

  Result<HomeDashboard> dashboardResult;
  int loadCount = 0;

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    loadCount += 1;
    return dashboardResult;
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}

final class _TestSecureSessionStorage implements SecureSessionStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<SessionTokens?> readTokens() async => null;

  @override
  Future<void> writeTokens(SessionTokens tokens) async {}
}
