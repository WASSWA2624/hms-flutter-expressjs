import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/session_state.dart';

final class AppRouteGuardRequest {
  const AppRouteGuardRequest({
    required this.location,
    this.grantedPermissions = const AppPermissionGrant.empty(),
  });

  final Uri location;
  final AppPermissionGrant grantedPermissions;
}

final class AppRouteGuards {
  const AppRouteGuards({
    required this.sessionState,
    this.routes = AppRoutes.all,
  });

  final SessionState sessionState;
  final List<AppRouteData> routes;

  String? redirect(AppRouteGuardRequest request) {
    final AppRouteData? targetRoute = _matchRoute(request.location.path);
    if (targetRoute == null) {
      return null;
    }

    if (targetRoute.isAuthEntryRoute && sessionState.isAuthenticated) {
      return AppRoutes.home.location();
    }

    if (!targetRoute.requiresAuthenticatedSession) {
      return null;
    }

    if (!sessionState.isReady) {
      return AppRoutes.sessionRestoring.locationWithFrom(request.location);
    }

    if (!sessionState.isAuthenticated) {
      return switch (sessionState.status) {
        SessionStatus.forbidden => AppRoutes.forbidden.locationWithFrom(
          request.location,
        ),
        SessionStatus.expired || SessionStatus.unauthenticated =>
          AppRoutes.login.locationWithFrom(request.location),
        SessionStatus.unknown => AppRoutes.sessionRestoring.locationWithFrom(
          request.location,
        ),
        SessionStatus.authenticated => null,
      };
    }

    if (!_hasRequiredPermissions(targetRoute, request.grantedPermissions)) {
      return AppRoutes.forbidden.locationWithFrom(request.location);
    }

    return null;
  }

  AppRouteData? _matchRoute(String locationPath) {
    for (final AppRouteData route in routes) {
      if (route.matchesPath(locationPath)) {
        return route;
      }
    }

    return null;
  }

  bool _hasRequiredPermissions(
    AppRouteData route,
    AppPermissionGrant grantedPermissions,
  ) {
    return grantedPermissions.grantsAll(route.requiredPermissions);
  }
}
