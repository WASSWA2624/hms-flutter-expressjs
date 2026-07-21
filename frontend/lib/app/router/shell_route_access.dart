import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';

bool canAccessShellRoute(AppRouteData route, AppAccessPolicy accessPolicy) {
  if (!route.accessRequirement.isAllowed(accessPolicy)) {
    return false;
  }

  final bool unlockedByExpandedGrant = accessPolicy
      .isShellRouteUnlockedByExpandedGrant(
        allPermissions: route.requiredPermissions,
        anyPermissions: route.requiredAnyPermissions,
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
