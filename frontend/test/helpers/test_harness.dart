import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/app/app.dart';
import 'package:hosspi_hms/app/router/app_router.dart';
import 'package:hosspi_hms/app/startup/app_startup_state.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_readiness.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

const Locale testLocale = Locale('en');

AppConfig testAppConfig() {
  return AppConfig.fromValues(
    environmentName: 'development',
    apiBaseUrl: 'http://localhost:3000',
    logLevelName: 'error',
  );
}

/// Module entitlements for integration deep-link navigation tests.
const List<AppModuleEntitlement> integrationModuleEntitlements =
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

SessionState integrationAuthenticatedSessionState() {
  return SessionState.authenticated(
    session: AuthSession(
      tokens: SessionTokens(accessToken: 'integration-test-access-token'),
      subject: 'tenant.admin@hosspi.com',
      moduleEntitlements: integrationModuleEntitlements,
      user: const AuthUserProfile(
        id: 'user-integration-123',
        displayId: 'USR-INT',
        email: 'tenant.admin@hosspi.com',
        firstName: 'Taylor',
        lastName: 'Demo',
        tenantId: 'tenant-integration',
        tenantName: 'IHK Hospital',
        facilityId: 'facility-integration',
        facilityName: 'IHK Hospital',
        facilityType: 'hospital',
        positionTitle: 'tenant_admin',
        staffNumber: 'STF-INT',
        staffPosition: 'administrator',
        roles: <String>['tenant_admin'],
      ),
    ),
  );
}

List<Object?> testReadyAppOverrides({
  ThemeMode themeMode = ThemeMode.light,
  Locale? locale = testLocale,
  StorageReadiness storageReadiness = const StorageReadiness.ready(),
  SessionState sessionState = const SessionState.ready(),
  String? initialLocation,
  bool mockHomeRepository = false,
}) {
  return <Object?>[
    appConfigProvider.overrideWithValue(testAppConfig()),
    if (mockHomeRepository)
      homeRepositoryProvider.overrideWithValue(_testHomeRepository),
    appStartupStateProvider.overrideWithValue(
      AppStartupState(
        themeMode: themeMode,
        locale: locale,
        accessibility: const AppAccessibilityPreferences(),
        storageReadiness: storageReadiness,
        sessionReadiness: sessionState,
      ),
    ),
    initialSessionStateProvider.overrideWithValue(sessionState),
    if (initialLocation != null)
      appInitialLocationProvider.overrideWithValue(initialLocation),
  ];
}

ProviderContainer createTestContainer({
  List<Object?> overrides = const <Object?>[],
}) {
  final container = ProviderContainer(
    overrides: <Object?>[
      appConfigProvider.overrideWithValue(testAppConfig()),
      ...overrides,
    ].cast(),
  );
  addTearDown(container.dispose);

  return container;
}

Future<void> pumpHosspiHmsApp(
  WidgetTester tester, {
  List<Object?> overrides = const <Object?>[],
  Size? size,
}) async {
  setTestViewport(tester, size);

  await tester.pumpWidget(
    ProviderScope(overrides: overrides.cast(), child: const HosspiHmsApp()),
  );
}

Future<void> pumpLocalizedWidget(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
  EdgeInsetsGeometry padding = const EdgeInsets.all(24),
}) async {
  setTestViewport(tester, size);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Padding(padding: padding, child: child),
      ),
    ),
  );
}

void setTestViewport(WidgetTester tester, Size? size) {
  if (size == null) {
    return;
  }

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

HomeDashboard testHomeDashboardFixture() {
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

final HomeRepository _testHomeRepository = _TestHomeRepository();

final class _TestHomeRepository implements HomeRepository {
  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    return Result<HomeDashboard>.success(testHomeDashboardFixture());
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}
