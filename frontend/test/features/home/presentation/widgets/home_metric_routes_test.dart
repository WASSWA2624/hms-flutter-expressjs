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
    test('HR profile exposes navigation for leave and shift cards', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.hr);
      final AppAccessPolicy policy = _policyForRoles(<String>['HR']);

      final HomeMetricNavigation? leaveNavigation = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_leaves',
          label: 'Pending leave approvals',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? shiftNavigation = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'unassigned_shifts',
          label: 'Unassigned shifts',
          value: 1,
        ),
        policy: policy,
      );

      expect(leaveNavigation?.route, AppRoutes.hr);
      expect(leaveNavigation?.queryParameters['queue'], 'LEAVE_REQUESTS');
      expect(shiftNavigation?.queryParameters['queue'], 'UNASSIGNED_SHIFTS');
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

    test('doctor profile cards stay non-navigable', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = _policyForRoles(<String>['DOCTOR']);

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned consultations',
            value: 3,
          ),
          policy: policy,
        ),
        isNull,
      );
    });
  });
}
