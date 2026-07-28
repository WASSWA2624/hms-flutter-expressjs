import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_access.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';

const List<AppModuleEntitlement> _activeModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'inpatient-bed-management',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'radiology-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'biomedical-engineering-suite',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'subscription-controls', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'integrations-core', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required List<String> roles,
  required Iterable<AppPermission> permissions,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: roles,
      ),
      permissions: permissions,
      moduleEntitlements: _activeModules,
      isAuthorizationHydrated: true,
    ),
  );
}

HomeDashboard _dashboardForProfile(
  HomeDashboardProfile profile, {
  HomeDashboardTrend? trend,
  HomeDashboardDistribution? distribution,
  List<String>? shortcutIds,
  List<String>? quickActionIds,
}) {
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: HomeDashboardContext(roleValue: profile.role.value),
    statusCards: profile.fallbackStatusCards(),
    trend:
        trend ??
        const HomeDashboardTrend(
          title: 'Trend',
          subtitle: '',
          points: <HomeTrendPoint>[
            HomeTrendPoint(id: 'd1', date: null, value: 3),
          ],
        ),
    distribution:
        distribution ??
        const HomeDashboardDistribution(
          title: 'Distribution',
          subtitle: '',
          total: 3,
          segments: <HomeDistributionSegment>[
            HomeDistributionSegment(id: 'a', label: 'A', value: 3),
          ],
        ),
    quickActionIds: quickActionIds ?? profile.quickActionIds,
    shortcutIds: shortcutIds ?? profile.shortcutIds,
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

Set<String> _cardIds(HomeDashboard dashboard) {
  return dashboard.statusCards.map((HomeStatusCard card) => card.id).toSet();
}

void main() {
  group('filterHomeDashboardForAccess', () {
    test('clinical:read + lab:read keeps clinical/lab cards only', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['CUSTOM_CLINICIAN'],
        permissions: <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.labRead,
        ],
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final HomeDashboard filtered = filterHomeDashboardForAccess(
        _dashboardForProfile(profile),
        policy,
      );
      final Set<String> ids = _cardIds(filtered);

      expect(ids, containsAll(<String>['assigned', 'in_progress', 'completed']));
      expect(ids, contains('results_pending_review'));
      expect(ids, isNot(contains('billing_exceptions')));
      expect(ids, isNot(contains('pending_dispense')));
      expect(ids, isNot(contains('radiology_pending')));
      expect(filtered.trend.hasData, isFalse);
      expect(filtered.distribution.hasData, isFalse);
    });

    test(
      'billing:read without financial:approve keeps revenue, hides approvals',
      () {
        final AppAccessPolicy policy = _policy(
          roles: <String>['BILLING'],
          permissions: <AppPermission>[AppPermissions.billingRead],
        );
        final HomeDashboardProfile profile = homeProfileForRole(AppRole.billing);
        final HomeDashboard filtered = filterHomeDashboardForAccess(
          _dashboardForProfile(profile),
          policy,
        );
        final Set<String> ids = _cardIds(filtered);

        expect(
          ids,
          containsAll(<String>[
            'collections_today',
            'overdue_balance_amount',
            'open_balances',
          ]),
        );
        expect(ids, isNot(contains('pending_approvals')));
        expect(ids, isNot(contains('refunds_today')));
      },
    );

    test(
      'facility-admin pack minus billing:read hides revenue only',
      () {
        final AppAccessPolicy policy = _policy(
          roles: <String>['FACILITY_ADMIN'],
          permissions: <AppPermission>[
            AppPermissions.facilityAdmin,
            AppPermissions.patientRead,
            AppPermissions.operationsRead,
            AppPermissions.emergencyRead,
            AppPermissions.labRead,
            AppPermissions.pharmacyRead,
            AppPermissions.hrRead,
            AppPermissions.biomedRead,
            AppPermissions.reportsRead,
            // intentionally no billing:read
          ],
        );
        final HomeDashboardProfile profile = homeProfileForRole(
          AppRole.facilityAdmin,
        );
        final HomeDashboard filtered = filterHomeDashboardForAccess(
          _dashboardForProfile(profile),
          policy,
        );
        final Set<String> ids = _cardIds(filtered);

        expect(
          ids,
          containsAll(<String>[
            'patient_flow_today',
            'appointments_today',
            'active_admissions',
            'bed_occupancy',
            'operational_blockers',
          ]),
        );
        expect(ids, isNot(contains('billing_exceptions')));
      },
    );

    test('clinical + reports:read surfaces trend/distribution', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['DOCTOR'],
        permissions: <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.labRead,
          AppPermissions.reportsRead,
        ],
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final HomeDashboard filtered = filterHomeDashboardForAccess(
        _dashboardForProfile(profile),
        policy,
      );

      expect(filtered.trend.hasData, isTrue);
      expect(filtered.distribution.hasData, isTrue);
      expect(
        filtered.trend.requiredPermissions,
        contains(AppPermissions.reportsRead),
      );
      expect(_cardIds(filtered), contains('assigned'));
    });

    test('actions and shortcuts omit unauthorized ids', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['CUSTOM'],
        permissions: <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.labRead,
        ],
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final List<HomeActionDefinition> actions = homeVisibleActions(
        profile.quickActionIds,
        policy,
      );
      final List<HomeShortcutDefinition> shortcuts = homeVisibleShortcuts(
        profile.shortcutIds,
        policy,
      );

      expect(
        actions.map((HomeActionDefinition action) => action.id),
        contains('continue_consultation'),
      );
      expect(
        actions.map((HomeActionDefinition action) => action.id),
        isNot(contains('create_invoice')),
      );
      expect(
        shortcuts.map((HomeShortcutDefinition shortcut) => shortcut.id),
        containsAll(<String>['clinical', 'lab']),
      );
      expect(
        shortcuts.map((HomeShortcutDefinition shortcut) => shortcut.id),
        isNot(contains('pharmacy')),
      );
      expect(
        shortcuts.map((HomeShortcutDefinition shortcut) => shortcut.id),
        isNot(contains('radiology')),
      );
    });

    test('API required_permissions preferred over catalog', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['CUSTOM'],
        permissions: <AppPermission>[AppPermissions.billingRead],
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final HomeDashboard dashboard = HomeDashboard(
        state: HomeDashboardLoadState.ready,
        profile: profile,
        context: const HomeDashboardContext(),
        statusCards: const <HomeStatusCard>[
          HomeStatusCard(
            id: 'assigned',
            label: 'Revenue override',
            value: 10,
            requiredPermissions: <AppPermission>[AppPermissions.billingRead],
          ),
          HomeStatusCard(
            id: 'in_progress',
            label: 'Clinical',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          ),
        ],
        trend: HomeDashboardTrend.empty,
        distribution: HomeDashboardDistribution.empty,
        quickActionIds: const <String>[],
        shortcutIds: const <String>[],
        queuePreview: const <HomeQueueItem>[],
        alerts: const <HomeAlertItem>[],
        activity: const <HomeActivityItem>[],
        tenantOptions: const <HomeTenantOption>[],
      );

      final HomeDashboard filtered = filterHomeDashboardForAccess(
        dashboard,
        policy,
      );
      expect(_cardIds(filtered), <String>{'assigned'});
    });
  });
}
