import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';

bool canAccessShellRoute(AppRouteData route, AppAccessPolicy accessPolicy) {
  if (!route.accessRequirement.isAllowed(accessPolicy)) {
    return false;
  }
  if (accessPolicy.isLabFocusedShellUser &&
      !AppRoutes.isLabFocusedShellRoute(route)) {
    return false;
  }
  return true;
}
