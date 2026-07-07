import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/app.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:patrol/patrol.dart';

import '../../test/helpers/test_harness.dart';

export '../../test/helpers/test_harness.dart';

/// Mobile viewport used for responsive Patrol smoke coverage.
const Size patrolMobileViewport = Size(390, 844);

/// Desktop viewport used for responsive Patrol smoke coverage.
const Size patrolDesktopViewport = Size(1440, 900);

const String patrolTestTenantId = 'tenant-patrol-test';
const String patrolTestFacilityId = 'facility-patrol-test';

/// Module entitlements required to reach gated workspace routes in Patrol tests.
const List<AppModuleEntitlement> patrolModuleEntitlements = <AppModuleEntitlement>[
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

List<Object?> patrolBaseOverrides() {
  return <Object?>[
    appConfigProvider.overrideWithValue(patrolTestAppConfig()),
  ];
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
  Size? viewport,
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
  Size viewport = patrolDesktopViewport,
}) async {
  setTestViewport($.tester, viewport);

  await $.pumpWidget(
    ProviderScope(
      overrides: <Object?>[
        ...patrolBaseOverrides(),
        ...overrides,
      ].cast(),
      child: const HosspiHmsApp(),
    ),
  );
  await $.pumpAndSettle(timeout: const Duration(seconds: 30));
}

Future<void> pumpPatrolAuthenticatedApp(
  PatrolIntegrationTester $, {
  String? initialLocation,
  Size viewport = patrolDesktopViewport,
}) {
  return pumpPatrolApp(
    $,
    overrides: patrolAuthenticatedOverrides(initialLocation: initialLocation),
    viewport: viewport,
  );
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
    remaining.removeWhere((String label) => find.text(label).evaluate().isNotEmpty);
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
        labels: <String>[
          'Physiotherapy',
          'Loading physiotherapy workspace',
        ],
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
        labels: <String>[
          'Discharge workspace',
          'Loading discharge workspace',
        ],
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
