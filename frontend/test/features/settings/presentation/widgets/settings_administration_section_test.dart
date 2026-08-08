import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_administration_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  test(
    'feature helpers match Administration matrix ∩ / ∪ and catalog navigate',
    () {
      expect(
        settingsAdministrationReadRequirement.allPermissions,
        <AppPermission>[AppPermissions.profileRead],
      );
      expect(
        settingsAdministrationReadRequirement.anyPermissions,
        settingsAdminAnyPermissions,
      );
      expect(
        settingsAdministrationCreateRequirement.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        settingsAdministrationUpdateRequirement.allPermissions,
        <AppPermission>[AppPermissions.profileUpdate],
      );
      expect(
        settingsAdministrationDeleteRequirement.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      // Navigate destinations keep RouteAccessCatalog sources (documented
      // mapping vs tab admin ∪).
      expect(
        settingsAdministrationTenantFacilityNavigateRequirement,
        same(RouteAccessCatalog.setupEntry),
      );
      expect(
        settingsAdministrationSubscriptionsNavigateRequirement,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        settingsAdministrationAccessAdminNavigateRequirement,
        same(RouteAccessCatalog.accessAdminEntry),
      );
      expect(
        SettingsAdministrationAtomPermissions.tab,
        same(settingsAdministrationReadRequirement),
      );
    },
  );

  testWidgets(
    'administration strip absent without profile:read (intersection denial)',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
          AppPermissions.subscriptionsRead,
          AppPermissions.accessAdminRead,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: false,
      );

      expect(find.text('Administration boundaries'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
      expect(find.text('Users and access'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.text('Access denied'), findsNothing);
    },
  );

  testWidgets(
    'administration strip absent with profile:read but no admin ∪ key',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.setupRead,
          AppPermissions.subscriptionsRead,
          AppPermissions.accessAdminRead,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: false,
      );

      expect(find.text('Administration boundaries'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
    },
  );

  testWidgets(
    'facility:admin ∪ allowance mounts navigate atoms without workspace',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
          AppPermissions.subscriptionsRead,
          AppPermissions.accessAdminRead,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: false,
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsOneWidget);
      expect(find.text('Subscription plans'), findsNothing);
      expect(find.text('Users and access'), findsOneWidget);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'tenant:admin ∪ alone allows section when destination rights present',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
          AppPermissions.setupRead,
          AppPermissions.accessAdminRead,
        ],
        settingsWorkspaceVisible: false,
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsOneWidget);
      expect(find.text('Users and access'), findsOneWidget);
      expect(find.text('Subscription plans'), findsNothing);
    },
  );

  testWidgets(
    'subscriptions tile stripped without platform admin',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.subscriptionsRead,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: true,
      );

      expect(find.text('Administration boundaries'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing facility strips Tenant and facility setup tile',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
          AppPermissions.accessAdminRead,
        ],
        settingsWorkspaceVisible: false,
        facilityId: null,
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Users and access'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing tenant strips Users and access tile',
    (WidgetTester tester) async {
      // Facility present so setup remains; tenant absent strips access admin.
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
          AppPermissions.setupRead,
          AppPermissions.accessAdminRead,
        ],
        settingsWorkspaceVisible: false,
        tenantId: null,
        facilityId: 'facility-1',
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsOneWidget);
      expect(find.text('Users and access'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized navigate flow opens Subscription plans destination',
    (WidgetTester tester) async {
      await _pumpSectionWithRouter(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.systemAdmin,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: true,
      );

      expect(find.text('Subscription plans'), findsOneWidget);
      await tester.tap(find.text('Subscription plans'));
      await tester.pumpAndSettle();
      expect(find.text('Subscriptions destination'), findsOneWidget);
    },
  );

  testWidgets(
    'navigate-only tab has no mutation chrome (post-mutation sync N/A)',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
          AppPermissions.subscriptionsRead,
          AppPermissions.accessAdminRead,
          AppPermissions.profileUpdate,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: false,
      );

      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Reset'), findsNothing);
      expect(find.byType(Form), findsNothing);
    },
  );

  testWidgets(
    'workspace mode keeps Subscription plans only under Administration',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.systemAdmin,
          AppPermissions.subscriptionsRead,
          AppPermissions.setupRead,
          AppPermissions.accessAdminRead,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: true,
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Subscription plans'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Users and access'), findsNothing);
    },
  );

  testWidgets(
    'no nested cross-module write chrome on administration tab',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
          AppPermissions.subscriptionsRead,
          AppPermissions.accessAdminRead,
          AppPermissions.profileUpdate,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: false,
      );

      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.text('Save'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'mobile light theme shows authorized administration navigate atoms',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
        ],
        settingsWorkspaceVisible: false,
        size: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsOneWidget);
      expect(find.text('Users and access'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
    },
  );

  testWidgets(
    'desktop dark theme shows authorized administration navigate atoms',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
          AppPermissions.subscriptionsRead,
          AppPermissions.accessAdminRead,
        ],
        modules: _subscriptionModule,
        settingsWorkspaceVisible: false,
        size: const Size(1280, 1200),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Subscription plans'), findsNothing);
      expect(find.text('Users and access'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsNothing);
    },
  );

  testWidgets(
    'SettingsPage strip hides Administration without admin ∪ (integration)',
    (WidgetTester tester) async {
      await _pumpSettingsPage(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        roles: const <String>['doctor'],
        tab: 'preferences',
      );

      expect(find.text('Preferences'), findsWidgets);
      expect(find.text('Administration boundaries'), findsNothing);
    },
  );

  testWidgets(
    'SettingsPage strip shows Administration for elevated admin (integration)',
    (WidgetTester tester) async {
      await _pumpSettingsPage(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.systemAdmin,
          AppPermissions.subscriptionsRead,
        ],
        modules: _subscriptionModule,
        roles: const <String>['SUPER_ADMIN'],
        tab: 'administration',
        size: const Size(1600, 1400),
      );

      expect(find.text('Administration boundaries'), findsWidgets);
      expect(find.text('Subscription plans'), findsWidgets);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Users and access'), findsNothing);
    },
  );

  test(
    'settingsAdministrationSectionVisible requires read ∩ and a destination',
    () {
      final AppAccessPolicy denied = AppAccessPolicy.fromSession(
        _session(
          permissions: <AppPermission>[AppPermissions.profileRead],
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
      ).copyWithPermissions(<AppPermission>[AppPermissions.profileRead]);

      expect(
        settingsAdministrationSectionVisible(
          denied,
          settingsWorkspaceVisible: false,
        ),
        isFalse,
      );

      final AuthSession allowedSession = _session(
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
        ],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      );
      final AppAccessPolicy allowed = AppAccessPolicy.fromSession(
        allowedSession,
      ).copyWithPermissions(<AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.facilityAdmin,
        AppPermissions.setupRead,
      ]);

      expect(
        settingsAdministrationSectionVisible(
          allowed,
          settingsWorkspaceVisible: false,
        ),
        isTrue,
      );
    },
  );
}

