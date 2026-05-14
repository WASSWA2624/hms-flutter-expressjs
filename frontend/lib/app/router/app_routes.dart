import 'package:hosspi_hms/core/permissions/app_permission.dart';

enum AppRouteAccess { public, authenticated }

final class AppRouteData {
  const AppRouteData({
    required this.name,
    required this.path,
    this.access = AppRouteAccess.public,
    this.requiredPermissions = const <AppPermission>{},
  });

  final String name;
  final String path;
  final AppRouteAccess access;
  final Set<AppPermission> requiredPermissions;

  bool get requiresAuthenticatedSession {
    return access == AppRouteAccess.authenticated ||
        requiredPermissions.isNotEmpty;
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

  static const AppRouteData login = AppRouteData(name: 'login', path: '/login');

  static const AppRouteData register = AppRouteData(
    name: 'register',
    path: '/register',
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
    login,
    register,
    sessionRestoring,
    authRequired,
    forbidden,
  ];

  static const List<AppRouteData> shellRoutes = <AppRouteData>[home, settings];

  static AppRouteData? matchPath(String locationPath) {
    for (final AppRouteData route in all) {
      if (route.matchesPath(locationPath)) {
        return route;
      }
    }

    return null;
  }
}
