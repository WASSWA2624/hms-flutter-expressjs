import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';

AppAccessPolicy _policyForRoles(List<String> roles) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(roles: roles),
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr'),
      ],
    ),
  );
}

void main() {
  group('home metric routes', () {
    test('HR profile exposes modal actions for leave and shift cards', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.hr);
      final AppAccessPolicy policy = _policyForRoles(<String>['HR']);

      final HomeMetricAction? leaveAction = homeMetricAction(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_leaves',
          label: 'Pending leave approvals',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricAction? shiftAction = homeMetricAction(
        profile: profile,
        card: const HomeStatusCard(
          id: 'unassigned_shifts',
          label: 'Unassigned shifts',
          value: 1,
        ),
        policy: policy,
      );

      expect(leaveAction?.target.kind, HomeMetricActionKind.hrWorkQueue);
      expect(leaveAction?.target.hrQueue, 'LEAVE_REQUESTS');
      expect(shiftAction?.target.hrQueue, 'UNASSIGNED_SHIFTS');
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'pending_leaves',
            label: 'Pending leave approvals',
            value: 2,
          ),
          policy: policy,
        ),
        isNull,
      );
    });

    test('HR queue targets map to workspace deep links', () {
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'hr', resource: 'staff-leaves'),
        ),
        <String, String>{'queue': 'LEAVE_REQUESTS'},
      );
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'hr', resource: 'payroll-runs'),
        ),
        <String, String>{'queue': 'PAYROLL_DRAFTS'},
      );
    });

    test('doctor profile cards navigate to clinical and lab workspaces', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'clinical'),
            AppModuleEntitlement(code: 'lab'),
          ],
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'results_pending_review',
            label: 'Results to review',
            value: 2,
          ),
          policy: policy,
        )?.route,
        AppRoutes.lab,
      );
      expect(
        homeMetricAction(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        ),
        isNull,
      );
    });

    test('doctor secondary cards navigate when grants and modules allow', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['CUSTOM'],
          ),
          permissions: const <AppPermission>[
            AppPermissions.clinicalRead,
            AppPermissions.radiologyRead,
            AppPermissions.pharmacyRead,
            AppPermissions.emergencyRead,
            AppPermissions.rosterRead,
            AppPermissions.hrRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'radiology-workflows',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'radiology_pending',
            label: 'Radiology results',
            value: 1,
            requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.radiology,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'prescriptions_pending',
            label: 'Prescriptions pending',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.pharmacy,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'emergency_cases_today',
            label: 'Emergency calls',
            value: 1,
            requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.emergency,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'shifts_today',
            label: 'My schedule',
            value: 1,
            requiredPermissions: <AppPermission>[AppPermissions.rosterRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.hr,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'prescriptions_pending',
            label: 'Prescriptions pending',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
          ),
          policy: AppAccessPolicy.fromSession(
            AuthSession(
              tokens: SessionTokens(accessToken: 'access-token'),
              user: const AuthUserProfile(
                tenantId: 'tenant-1',
                facilityId: 'facility-1',
                roles: <String>['CUSTOM'],
              ),
              permissions: const <AppPermission>[AppPermissions.clinicalRead],
              moduleEntitlements: const <AppModuleEntitlement>[
                AppModuleEntitlement(
                  code: 'pharmacy-dispensing',
                  licenseStatus: 'ACTIVE',
                ),
              ],
              isAuthorizationHydrated: true,
            ),
          ),
        ),
        isNull,
      );
    });

    test('pharmacist profile cards navigate to pharmacy workspace', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.pharmacist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['PHARMACIST']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'pharmacy'),
            AppModuleEntitlement(code: 'pharmacy-dispensing'),
          ],
        ),
      );

      final HomeMetricNavigation? pending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_dispense',
          label: 'Pending',
          value: 4,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? lowStock = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'low_stock',
          label: 'Low stock',
          value: 2,
        ),
        policy: policy,
      );

      expect(pending?.route, AppRoutes.pharmacy);
      expect(pending?.queryParameters, <String, String>{'section': 'orders'});
      expect(lowStock?.route, AppRoutes.pharmacy);
      expect(lowStock?.queryParameters, <String, String>{
        'section': 'inventory',
      });
    });

    test('pharmacist billing_pending navigates to billing when granted', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.pharmacist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['PHARMACIST'],
          ),
          permissions: const <AppPermission>[
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
            AppPermissions.billingRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'pharmacy'),
            AppModuleEntitlement(code: 'pharmacy-dispensing'),
            AppModuleEntitlement(code: 'billing-payments'),
          ],
        ),
      );

      final HomeMetricNavigation? billingPending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'billing_pending',
          label: 'Billing pending',
          value: 120,
          format: 'currency',
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(billingPending?.route, AppRoutes.billing);
      expect(billingPending?.queryParameters, <String, String>{
        'queue': 'pendingPayment',
      });
    });

    test('receptionist metric cards navigate to front-desk workspaces', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.receptionist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['RECEPTIONIST'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      final HomeMetricNavigation? meetings = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'appointments_today',
          label: 'Meetings',
          value: 3,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? registrations = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'registrations_today',
          label: 'Registrations',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? emergency = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'emergency_cases_today',
          label: 'Emergency intake',
          value: 1,
        ),
        policy: policy,
      );

      expect(meetings?.route, AppRoutes.reception);
      expect(meetings?.queryParameters, <String, String>{
        'section': 'appointments',
      });
      expect(registrations?.route, AppRoutes.patients);
      expect(emergency?.route, AppRoutes.emergency);
    });

    test('receptionist pending payments navigates to billing when granted', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.receptionist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['RECEPTIONIST'],
          ),
          permissions: const <AppPermission>[
            AppPermissions.patientRead,
            AppPermissions.billingRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      final HomeMetricNavigation? pending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_balance_amount',
          label: 'Pending payments',
          value: 4,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(pending?.route, AppRoutes.billing);
      expect(pending?.queryParameters, <String, String>{
        'queue': 'pendingPayment',
      });
    });

    test('homeHrMetricAccessAllowed gates HR modal actions', () {
      final AppAccessPolicy allowed = _policyForRoles(<String>['HR']);
      final AppAccessPolicy denied = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'hr'),
          ],
        ),
      );

      expect(homeHrMetricAccessAllowed(allowed), isTrue);
      expect(homeHrMetricAccessAllowed(denied), isFalse);
    });

    test('never navigates from a card missing required permissions', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['CUSTOM'],
          ),
          permissions: const <AppPermission>[AppPermissions.clinicalRead],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'results_pending_review',
            label: 'Results',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.labRead],
          ),
          policy: policy,
        ),
        isNull,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned',
            value: 3,
            requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
    });
  });
}