const List<AppModuleEntitlement> _subscriptionModule = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'subscription-controls', licenseStatus: 'ACTIVE'),
];

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
  required bool settingsWorkspaceVisible,
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
  List<String> roles = const <String>['doctor'],
  Size size = const Size(900, 1000),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final AuthSession session = _session(
    permissions: permissions,
    modules: modules,
    roles: roles,
    tenantId: tenantId,
    facilityId: facilityId,
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SettingsAdministrationSection(
              settingsWorkspaceVisible: settingsWorkspaceVisible,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSectionWithRouter(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
  required bool settingsWorkspaceVisible,
  Size size = const Size(900, 1000),
}) async {
  final AuthSession session = _session(
    permissions: permissions,
    modules: modules,
    tenantId: 'tenant-1',
    facilityId: 'facility-1',
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.settings.location(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.settings.path,
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SettingsAdministrationSection(
                settingsWorkspaceVisible: settingsWorkspaceVisible,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.subscriptions.path,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Subscriptions destination'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
  List<String> roles = const <String>['doctor'],
  String tab = 'administration',
  Size size = const Size(900, 1000),
}) async {
  final bool elevated = roles.contains('SUPER_ADMIN');
  final AuthSession session = _session(
    permissions: permissions,
    modules: modules,
    roles: roles,
    tenantId: elevated ? null : 'tenant-1',
    facilityId: elevated ? null : 'facility-1',
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        settingsWorkspaceRepositoryProvider.overrideWithValue(
          _FakeSettingsWorkspaceRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsPage(
              initialQuery: SettingsPageQuery(tab: tab),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _session({
  required List<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
  List<String> roles = const <String>['doctor'],
  String? tenantId,
  String? facilityId,
}) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    isAuthorizationHydrated: true,
    moduleEntitlements: modules,
    user: AuthUserProfile(
      id: 'user-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Demo',
      tenantId: tenantId,
      facilityId: facilityId,
      roles: roles,
    ),
  );
}

final class _FakeSettingsWorkspaceRepository
    implements SettingsWorkspaceRepository {
  @override
  Future<Result<SettingsWorkspace>> getWorkspace(
    SettingsWorkspaceQuery query,
  ) async {
    return Result<SettingsWorkspace>.success(
      SettingsWorkspace(
        status: SettingsWorkspaceStatus.ready,
        generatedAt: DateTime.utc(2026, 5, 22, 9),
        context: const SettingsWorkspaceContext(
          state: SettingsWorkspaceStatus.ready,
          tenantName: 'Acme Health',
          facilityName: 'Central Hospital',
          roleKeys: <String>['SUPER_ADMIN'],
        ),
        summaryCards: const <SettingsSummaryCard>[],
        checklist: const SettingsChecklist(
          completedCount: 0,
          totalCount: 0,
          items: <SettingsChecklistItem>[],
        ),
        quickActions: const <SettingsQuickAction>[],
        moduleGroups: const <SettingsModuleGroup>[],
        referenceData: const SettingsReferenceData(
          tenants: <SettingsReferenceOption>[],
          facilities: <SettingsReferenceOption>[],
        ),
        stats: const SettingsWorkspaceStats(
          totalModules: 0,
          configuredModules: 0,
          attentionModules: 0,
          totalRecords: 0,
        ),
        permissions: const SettingsWorkspacePermissions(canWrite: true),
      ),
    );
  }

  @override
  Future<Result<SettingsReferenceData>> getReferenceData(
    SettingsWorkspaceQuery query,
  ) async {
    return const Result<SettingsReferenceData>.success(
      SettingsReferenceData(
        tenants: <SettingsReferenceOption>[],
        facilities: <SettingsReferenceOption>[],
      ),
    );
  }
}
