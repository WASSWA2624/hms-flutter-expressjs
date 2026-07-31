import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
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

    // Waiting shell: stay while unknown or Me enrichment pending; once ready,
    // resume `from` (or home) so users do not need a duplicate exit action.
    if (targetRoute.path == AppRoutes.sessionRestoring.path) {
      if (!sessionState.isReady || _needsMeEnrichment) {
        return null;
      }
      return _resumeAfterSessionRestore(request.location);
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

    // JWT-only restore (e.g. hot reload) has no plan modules yet — hold gated
    // routes instead of treating empty entitlements as a hard deny.
    if (_needsMeEnrichment && !targetRoute.accessRequirement.isEmpty) {
      return AppRoutes.sessionRestoring.locationWithFrom(request.location);
    }

    if (!_hasRequiredAccess(targetRoute, request.grantedPermissions)) {
      return AppRoutes.forbidden.locationWithFrom(request.location);
    }

    return null;
  }

  bool get _needsMeEnrichment =>
      sessionState.session?.needsMeEnrichment ?? false;

  String? _resumeAfterSessionRestore(Uri sessionRestoringLocation) {
    final Uri resumeTarget = _resumeUri(
      sessionRestoringLocation.queryParameters['from'],
    );

    if (sessionState.isAuthenticated) {
      if (_needsMeEnrichment) {
        return null;
      }
      return resumeTarget.toString();
    }

    return switch (sessionState.status) {
      SessionStatus.forbidden => AppRoutes.forbidden.locationWithFrom(
        resumeTarget,
      ),
      SessionStatus.expired || SessionStatus.unauthenticated =>
        AppRoutes.login.locationWithFrom(resumeTarget),
      SessionStatus.unknown => null,
      SessionStatus.authenticated => resumeTarget.toString(),
    };
  }

  Uri _resumeUri(String? fromRaw) {
    if (fromRaw == null || fromRaw.trim().isEmpty) {
      return Uri(path: AppRoutes.home.path);
    }

    final Uri? parsed = Uri.tryParse(fromRaw);
    if (parsed == null || parsed.hasScheme) {
      return Uri(path: AppRoutes.home.path);
    }

    final String path = parsed.path;
    if (path.isEmpty || path == AppRoutes.sessionRestoring.path) {
      return Uri(path: AppRoutes.home.path);
    }

    return parsed;
  }

  AppRouteData? _matchRoute(String locationPath) {
    for (final AppRouteData route in routes) {
      if (route.matchesPath(locationPath)) {
        return route;
      }
    }

    return null;
  }

  bool _hasRequiredAccess(
    AppRouteData route,
    AppPermissionGrant grantedPermissions,
  ) {
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      sessionState.session,
    );
    final AppPermissionGrant effectivePermissions = AppPermissionGrant(
      <AppPermission>{...policy.permissions, ...grantedPermissions.permissions},
    );
    final effectivePolicy = AppAccessPolicy.fromSession(
      sessionState.session,
    ).copyWithPermissions(effectivePermissions.permissions);

    return canAccessShellRoute(route, effectivePolicy);
  }
}
