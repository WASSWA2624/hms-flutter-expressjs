import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

/// Resolves a tappable destination for a home KPI card when the profile defines one.
HomeMetricNavigation? homeMetricNavigation({
  required HomeDashboardProfile profile,
  required HomeStatusCard card,
  required AppAccessPolicy policy,
}) {
  final HomeMetricRouteTarget? target = profile.metricRouteTargets[card.id];
  if (target == null) {
    return null;
  }
  if (!policy.hasAllActiveModules(<String>['hr'])) {
    return null;
  }
  if (!policy.grantsAny(<AppPermission>[
    AppPermissions.hrRead,
    AppPermissions.rosterRead,
  ])) {
    return null;
  }

  return HomeMetricNavigation(
    route: AppRoutes.hr,
    queryParameters: target.queryParameters,
  );
}

final class HomeMetricNavigation {
  const HomeMetricNavigation({
    required this.route,
    this.queryParameters = const <String, String>{},
  });

  final AppRouteData route;
  final Map<String, String> queryParameters;
}

/// Maps HR workspace queue row targets to `/hr` deep-link query parameters.
Map<String, String> homeHrQueryForTarget(HomeRouteTarget? target) {
  if (target == null) {
    return const <String, String>{};
  }
  if (target.moduleSlug.toLowerCase() != 'hr') {
    return const <String, String>{};
  }

  final String? queue = switch ((target.resource ?? '').toLowerCase()) {
    'staff-leaves' => 'LEAVE_REQUESTS',
    'shift-swap-requests' => 'SWAP_REQUESTS',
    'nurse-rosters' => 'ROSTER_DRAFTS',
    'shifts' => 'UNASSIGNED_SHIFTS',
    'payroll-runs' => 'PAYROLL_DRAFTS',
    _ => null,
  };
  if (queue == null) {
    return const <String, String>{};
  }
  return <String, String>{'queue': queue};
}
