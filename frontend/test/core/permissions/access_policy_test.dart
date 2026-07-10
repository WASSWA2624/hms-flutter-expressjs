import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

void main() {
  group('AppAccessPolicy', () {
    test('merges direct permissions with permissions from multiple roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR', 'BILLING']),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.grants(AppPermissions.clinicalWrite), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isTrue);
      expect(policy.grants(AppPermissions.financialApprove), isTrue);
      expect(policy.grants(AppPermissions.systemAdmin), isFalse);
    });

    test('normalizes legacy role aliases to canonical backend roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          roles: <String>['charge_nurse', 'ambulance_driver'],
        ),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasRole(AppRole.wardManager), isTrue);
      expect(policy.hasRole(AppRole.ambulanceOperator), isTrue);
      expect(policy.grants(AppPermissions.rosterPublish), isTrue);
      expect(policy.grants(AppPermissions.emergencyWrite), isTrue);
    });

    test(
      'grants pharmacist patient and reports read without patient write',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PHARMACIST']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'reporting-analytics',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        final policy = AppAccessPolicy.fromSession(session);

        expect(policy.grants(AppPermissions.pharmacyRead), isTrue);
        expect(policy.grants(AppPermissions.patientRead), isTrue);
        expect(policy.grants(AppPermissions.reportsRead), isTrue);
        expect(policy.grants(AppPermissions.patientWrite), isFalse);
        expect(policy.hasActiveModule('pharmacy'), isTrue);
        expect(policy.hasActiveModule('reports'), isTrue);
        expect(AppRoutes.patients.accessRequirement.isAllowed(policy), isTrue);
        expect(AppRoutes.pharmacy.accessRequirement.isAllowed(policy), isTrue);
        expect(AppRoutes.reports.accessRequirement.isAllowed(policy), isTrue);
      },
    );

    test('normalizes display-form elevated role names', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['Super Admin']),
      );

      final policy = AppAccessPolicy.fromSession(session);
      const requirement = AccessRequirement(
        anyPermissions: <AppPermission>[AppPermissions.clinicalRead],
        requiresTenantContext: true,
        requiresFacilityContext: true,
      );

      expect(policy.hasRole(AppRole.superAdmin), isTrue);
      expect(policy.isElevated, isTrue);
      expect(requirement.isAllowed(policy), isTrue);
    });

    test('uses active module entitlements when they are present', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR']),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'clinical-care', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing', isActive: false),
        ],
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasActiveModule('clinical_care'), isTrue);
      expect(policy.hasActiveModule('billing'), isFalse);
      expect(policy.hasAllActiveModules(<String>['clinical-care']), isTrue);
      expect(
        policy.hasAllActiveModules(<String>['clinical-care', 'billing']),
        isFalse,
      );
    });

    test('does not block modules before entitlements are loaded', () {
      final policy = AppAccessPolicy.fromSession(null);

      expect(policy.hasActiveModule('clinical-care'), isTrue);
    });

    test(
      'evaluates reusable requirements across roles permissions and scope',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['FACILITY_ADMIN'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'settings', licenseStatus: 'ACTIVE'),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.facilityAdmin],
          anyPermissions: <AppPermission>[
            AppPermissions.facilityAdmin,
            AppPermissions.systemAdmin,
          ],
          activeModules: <String>['settings'],
          requiresTenantContext: true,
          requiresFacilityContext: true,
        );

        expect(requirement.isAllowed(policy), isTrue);
      },
    );

    test(
      'denies access when plan modules are missing before role or rights',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['DOCTOR'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.doctor],
          anyPermissions: <AppPermission>[AppPermissions.clinicalRead],
          activeModules: <String>['lab-workflows'],
        );

        expect(policy.hasRole(AppRole.doctor), isTrue);
        expect(policy.grants(AppPermissions.clinicalRead), isTrue);
        expect(requirement.isAllowed(policy), isFalse);
      },
    );

    test(
      'allows access only when plan modules role and rights all pass',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['DOCTOR'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.doctor],
          anyPermissions: <AppPermission>[AppPermissions.labRead],
          activeModules: <String>['lab-workflows'],
        );

        expect(requirement.isAllowed(policy), isTrue);
      },
    );

    test(
      'allows custom roles when their permission pack matches the route',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['TESTING'],
          ),
          permissions: const <AppPermission>[AppPermissions.patientRead],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.doctor, AppRole.tenantAdmin],
          allPermissions: <AppPermission>[AppPermissions.patientRead],
          activeModules: <String>['patient-registry'],
        );

        expect(policy.hasAnyRole(requirement.anyRoles), isFalse);
        expect(requirement.isAllowed(policy), isTrue);
      },
    );
  });
}
