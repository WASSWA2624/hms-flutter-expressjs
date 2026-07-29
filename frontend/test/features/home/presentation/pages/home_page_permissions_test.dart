import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/home_access.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/app_quick_actions.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_charts_row.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_metric_strip.dart';
import 'package:hosspi_hms/shared/dashboard/role_dashboard_scaffold.dart';

const List<AppModuleEntitlement> _fullModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'radiology-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'emergency-trauma', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage UI permissions', () {
    testWidgets('missing profile:read hides entire home surface', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        permissions: <AppPermission>[AppPermissions.clinicalRead],
        dashboard: _doctorDashboard(),
      );

      expect(find.byType(RoleDashboardScaffold), findsNothing);
      expect(find.byType(DashboardMetricStrip), findsNothing);
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('Assigned today'), findsNothing);
      expect(find.text('Preparing dashboard'), findsNothing);
    });

    testWidgets(
      'profile:read + clinical/lab shows authorized atoms; billing write absent',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.labRead,
          ],
          dashboard: _doctorDashboard(),
        );

        expect(find.byType(RoleDashboardScaffold), findsOneWidget);
        expect(find.text('Assigned today'), findsOneWidget);
        expect(find.text('Results to review'), findsOneWidget);
        expect(find.text('Collections today'), findsNothing);
        expect(find.text('Pending approvals'), findsNothing);
        expect(find.text('Continue consultation'), findsOneWidget);
        expect(find.text('Create invoice'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expect(find.textContaining('No access'), findsNothing);
      },
    );

    testWidgets(
      '∩ denial: billing:read without financial:approve hides pending approvals',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.billingRead,
          ],
          dashboard: _billingDashboard(),
        );

        expect(find.text('Collections today'), findsOneWidget);
        expect(find.text('Pending approvals'), findsNothing);
        expect(find.text('Refunds today'), findsNothing);
      },
    );

    testWidgets(
      '∪ across grants: clinical + billing surfaces union of atoms',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
          ],
          dashboard: _mixedClinicalBillingDashboard(),
          roles: <String>['CUSTOM_MIXED'],
        );

        expect(find.text('Assigned today'), findsOneWidget);
        expect(find.text('Collections today'), findsOneWidget);
        expect(find.text('Pending approvals'), findsNothing);
        expect(find.text('Continue consultation'), findsNothing);
      },
    );

    testWidgets(
      'subscription strips billing KPI when plan module inactive',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
          ],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          dashboard: _mixedClinicalBillingDashboard(),
          roles: <String>['CUSTOM_MIXED'],
        );

        expect(find.text('Assigned today'), findsOneWidget);
        expect(find.text('Collections today'), findsNothing);
      },
    );

    testWidgets('nested cross-module pharmacy shortcut absent without rights', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.labRead,
        ],
        dashboard: _doctorDashboard(),
      );

      // Shortcuts render as labels in priority panel when entitled.
      expect(find.text('Pharmacy'), findsNothing);
      expect(find.text('Radiology'), findsNothing);
    });

    testWidgets('error/retry remains available for authorized users', (
      WidgetTester tester,
    ) async {
      final _FakeHomeRepository repository = _FakeHomeRepository(
        const Result<HomeDashboard>.failure(AppFailure.network()),
      );

      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.clinicalRead,
        ],
        repository: repository,
      );

      expect(find.text('Try again'), findsOneWidget);

      repository.nextResult = Result<HomeDashboard>.success(_doctorDashboard());
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Assigned today'), findsOneWidget);
      expect(repository.callCount, greaterThanOrEqualTo(2));
    });

    testWidgets('mobile viewport keeps authorized quick actions visible', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.labRead,
        ],
        dashboard: _doctorDashboard(),
        size: const Size(390, 844),
      );

      expect(find.byType(AppQuickActions), findsOneWidget);
      expect(find.text('Continue consultation'), findsOneWidget);
      expect(find.text('Assigned today'), findsOneWidget);
    });

    testWidgets('desktop viewport + dark theme keeps authorized metrics', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.clinicalRead,
          AppPermissions.labRead,
        ],
        dashboard: _doctorDashboard(),
        size: const Size(1280, 900),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Assigned today'), findsOneWidget);
      expect(find.text('Results to review'), findsOneWidget);
      expect(find.text('Collections today'), findsNothing);
    });

    testWidgets('light theme keeps authorized metrics and hides write actions', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.clinicalRead,
          AppPermissions.labRead,
        ],
        dashboard: _doctorDashboard(),
        size: const Size(1280, 900),
        themeMode: ThemeMode.light,
      );

      expect(find.text('Assigned today'), findsOneWidget);
      expect(find.text('Continue consultation'), findsNothing);
      expect(find.text('Order lab'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'charts absent without reports:read even when trend payload present',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.clinicalRead,
            AppPermissions.labRead,
          ],
          dashboard: _doctorDashboard(),
        );

        expect(find.byType(DashboardChartsRow), findsNothing);
        expect(find.text('Trend'), findsNothing);
      },
    );

    testWidgets(
      'profile:read only collapses KPI/actions; empty queue copy remains',
      (WidgetTester tester) async {
        await _pumpHome(
          tester,
          permissions: <AppPermission>[AppPermissions.profileRead],
          dashboard: _doctorDashboard(),
        );

        expect(find.byType(RoleDashboardScaffold), findsOneWidget);
        expect(find.text('Assigned today'), findsNothing);
        expect(find.text('Results to review'), findsNothing);
        expect(find.text('Continue consultation'), findsNothing);
        expect(find.text('No assigned clinical work right now.'), findsOneWidget);
        expect(find.textContaining('No access'), findsNothing);
      },
    );

    testWidgets('loading state remains observable for authorized users', (
      WidgetTester tester,
    ) async {
      final _FakeHomeRepository repository = _FakeHomeRepository(
        Result<HomeDashboard>.success(_doctorDashboard()),
        delay: const Duration(milliseconds: 200),
      );

      await _pumpHome(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.clinicalRead,
        ],
        repository: repository,
        settle: false,
      );

      expect(find.text('Preparing dashboard'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Assigned today'), findsOneWidget);
    });

    testWidgets(
      'post-mutation sync reloads dashboard and keeps permission filter',
      (WidgetTester tester) async {
        final _FakeHomeRepository repository = _FakeHomeRepository(
          Result<HomeDashboard>.success(_doctorDashboard()),
        );

        final ProviderContainer container = await _pumpHome(
          tester,
          permissions: <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.clinicalRead,
            AppPermissions.labRead,
          ],
          repository: repository,
        );

        expect(find.text('Assigned today'), findsOneWidget);
        expect(repository.callCount, 1);

        // Mirrors [homeOnDashboardMutationSuccess] / [homeRefreshDashboard].
        container.invalidate(
          homeControllerProvider(HomeDashboardRequest.empty),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(repository.callCount, greaterThanOrEqualTo(2));
        expect(find.text('Assigned today'), findsOneWidget);
        expect(find.text('Collections today'), findsNothing);
        expect(find.textContaining('No access'), findsNothing);
      },
    );

    test('homeTabReadRequirement is the feature *Requirement helper', () {
      expect(
        homeTabReadRequirement.allPermissions,
        <AppPermission>[AppPermissions.profileRead],
      );
      expect(
        homeAtomRequirement(const <AppPermission>[
          AppPermissions.clinicalRead,
        ]).allPermissions,
        contains(AppPermissions.clinicalRead),
      );
      expect(
        homeQueueItemRequirement(id: 'guided_clinical_queue').allPermissions,
        contains(AppPermissions.clinicalRead),
      );
      expect(
        homeAlertRequirement(id: 'guided_critical_labs').allPermissions,
        contains(AppPermissions.labRead),
      );
    });
  });
}

Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  HomeDashboard? dashboard,
  _FakeHomeRepository? repository,
  List<String> roles = const <String>['DOCTOR'],
  List<AppModuleEntitlement> modules = _fullModules,
  Size size = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  final AuthSession session = AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    moduleEntitlements: modules,
    isAuthorizationHydrated: true,
    user: AuthUserProfile(
      id: 'user-1',
      displayId: 'USR-1',
      email: 'doc@example.com',
      firstName: 'Doc',
      lastName: 'Demo',
      tenantId: 'tenant-1',
      tenantName: 'Acme Health',
      facilityId: 'facility-1',
      facilityName: 'Central Hospital',
      roles: roles,
    ),
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(session);

  final _FakeHomeRepository repo =
      repository ??
      _FakeHomeRepository(
        Result<HomeDashboard>.success(dashboard ?? _doctorDashboard()),
      );

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final ProviderContainer container = ProviderContainer(
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
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: HomePage()),
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }
  return container;
}

