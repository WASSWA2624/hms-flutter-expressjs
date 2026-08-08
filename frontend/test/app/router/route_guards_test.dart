import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/route_guards.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
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
  const AppPermission reportsReadPermission = AppPermission('reports:read');
  final AppRouteData permissionRoute = AppRouteData(
    name: 'reportsGuardTest',
    path: '/reports-guard-test',
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

    test('keeps session-restoring while the session is still unknown', () {
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.notReady(),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri(
              path: AppRoutes.sessionRestoring.path,
              queryParameters: <String, String>{'from': protectedRoute.path},
            ),
          ),
        ),
        isNull,
      );
    });

    test('resumes from after session restore when authenticated', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
        isModuleCatalogHydrated: true,
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
      );
      final Uri from = Uri(path: protectedRoute.path);

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri.parse(
              AppRoutes.sessionRestoring.locationWithFrom(from),
            ),
          ),
        ),
        from.toString(),
      );
    });

    test('resumes home from session-restoring when from is missing', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
        isModuleCatalogHydrated: true,
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri(path: AppRoutes.sessionRestoring.path),
          ),
        ),
        AppRoutes.home.path,
      );
    });

    test('sends unsigned-in restore to login with from', () {
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.unauthenticated(),
      );
      final Uri from = Uri(path: protectedRoute.path);

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri.parse(
              AppRoutes.sessionRestoring.locationWithFrom(from),
            ),
          ),
        ),
        AppRoutes.login.locationWithFrom(from),
      );
    });

    test('sends forbidden restore to forbidden with from', () {
      const AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.forbidden(),
      );
      final Uri from = Uri(path: protectedRoute.path);

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri.parse(
              AppRoutes.sessionRestoring.locationWithFrom(from),
            ),
          ),
        ),
        AppRoutes.forbidden.locationWithFrom(from),
      );
    });

    test('ignores absolute from and resumes home when authenticated', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
        isModuleCatalogHydrated: true,
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri(
              path: AppRoutes.sessionRestoring.path,
              queryParameters: <String, String>{
                'from': 'https://evil.example/phish',
              },
            ),
          ),
        ),
        AppRoutes.home.path,
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
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          roles: <String>['nurse'],
        ),
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
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          roles: <String>['nurse'],
        ),
        isModuleCatalogHydrated: true,
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'reporting-analytics'),
        ],
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
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

    test('holds module routes while tenant Me enrichment is pending', () {
      final Uri targetLocation = Uri(path: moduleRoute.path);
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
      );
      expect(session.needsMeEnrichment, isTrue);
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: <AppRouteData>[moduleRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.sessionRestoring.locationWithFrom(targetLocation),
      );
    });

    test('holds permission-gated routes while Me enrichment is pending', () {
      final Uri targetLocation = Uri(path: permissionRoute.path);
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: <AppRouteData>[permissionRoute],
      );

      expect(
        guards.redirect(AppRouteGuardRequest(location: targetLocation)),
        AppRoutes.sessionRestoring.locationWithFrom(targetLocation),
      );
    });

    test('stays on session-restoring while Me enrichment is pending', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(tenantId: 'tenant-1'),
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri.parse(
              AppRoutes.sessionRestoring.locationWithFrom(
                Uri(path: moduleRoute.path),
              ),
            ),
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

    test('gates the subscriptions workspace to platform admins only', () {
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
              AppPermissions.subscriptionsRead,
            }),
          ),
        ),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: targetLocation,
            grantedPermissions: AppPermissionGrant(<AppPermission>{
              AppPermissions.platformAdmin,
            }),
          ),
        ),
        isNull,
      );

      final AppRouteGuards superAdminGuards = AppRouteGuards(
        sessionState: SessionState.authenticated(
          session: AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(roles: <String>['PLATFORM_ADMIN']),
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(code: 'subscription-controls'),
            ],
          ),
        ),
        routes: <AppRouteData>[AppRoutes.subscriptions],
      );

      expect(
        superAdminGuards.redirect(
          AppRouteGuardRequest(location: targetLocation),
        ),
        isNull,
      );
    });

    test(
      'keeps patient portal and housekeeping out of staff patient flow routes',
      () {
        for (final role in <String>['PATIENT', 'HOUSE_KEEPER']) {
          final session = AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: AuthUserProfile(roles: <String>[role]),
          );
          final AppRouteGuards guards = AppRouteGuards(
            sessionState: SessionState.authenticated(session: session),
            routes: const <AppRouteData>[AppRoutes.patients, AppRoutes.opd],
          );

          expect(
            guards.redirect(
              AppRouteGuardRequest(
                location: Uri(path: AppRoutes.patients.path),
              ),
            ),
            AppRoutes.forbidden.locationWithFrom(
              Uri(path: AppRoutes.patients.path),
            ),
          );
          expect(
            guards.redirect(
              AppRouteGuardRequest(location: Uri(path: AppRoutes.opd.path)),
            ),
            AppRoutes.forbidden.locationWithFrom(Uri(path: AppRoutes.opd.path)),
          );
        }
      },
    );

    test('allows permitted staff patient flow roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'patient-registry'),
          AppModuleEntitlement(code: 'scheduling-queue'),
        ],
        user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: const <AppRouteData>[AppRoutes.patients, AppRoutes.opd],
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(location: Uri(path: AppRoutes.patients.path)),
        ),
        isNull,
      );
      expect(
        guards.redirect(
          AppRouteGuardRequest(location: Uri(path: AppRoutes.opd.path)),
        ),
        AppRoutes.reception.location(
          queryParameters: const <String, String>{'section': 'queue'},
        ),
      );
    });

    test('redirects receptionist OPD deep links to Reception', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        permissions: <AppPermission>[
          ...AppAccessPolicy.fromSession(
            AuthSession(
              tokens: SessionTokens(accessToken: 'access-token'),
              user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
            ),
          ).permissions,
          AppPermissions.opdRead,
        ],
        isAuthorizationHydrated: true,
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'patient-registry'),
          AppModuleEntitlement(code: 'scheduling-queue'),
          AppModuleEntitlement(code: 'notifications-communications'),
          AppModuleEntitlement(code: 'reporting-analytics'),
        ],
        user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: const <AppRouteData>[AppRoutes.opd, AppRoutes.emergency],
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: Uri(
              path: AppRoutes.opd.path,
              queryParameters: const <String, String>{'flowId': 'flow-9'},
            ),
          ),
        ),
        AppRoutes.reception.location(
          queryParameters: const <String, String>{
            'flowId': 'flow-9',
            'section': 'active',
          },
        ),
      );
      expect(
        guards.redirect(
          AppRouteGuardRequest(location: Uri(path: AppRoutes.emergency.path)),
        ),
        AppRoutes.reception.location(
          queryParameters: const <String, String>{'section': 'high-priority'},
        ),
      );
    });

    test('gates the HR workspace by HR and roster permissions', () {
      final Uri targetLocation = Uri(path: AppRoutes.hr.path);
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
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
              AppPermissions.hrRead,
            }),
          ),
        ),
        isNull,
      );
    });

    test('blocks HR from the access admin workspace route', () {
      final Uri targetLocation = Uri(path: AppRoutes.accessAdmin.path);
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          roles: <String>['HR'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: SessionState.authenticated(session: session),
        routes: <AppRouteData>[AppRoutes.accessAdmin],
      );

      expect(
        guards.redirect(
          AppRouteGuardRequest(
            location: targetLocation,
            grantedPermissions: AppPermissionGrant(<AppPermission>{
              AppPermissions.hrWrite,
            }),
          ),
        ),
        AppRoutes.forbidden.locationWithFrom(targetLocation),
      );
    });
  });
}
