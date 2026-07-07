import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/app.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:patrol/patrol.dart';

import '../../test/helpers/test_harness.dart';
import 'demo_credentials.dart';

export '../../test/helpers/test_harness.dart';

/// Mobile viewport used for responsive Patrol smoke coverage.
const Size patrolMobileViewport = Size(390, 844);

/// Desktop viewport used for responsive Patrol smoke coverage.
const Size patrolDesktopViewport = Size(1440, 900);

const String patrolTestTenantId = 'tenant-patrol-test';
const String patrolTestFacilityId = 'facility-patrol-test';

/// Module entitlements for offline shell tests that deep-link gated routes.
const List<AppModuleEntitlement> patrolModuleEntitlements =
    <AppModuleEntitlement>[
      AppModuleEntitlement(code: 'billing-insurance'),
      AppModuleEntitlement(code: 'scheduling-queue'),
      AppModuleEntitlement(code: 'inpatient-bed-management'),
      AppModuleEntitlement(code: 'icu-critical-care'),
      AppModuleEntitlement(code: 'encounters-vitals'),
      AppModuleEntitlement(code: 'physiotherapy'),
      AppModuleEntitlement(code: 'lab-workflows'),
      AppModuleEntitlement(code: 'radiology-workflows'),
      AppModuleEntitlement(code: 'pharmacy-dispensing'),
      AppModuleEntitlement(code: 'facilities-maintenance'),
      AppModuleEntitlement(code: 'hr-rosters'),
      AppModuleEntitlement(code: 'biomedical-engineering-suite'),
      AppModuleEntitlement(code: 'notifications-communications'),
      AppModuleEntitlement(code: 'integrations-core'),
      AppModuleEntitlement(code: 'theatre-anesthesia'),
      AppModuleEntitlement(code: 'reporting-analytics'),
    ];

AppConfig patrolTestAppConfig() {
  return AppConfig.fromValues(
    environmentName: 'development',
    apiBaseUrl: 'http://localhost:3000',
    logLevelName: 'debug',
  );
}

List<Object?> patrolE2eOverrides() {
  return <Object?>[appConfigProvider.overrideWithValue(patrolTestAppConfig())];
}

List<Object?> patrolShellOverrides() {
  return <Object?>[
    ...patrolE2eOverrides(),
    homeRepositoryProvider.overrideWithValue(_patrolHomeRepository),
  ];
}

HomeDashboard patrolHomeDashboardFixture() {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.tenantAdmin);

  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: const HomeDashboardContext(roleValue: 'TENANT_ADMIN'),
    statusCards: profile.fallbackStatusCards(),
    trend: HomeDashboardTrend.empty,
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: profile.quickActionIds,
    shortcutIds: profile.shortcutIds,
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
    usesFallbackData: true,
  );
}

final HomeRepository _patrolHomeRepository = _PatrolHomeRepository();

final class _PatrolHomeRepository implements HomeRepository {
  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    return Result<HomeDashboard>.success(patrolHomeDashboardFixture());
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}

SessionState patrolAuthenticatedSessionState() {
  return SessionState.authenticated(
    session: AuthSession(
      tokens: SessionTokens(accessToken: 'patrol-test-access-token'),
      subject: 'admin@example.com',
      moduleEntitlements: patrolModuleEntitlements,
      user: const AuthUserProfile(
        id: 'user-patrol-123',
        displayId: 'USR-PATROL',
        email: 'admin@example.com',
        firstName: 'Patrol',
        lastName: 'Admin',
        tenantId: patrolTestTenantId,
        tenantName: 'IHK Hospital',
        facilityId: patrolTestFacilityId,
        facilityName: 'IHK Hospital',
        facilityType: 'hospital',
        positionTitle: 'tenant_admin',
        staffNumber: 'STF-PATROL',
        staffPosition: 'administrator',
        roles: <String>['tenant_admin'],
      ),
    ),
  );
}

List<Object?> patrolAuthenticatedOverrides({
  String? initialLocation,
  SessionState? sessionState,
}) {
  final SessionState effectiveSession =
      sessionState ?? patrolAuthenticatedSessionState();

  return testReadyAppOverrides(
    sessionState: effectiveSession,
    initialLocation: initialLocation,
  );
}

Future<void> pumpPatrolApp(
  PatrolIntegrationTester $, {
  List<Object?> overrides = const <Object?>[],
  List<Object?> baseOverrides = const <Object?>[],
  Size viewport = patrolDesktopViewport,
}) async {
  setTestViewport($.tester, viewport);

  await $.pumpWidget(
    ProviderScope(
      overrides: <Object?>[...baseOverrides, ...overrides].cast(),
      child: const HosspiHmsApp(),
    ),
  );
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

Future<void> pumpPatrolShellApp(
  PatrolIntegrationTester $, {
  List<Object?> overrides = const <Object?>[],
  Size viewport = patrolDesktopViewport,
}) {
  return pumpPatrolApp(
    $,
    baseOverrides: patrolShellOverrides(),
    overrides: overrides,
    viewport: viewport,
  );
}

Future<void> pumpPatrolE2eApp(
  PatrolIntegrationTester $, {
  String initialLocation = '/login',
  Size viewport = patrolDesktopViewport,
}) {
  return pumpPatrolApp(
    $,
    baseOverrides: patrolE2eOverrides(),
    overrides: testReadyAppOverrides(initialLocation: initialLocation),
    viewport: viewport,
  );
}

Future<void> loginAs(PatrolIntegrationTester $, DemoAccount account) async {
  expect(find.byType(LoginPage), findsOneWidget);
  await _submitPatrolLogin($, account.email, demoAccountPassword);
  await $.pumpAndSettle(timeout: const Duration(seconds: 45));
  expect(find.byType(LoginPage), findsNothing);
  expect(find.byType(HomePage), findsWidgets);
}

Future<void> loginAndOpenRoute(
  PatrolIntegrationTester $,
  DemoAccount account,
  String path, {
  Size viewport = patrolDesktopViewport,
}) async {
  await pumpPatrolE2eApp($, viewport: viewport);
  await loginAs($, account);
  if (path != AppRoutes.home.path) {
    await goToModule($, path);
  }
}

Future<void> logoutPatrol(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byTooltip('Account'));
  await $.pumpAndSettle();
  await $.tester.tap(find.text('Logout'));
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
  expect(find.byType(LoginPage), findsOneWidget);
}

