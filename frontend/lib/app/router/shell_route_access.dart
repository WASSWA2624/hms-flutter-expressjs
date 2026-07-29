import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';

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
