import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';

AppAccessPolicy _policyForRoles(List<String> roles) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(roles: roles),
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr'),
      ],
    ),
  );
}

void main() {
  group('home metric routes', () {
    test('HR profile exposes modal actions for leave and shift cards', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.hr);
      final AppAccessPolicy policy = _policyForRoles(<String>['HR']);

      final HomeMetricAction? leaveAction = homeMetricAction(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_leaves',
          label: 'Pending leave approvals',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricAction? shiftAction = homeMetricAction(
        profile: profile,
        card: const HomeStatusCard(
          id: 'unassigned_shifts',
          label: 'Unassigned shifts',
          value: 1,
        ),
        policy: policy,
      );

      expect(leaveAction?.target.kind, HomeMetricActionKind.hrWorkQueue);
      expect(leaveAction?.target.hrQueue, 'LEAVE_REQUESTS');
      expect(shiftAction?.target.hrQueue, 'UNASSIGNED_SHIFTS');
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'pending_leaves',
            label: 'Pending leave approvals',
            value: 2,
          ),
          policy: policy,
        ),
        isNull,
      );
    });

    test('HR queue targets map to workspace deep links', () {
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'hr', resource: 'staff-leaves'),
        ),
        <String, String>{'queue': 'LEAVE_REQUESTS'},
      );
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'hr', resource: 'payroll-runs'),
        ),
        <String, String>{'queue': 'PAYROLL_DRAFTS'},
      );
    });

    test('doctor profile cards navigate to clinical and lab workspaces', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'clinical'),
            AppModuleEntitlement(code: 'lab'),
          ],
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'results_pending_review',
            label: 'Results to review',
            value: 2,
          ),
          policy: policy,
        )?.route,
        AppRoutes.lab,
      );
      expect(
        homeMetricAction(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        ),
        isNull,
      );
    });

    test('pharmacist profile cards navigate to pharmacy workspace', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.pharmacist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['PHARMACIST']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'pharmacy'),
            AppModuleEntitlement(code: 'pharmacy-dispensing'),
          ],
        ),
      );

      final HomeMetricNavigation? pending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_dispense',
          label: 'Pending',
          value: 4,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? lowStock = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'low_stock',
          label: 'Low stock',
          value: 2,
        ),
        policy: policy,
      );

      expect(pending?.route, AppRoutes.pharmacy);
      expect(pending?.queryParameters, <String, String>{'section': 'orders'});
      expect(lowStock?.route, AppRoutes.pharmacy);
      expect(lowStock?.queryParameters, <String, String>{
        'section': 'inventory',
      });
    });

    test('homeHrMetricAccessAllowed gates HR modal actions', () {
      final AppAccessPolicy allowed = _policyForRoles(<String>['HR']);
      final AppAccessPolicy denied = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'hr'),
          ],
        ),
      );

      expect(homeHrMetricAccessAllowed(allowed), isTrue);
      expect(homeHrMetricAccessAllowed(denied), isFalse);
    });
  });
}