Future<void> _submitPatrolLogin(
  PatrolIntegrationTester $,
  String email,
  String password,
) async {
  await $.tester.enterText(find.byType(EditableText).at(0), email);
  await $.tester.enterText(find.byType(EditableText).at(1), password);
  await $.tester.tap(
    find.byWidgetPredicate(
      (Widget widget) => widget is AppButton && widget.label == 'Sign in',
    ),
  );
  await $.pump();
}

Future<void> goToModule(
  PatrolIntegrationTester $,
  String path, {
  Duration settleTimeout = const Duration(seconds: 20),
}) async {
  final BuildContext context = $.tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await $.pumpAndSettle(timeout: settleTimeout);
}

Future<void> openFirstDataRow(PatrolIntegrationTester $) async {
  final Finder rows = find.byType(InkWell);
  if (rows.evaluate().isEmpty) {
    return;
  }

  await $.tester.tap(rows.first);
  await $.pumpAndSettle();
}

Future<void> expectAnyVisible(
  PatrolIntegrationTester $,
  Iterable<String> labels, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final Set<String> remaining = labels.toSet();
  final Stopwatch stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    remaining.removeWhere(
      (String label) => find.text(label).evaluate().isNotEmpty,
    );
    if (remaining.isEmpty) {
      return;
    }
    await $.pump(const Duration(milliseconds: 200));
  }

  expect(remaining, isEmpty, reason: 'Expected one of: ${labels.join(', ')}');
}

AppLocalizations patrolL10n(PatrolIntegrationTester $) {
  return $.tester.element(find.byType(Scaffold).first).l10n;
}

DemoAccount demoAccountForRoute(AppRouteData route) {
  return switch (route.name) {
    'patients' => DemoAccount.reception,
    'opd' => DemoAccount.doctor,
    'clinical' => DemoAccount.doctor,
    'lab' => DemoAccount.lab,
    'radiology' => DemoAccount.radiology,
    'pharmacy' => DemoAccount.pharmacy,
    'billing' => DemoAccount.billing,
    'claims' => DemoAccount.billing,
    'hr' => DemoAccount.hr,
    'biomedical' => DemoAccount.biomed,
    'housekeeping' => DemoAccount.housekeeping,
    'operations' => DemoAccount.operations,
    'emergency' => DemoAccount.ambulance,
    'nursing' => DemoAccount.nurse,
    _ => DemoAccount.tenantAdmin,
  };
}

/// Workspace routes with stable shell labels for Patrol navigation checks.
final List<PatrolWorkspaceTarget> patrolWorkspaceTargets =
    <PatrolWorkspaceTarget>[
      const PatrolWorkspaceTarget(
        route: AppRoutes.claims,
        labels: <String>['Insurance and claims', 'Loading claims'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.subscriptions,
        labels: <String>['Subscriptions', 'Loading subscriptions'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.emergency,
        labels: <String>['Emergency board', 'Loading emergency board'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.ipd,
        labels: <String>['Inpatient workspace', 'Loading inpatient workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.roomsBeds,
        labels: <String>['Rooms and beds', 'Loading rooms and beds'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.icu,
        labels: <String>['ICU board', 'Loading ICU board'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.nursing,
        labels: <String>['Nursing', 'Loading nursing workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.physiotherapy,
        labels: <String>['Physiotherapy', 'Loading physiotherapy workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.lab,
        labels: <String>['Laboratory', 'Loading laboratory'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.radiology,
        labels: <String>['Radiology', 'Loading radiology workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.pharmacy,
        labels: <String>['Pharmacy', 'Loading pharmacy workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.operations,
        labels: <String>['Operations', 'Loading operations'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.housekeeping,
        labels: <String>['Housekeeping', 'Loading housekeeping'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.hr,
        labels: <String>['Human resources', 'Loading HR workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.biomedical,
        labels: <String>['Biomedical', 'Loading biomedical'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.communications,
        labels: <String>['Communications', 'Loading communications'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.integrations,
        labels: <String>['Integrations', 'Loading integrations'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.discharge,
        labels: <String>['Discharge workspace', 'Loading discharge workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.mortuary,
        labels: <String>['Mortuary', 'Loading mortuary workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.theater,
        labels: <String>['Theater', 'Loading theater'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.reports,
        labels: <String>['Reports and audit', 'Loading reports workspace'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.tenantFacilitySetup,
        labels: <String>['Tenant and facility setup', 'Loading setup'],
      ),
      const PatrolWorkspaceTarget(
        route: AppRoutes.accessAdmin,
        labels: <String>['Users and access', 'Loading access workspace'],
      ),
    ];

final class PatrolWorkspaceTarget {
  const PatrolWorkspaceTarget({required this.route, required this.labels});

  final AppRouteData route;
  final List<String> labels;
}
