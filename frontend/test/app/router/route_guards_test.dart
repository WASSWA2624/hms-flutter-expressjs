import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/route_guards.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

void main() {
  const AppRouteData publicRoute = AppRouteData(
    name: 'public',
    path: '/public',
  );
  const AppRouteData protectedRoute = AppRouteData(
    name: 'protected',
    path: '/protected',
    access: AppRouteAccess.authenticated,
  );
  const AppPermission reportsReadPermission = AppPermission('reports.read');
  final AppRouteData permissionRoute = AppRouteData(
    name: 'reports',
    path: '/reports',
    requiredPermissions: <AppPermission>{reportsReadPermission},
  );
  const AppRouteData moduleRoute = AppRouteData(
    name: 'billing',
    path: '/billing',
    requiredActiveModules: <String>['billing'],
  );

  group('AppRouteGuards', () {
    test('allows public and unknown routes', () {
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.ready(),
        routes: <AppRouteData>[publicRoute],
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(location: Uri(path: publicRoute.path)),
        ),
        isNull,
      );
      expect(
        guards.redirect(AppRouteGuardRequest(location: Uri(path: '/unknown'))),
        isNull,
      );
    });

    test('redirects protected routes while the session is restoring', () {
      final Uri targetLocation = Uri(path: protectedRoute.path);
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.notReady(),
        routes: <AppRouteData>[protectedRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.sessionRestoring.locationWithFrom(targetLocation),
      );
    });

    test('redirects protected routes without an authenticated session', () {
      final Uri targetLocation = Uri(path: protectedRoute.path);
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.ready(),
        routes: <AppRouteData>[protectedRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.login.locationWithFrom(targetLocation),
      );
    });

    test('redirects expired sessions to the login route', () {
      final Uri targetLocation = Uri(path: protectedRoute.path);
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.expired(),
        routes: <AppRouteData>[protectedRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.login.locationWithFrom(targetLocation),
      );
    });

    test('redirects forbidden session state to the forbidden route', () {
      final Uri targetLocation = Uri(path: protectedRoute.path);
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.forbidden(),
        routes: <AppRouteData>[protectedRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );
    });

    test('allows protected routes with an authenticated session', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: <AppRouteData>[protectedRoute],
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(location: Uri(path: protectedRoute.path)),
        ),
        isNull,
      );
    });

    test('redirects authenticated users without required permissions', () {
      final Uri targetLocation = Uri(path: permissionRoute.path);
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: const SessionState.authenticated(),
        routes: <AppRouteData>[permissionRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );
    });

    test('allows authenticated users with required permissions', () {
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: const SessionState.authenticated(),
        routes: <AppRouteData>[permissionRoute],
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri(path: permissionRoute.path),
            grantedPermissions: AppPermissionGrant(<AppPermission>{
              reportsReadPermission,
            }),
          ),
        ),
        isNull,
      );
    });

    test('redirects authenticated users without active module access', () {
      final Uri targetLocation = Uri(path: moduleRoute.path);
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'billing', isActive: false),
        ],
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: <AppRouteData>[moduleRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );
    });

    test('gates the subscriptions workspace by subscription permissions', () {
      final Uri targetLocation = Uri(path: AppRoutes.subscriptions.path);
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(),
        routes: <AppRouteData>[AppRoutes.subscriptions],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: targetLocation,
            grantedPermissions: AppPermissionGrant(<AppPermission>{
              const AppPermission('subscriptions:read'),
            }),
          ),
        ),
        isNull,
      );
    });

    test('gates the HR workspace by HR and roster permissions', () {
      final Uri targetLocation = Uri(path: AppRoutes.hr.path);
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: <AppRouteData>[AppRoutes.hr],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: targetLocation,
            grantedPermissions: AppPermissionGrant(<AppPermission>{
              const AppPermission('hr:read'),
            }),
          ),
        ),
        isNull,
      );
    });
  });
}
