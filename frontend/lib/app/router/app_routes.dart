import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

enum AppRouteAccess { public, authenticated }

final class AppRouteData {
  const AppRouteData({
    required this.name,
    required this.path,
    this.access = AppRouteAccess.public,
    this.requiredPermissions = const <AppPermission>[],
    this.requiredAnyPermissions = const <AppPermission>[],
    this.requiredAnyRoles = const <AppRole>[],
    this.requiredActiveModules = const <String>[],
    this.requiresTenantContext = false,
    this.requiresFacilityContext = false,
  });

  final String name;
  final String path;
  final AppRouteAccess access;
  final Iterable<AppPermission> requiredPermissions;
  final Iterable<AppPermission> requiredAnyPermissions;
  final Iterable<AppRole> requiredAnyRoles;
  final Iterable<String> requiredActiveModules;
  final bool requiresTenantContext;
  final bool requiresFacilityContext;

  bool get requiresAuthenticatedSession {
    return access == AppRouteAccess.authenticated ||
        requiredPermissions.isNotEmpty ||
        requiredAnyPermissions.isNotEmpty ||
        requiredAnyRoles.isNotEmpty ||
        requiredActiveModules.isNotEmpty ||
        requiresTenantContext ||
        requiresFacilityContext;
  }

  bool get isAuthEntryRoute {
    return path == AppRoutes.login.path || path == AppRoutes.register.path;
  }

  bool matchesPath(String locationPath) {
    return locationPath == path;
  }

  String location({
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    return Uri(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  String locationWithFrom(Uri from) {
    return location(queryParameters: <String, String>{'from': from.toString()});
  }
}

abstract final class AppRoutes {
  static const AppRouteData home = AppRouteData(
    name: 'home',
    path: '/',
    access: AppRouteAccess.authenticated,
  );
  static const AppRouteData settings = AppRouteData(
    name: 'settings',
    path: '/settings',
    access: AppRouteAccess.authenticated,
  );
  static const AppRouteData tenantFacilitySetup = AppRouteData(
    name: 'tenantFacilitySetup',
    path: '/admin/setup',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
    requiredAnyRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
  );
  static const AppRouteData profile = AppRouteData(
    name: 'profile',
    path: '/profile',
    access: AppRouteAccess.authenticated,
  );

  static const AppRouteData login = AppRouteData(name: 'login', path: '/login');

  static const AppRouteData register = AppRouteData(
    name: 'register',
    path: '/register',
  );

  static const AppRouteData verifyEmail = AppRouteData(
    name: 'verifyEmail',
    path: '/verify-email',
  );

  static const AppRouteData sessionRestoring = AppRouteData(
    name: 'sessionRestoring',
    path: '/session-restoring',
  );

  static const AppRouteData authRequired = AppRouteData(
    name: 'authRequired',
    path: '/auth-required',
  );

  static const AppRouteData forbidden = AppRouteData(
    name: 'forbidden',
    path: '/forbidden',
  );

  static const List<AppRouteData> all = <AppRouteData>[
    home,
    settings,
    tenantFacilitySetup,
    profile,
    login,
    register,
    verifyEmail,
    sessionRestoring,
    authRequired,
    forbidden,
  ];

  static const List<AppRouteData> shellRoutes = <AppRouteData>[
    home,
    settings,
    tenantFacilitySetup,
    profile,
  ];

  static AppRouteData? matchPath(String locationPath) {
    for (final AppRouteData route in all) {
      if (route.matchesPath(locationPath)) {
        return route;
      }
    }

    return null;
  }
}