HomeDashboard _doctorDashboard() {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: profile.fallbackStatusCards(),
    trend: const HomeDashboardTrend(
      title: 'Trend',
      subtitle: '',
      points: <HomeTrendPoint>[HomeTrendPoint(id: 'd1', date: null, value: 2)],
      requiredPermissions: <AppPermission>[AppPermissions.reportsRead],
    ),
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: profile.quickActionIds,
    shortcutIds: profile.shortcutIds,
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

HomeDashboard _billingDashboard() {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.billing);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: const <HomeStatusCard>[
      HomeStatusCard(
        id: 'collections_today',
        label: 'Collections today',
        value: 1200,
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCard(
        id: 'pending_approvals',
        label: 'Pending approvals',
        value: 3,
        requiredPermissions: <AppPermission>[AppPermissions.financialApprove],
      ),
      HomeStatusCard(
        id: 'refunds_today',
        label: 'Refunds today',
        value: 1,
        requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
      ),
    ],
    trend: HomeDashboardTrend.empty,
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: const <String>[],
    shortcutIds: const <String>['billing'],
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

HomeDashboard _mixedClinicalBillingDashboard() {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile.copyWith(
      maxStatusCards: 8,
      statusCards: <HomeStatusCardTemplate>[
        ...profile.statusCards,
        const HomeStatusCardTemplate(
          id: 'collections_today',
          label: 'Collections today',
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        const HomeStatusCardTemplate(
          id: 'pending_approvals',
          label: 'Pending approvals',
          requiredPermissions: <AppPermission>[AppPermissions.financialApprove],
        ),
      ],
    ),
    context: const HomeDashboardContext(roleValue: 'CUSTOM_MIXED'),
    statusCards: const <HomeStatusCard>[
      HomeStatusCard(
        id: 'assigned',
        label: 'Assigned today',
        value: 4,
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCard(
        id: 'collections_today',
        label: 'Collections today',
        value: 900,
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCard(
        id: 'pending_approvals',
        label: 'Pending approvals',
        value: 2,
        requiredPermissions: <AppPermission>[AppPermissions.financialApprove],
      ),
    ],
    trend: HomeDashboardTrend.empty,
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: const <String>['continue_consultation'],
    shortcutIds: const <String>['clinical', 'billing'],
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

final class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.nextResult, {this.delay});

  Result<HomeDashboard> nextResult;
  final Duration? delay;
  int callCount = 0;

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    callCount += 1;
    final Duration? wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
    return nextResult;
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
