import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';

/// OPD / Emergency workspaces are never reachable for receptionist-focused users.
///
/// Desk data stays on [AppRoutes.reception]. Extra grants such as a stale
/// `opd:read` row must not reopen these menus via the expanded-grant escape.
bool isReceptionistDeniedWorkspaceRoute(AppRouteData route) {
  return route.name == AppRoutes.opd.name ||
      route.name == AppRoutes.emergency.name;
}

/// Rewrites OPD / Emergency deep links to Reception for focused front-desk users.
String receptionistDeskLocationForWorkspace(
  String location, {
  required AppAccessPolicy policy,
}) {
  if (!policy.isReceptionistFocusedShellUser) {
    return location;
  }
  final Uri uri = Uri.parse(location);
  if (uri.path != AppRoutes.opd.path && uri.path != AppRoutes.emergency.path) {
    return location;
  }
  final Map<String, String> query = Map<String, String>.of(uri.queryParameters);
  if (uri.path == AppRoutes.emergency.path) {
    query.putIfAbsent('section', () => 'high-priority');
  } else if (!query.containsKey('section') && !query.containsKey('panel')) {
    query['section'] = query.containsKey('flowId') || query.containsKey('flow_id')
        ? 'active'
        : 'queue';
  }
  return AppRoutes.reception.location(queryParameters: query);
}

bool canAccessShellRoute(AppRouteData route, AppAccessPolicy accessPolicy) {
  final AccessRequirement requirement = route.accessRequirement;
  if (!requirement.isAllowed(accessPolicy)) {
    return false;
  }

  // Custom roles / direct grants only: map permissions to their home workspaces
  // instead of letting broad route any-permission lists leak across modules.
  if (accessPolicy.isPermissionScopedShellUser) {
    return accessPolicy.isShellRouteAllowedByPermissionDomain(
      allPermissions: requirement.allPermissions,
      anyPermissions: requirement.anyPermissions,
      allowedDomains: AppRoutes.permissionScopedDomainsFor(route),
    );
  }

  if (accessPolicy.isReceptionistFocusedShellUser &&
      isReceptionistDeniedWorkspaceRoute(route)) {
    return false;
  }

  final bool unlockedByExpandedGrant = accessPolicy
      .isShellRouteUnlockedByExpandedGrant(
        allPermissions: requirement.allPermissions,
        anyPermissions: requirement.anyPermissions,
      );

  if (accessPolicy.isLabFocusedShellUser &&
      !AppRoutes.isLabFocusedShellRoute(route) &&
      !unlockedByExpandedGrant) {
    return false;
  }
  if (accessPolicy.isPharmacistFocusedShellUser &&
      !AppRoutes.isPharmacistFocusedShellRoute(route) &&
      !unlockedByExpandedGrant) {
    return false;
  }
  if (accessPolicy.isReceptionistFocusedShellUser &&
      !AppRoutes.isReceptionistFocusedShellRoute(route) &&
      !unlockedByExpandedGrant) {
    return false;
  }
  if (accessPolicy.isBillingFocusedShellUser &&
      !AppRoutes.isBillingFocusedShellRoute(route) &&
      !unlockedByExpandedGrant) {
    return false;
  }
  return true;
}
